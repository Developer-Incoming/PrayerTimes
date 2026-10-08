//
//  PrayerScheduleTests.swift
//  PrayerKitTests
//

import XCTest
@testable import PrayerKit

final class PrayerScheduleTests: XCTestCase {

    private let makkah = SavedLocation(name: "Makkah", latitude: 21.4225, longitude: 39.8262,
                                       timeZoneIdentifier: "Asia/Riyadh")

    private func schedule(_ configure: (inout PrayerSettings) -> Void = { _ in }) -> PrayerSchedule {
        var settings = PrayerSettings()
        settings.location = makkah
        configure(&settings)
        return PrayerSchedule(settings: settings)!
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int, tz: String = "Asia/Riyadh") -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: tz)!
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func testNoScheduleWithoutLocation() {
        XCTAssertNil(PrayerSchedule(settings: PrayerSettings()))
    }

    func testDayContainsAllPrayersInOrder() {
        let day = schedule().day(containing: date(2026, 10, 7, 10, 0))
        XCTAssertEqual(day.times.map(\.prayer), Prayer.allCases)
        XCTAssertEqual(day.times.map(\.date), day.times.map(\.date).sorted())
    }

    func testDayForLocalCalendarDate() {
        let s = schedule()
        // A date picked on a device in Los Angeles (late evening Oct 7 local,
        // which is already Oct 8 in Makkah) still shows Oct 7.
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let picked = la.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 23))!
        let day = s.day(for: picked, in: la)
        XCTAssertEqual(s.calendar.component(.day, from: day.time(for: .dhuhr)!), 7)
    }

    func testStatusNextAndRecent() {
        let s = schedule()
        let day = s.day(containing: date(2026, 10, 7, 12, 0))
        let dhuhr = day[.dhuhr]!
        let asr = day[.asr]!

        // 10 minutes after Dhuhr with a 30 minute window.
        let status = s.status(at: dhuhr.addingTimeInterval(600), recentWindow: 1800)!
        XCTAssertEqual(status.next.prayer, .asr)
        XCTAssertEqual(status.next.date, asr)
        XCTAssertEqual(status.previous?.prayer, .dhuhr)
        XCTAssertEqual(status.recent?.prayer, .dhuhr)

        // 40 minutes after Dhuhr: no longer recent.
        let later = s.status(at: dhuhr.addingTimeInterval(2400), recentWindow: 1800)!
        XCTAssertNil(later.recent)
        XCTAssertEqual(later.previous?.prayer, .dhuhr)

        // Exactly at Dhuhr: Dhuhr just started.
        let exact = s.status(at: dhuhr, recentWindow: 1800)!
        XCTAssertEqual(exact.recent?.prayer, .dhuhr)
        XCTAssertEqual(exact.next.prayer, .asr)
    }

    func testStatusAfterIshaPointsToTomorrowsFajr() {
        let s = schedule()
        let today = s.day(containing: date(2026, 10, 7, 12, 0))
        let tomorrow = s.day(containing: date(2026, 10, 8, 12, 0))
        let status = s.status(at: today[.isha]!.addingTimeInterval(3600))!
        XCTAssertEqual(status.next.prayer, .fajr)
        XCTAssertEqual(status.next.date, tomorrow[.fajr]!)
        XCTAssertEqual(status.previous?.prayer, .isha)
    }

    func testStatusCanSkipSunrise() {
        let s = schedule()
        let day = s.day(containing: date(2026, 10, 7, 12, 0))
        let afterFajr = day[.fajr]!.addingTimeInterval(60)
        XCTAssertEqual(s.status(at: afterFajr, includeSunrise: true)!.next.prayer, .sunrise)
        XCTAssertEqual(s.status(at: afterFajr, includeSunrise: false)!.next.prayer, .dhuhr)
    }

    func testTransitionDates() {
        let s = schedule()
        let start = date(2026, 10, 7, 0, 0)
        let end = start.addingTimeInterval(86_400)
        let transitions = s.transitionDates(from: start, to: end, includeSunrise: false, recentWindow: 1800)
        let day = s.day(containing: date(2026, 10, 7, 12, 0))
        for prayer in Prayer.obligatory {
            XCTAssertTrue(transitions.contains(day[prayer]!), "\(prayer)")
            XCTAssertTrue(transitions.contains(day[prayer]!.addingTimeInterval(1800)), "\(prayer) + window")
        }
        XCTAssertFalse(transitions.contains(day[.sunrise]!))
        XCTAssertEqual(transitions, transitions.sorted())
        XCTAssertTrue(transitions.allSatisfy { $0 > start && $0 <= end })
    }

    func testEventsAcrossDays() {
        let s = schedule()
        let start = date(2026, 10, 7, 0, 0)
        let events = s.events(from: start, to: start.addingTimeInterval(3 * 86_400))
        XCTAssertEqual(events.count, 18)
        XCTAssertEqual(events.map(\.date), events.map(\.date).sorted())
    }

    func testNotificationPlan() {
        let disabled = schedule()
        XCTAssertTrue(disabled.notificationPlan(from: date(2026, 10, 7, 0, 0)).isEmpty)

        let s = schedule { settings in
            settings.notifications.isEnabled = true
            settings.notifications[.asr] = PrayerNotificationSettings(alert: .silent, reminderMinutes: 15)
            settings.notifications[.isha] = PrayerNotificationSettings(alert: .off, reminderMinutes: 10)
        }
        let now = date(2026, 10, 7, 0, 0)
        let plan = s.notificationPlan(from: now, days: 2)
        // Per day: fajr, dhuhr, asr, asr reminder, maghrib (sunrise and isha off).
        XCTAssertEqual(plan.count, 10)
        XCTAssertFalse(plan.contains { $0.prayer == .isha || $0.prayer == .sunrise })
        XCTAssertTrue(plan.allSatisfy { $0.fireDate > now })
        XCTAssertEqual(plan.map(\.fireDate), plan.map(\.fireDate).sorted())

        let reminders = plan.filter(\.isReminder)
        XCTAssertEqual(reminders.count, 2)
        for reminder in reminders {
            XCTAssertEqual(reminder.prayer, .asr)
            XCTAssertEqual(reminder.prayerDate.timeIntervalSince(reminder.fireDate), 900)
            XCTAssertFalse(reminder.playsSound)
        }
        XCTAssertTrue(plan.filter { $0.prayer == .fajr }.allSatisfy(\.playsSound))
        XCTAssertEqual(Set(plan.map(\.id)).count, plan.count, "identifiers must be unique")

        // System limit of pending notifications.
        XCTAssertEqual(s.notificationPlan(from: now, days: 30, limit: 64).count, 64)
    }

    func testNotificationPlanSkipsPastTimes() {
        let s = schedule { $0.notifications.isEnabled = true }
        let day = s.day(containing: date(2026, 10, 7, 12, 0))
        let now = day[.dhuhr]!.addingTimeInterval(1)
        let plan = s.notificationPlan(from: now, days: 1)
        XCTAssertEqual(plan.first?.prayer, .asr)
    }

    func testHijri() {
        let s = schedule { $0.hijriCalendar = .ummAlQura }
        // 1 Ramadan 1447 (Umm al-Qura) == 18 February 2026.
        let ramadan = HijriFormatter(kind: .ummAlQura, timeZone: s.timeZone)
            .components(from: s.hijriDate(at: date(2026, 2, 18, 12, 0)))
        XCTAssertEqual(ramadan.day, 1)
        XCTAssertEqual(ramadan.month, 9)
        XCTAssertEqual(ramadan.year, 1447)

        // Adjustment.
        let adjusted = schedule { $0.hijriAdjustment = -1 }
        let c = HijriFormatter(kind: .ummAlQura, timeZone: s.timeZone)
            .components(from: adjusted.hijriDate(at: date(2026, 2, 18, 12, 0)))
        XCTAssertEqual(c.month, 8)

        // New day at Maghrib.
        let maghribRule = schedule { $0.hijriChangesAtMaghrib = true }
        let maghrib = maghribRule.day(containing: date(2026, 2, 17, 12, 0))[.maghrib]!
        let before = HijriFormatter(kind: .ummAlQura, timeZone: s.timeZone)
            .components(from: maghribRule.hijriDate(at: maghrib.addingTimeInterval(-60)))
        let after = HijriFormatter(kind: .ummAlQura, timeZone: s.timeZone)
            .components(from: maghribRule.hijriDate(at: maghrib.addingTimeInterval(60)))
        XCTAssertEqual(before.month, 8)
        XCTAssertEqual(after.month, 9)
        XCTAssertEqual(after.day, 1)

        XCTAssertFalse(s.hijriString(at: date(2026, 10, 7, 12, 0)).isEmpty)
    }

    func testTimeFormatter() {
        let en = Locale(identifier: "en_US")
        let tz = TimeZone(identifier: "Asia/Riyadh")!
        let d = date(2026, 10, 7, 15, 5)
        XCTAssertEqual(PrayerTimeFormatter(format: .twentyFourHour, timeZone: tz, locale: en).string(from: d), "15:05")
        let twelve = PrayerTimeFormatter(format: .twelveHour, timeZone: tz, locale: en).string(from: d)
        XCTAssertTrue(twelve.hasPrefix("3:05"), twelve)
        XCTAssertTrue(twelve.hasSuffix("PM"), twelve)
    }
}

final class PrayerSettingsTests: XCTestCase {

    func testDecodingEmptyObjectGivesDefaults() throws {
        let settings = try JSONDecoder().decode(PrayerSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(settings, PrayerSettings())
    }

    func testDecodingIgnoresUnknownAndInvalidValues() throws {
        let json = #"{"calculationMethod":"doesNotExist","asrMethod":"hanafi","extra":1}"#
        let settings = try JSONDecoder().decode(PrayerSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.calculationMethod, .mwl)
        XCTAssertEqual(settings.asrMethod, .hanafi)
    }

    func testRoundTrip() throws {
        var settings = PrayerSettings()
        settings.location = SavedLocation(name: "Cairo", latitude: 30.0444, longitude: 31.2357, timeZoneIdentifier: "Africa/Cairo")
        settings.calculationMethod = .custom
        settings.customParameters = .init(fajrAngle: 19, maghrib: .angle(4), isha: .minutes(80))
        settings.setOffset(3, for: .maghrib)
        settings.hijriAdjustment = 1
        settings.timeFormat = .twentyFourHour
        settings.notifications.isEnabled = true
        settings.notifications[.fajr] = .init(alert: .silent, reminderMinutes: 20)

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(PrayerSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
        XCTAssertEqual(decoded.offset(for: .maghrib), 3)
        XCTAssertEqual(decoded.notifications[.fajr].reminderMinutes, 20)
        XCTAssertEqual(decoded.notifications[.sunrise].alert, .off)
    }

    func testStorePersistence() {
        let defaults = UserDefaults(suiteName: "PrayerKitTests.\(UUID().uuidString)")!
        XCTAssertEqual(SettingsStore.load(from: defaults), PrayerSettings())
        var settings = PrayerSettings()
        settings.asrMethod = .hanafi
        SettingsStore.save(settings, to: defaults)
        XCTAssertEqual(SettingsStore.load(from: defaults).asrMethod, .hanafi)
    }

    func testOffsetsAffectCalculator() {
        var settings = PrayerSettings()
        settings.location = SavedLocation(name: "X", latitude: 30, longitude: 31, timeZoneIdentifier: "Africa/Cairo")
        let base = PrayerSchedule(settings: settings)!.day(year: 2026, month: 10, day: 7)
        settings.setOffset(-2, for: .fajr)
        let tuned = PrayerSchedule(settings: settings)!.day(year: 2026, month: 10, day: 7)
        XCTAssertEqual(tuned[.fajr]!.timeIntervalSince(base[.fajr]!), -120)
        XCTAssertEqual(tuned[.dhuhr], base[.dhuhr])
        XCTAssertNotEqual(PrayerSettings().calculationSignature, settings.calculationSignature)
    }
}
