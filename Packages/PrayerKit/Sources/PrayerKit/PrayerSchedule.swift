//
//  PrayerSchedule.swift
//  PrayerKit
//

import Foundation

/// The prayer situation at a given instant.
public struct PrayerStatus: Hashable, Sendable {
    /// The most recent time that has started (may be from yesterday).
    public var previous: PrayerTime?
    /// The next upcoming time.
    public var next: PrayerTime
    /// `previous` when it started less than the "recent" window ago.
    public var recent: PrayerTime?

    public init(previous: PrayerTime?, next: PrayerTime, recent: PrayerTime?) {
        self.previous = previous
        self.next = next
        self.recent = recent
    }
}

/// A notification that should be scheduled.
public struct PlannedNotification: Hashable, Sendable, Identifiable {
    public var prayer: Prayer
    /// When the prayer time begins.
    public var prayerDate: Date
    /// When the notification fires (earlier than `prayerDate` for reminders).
    public var fireDate: Date
    /// Minutes before the prayer time, 0 for the prayer time itself.
    public var minutesBefore: Int
    public var playsSound: Bool

    public var isReminder: Bool { minutesBefore > 0 }

    public var id: String {
        "prayer.\(prayer.rawValue).\(Int(prayerDate.timeIntervalSince1970)).\(minutesBefore)"
    }
}

/// Computes prayer days, upcoming times and statuses for the configured
/// location and settings.
public struct PrayerSchedule: Sendable {
    public let settings: PrayerSettings
    public let location: SavedLocation
    private let calculator: PrayerTimeCalculator

    public init?(settings: PrayerSettings) {
        guard let location = settings.location, let calculator = settings.calculator else { return nil }
        self.settings = settings
        self.location = location
        self.calculator = calculator
    }

    public var timeZone: TimeZone { location.timeZone }

    /// Gregorian calendar in the location's time zone.
    public var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }

    // MARK: Days

    public func day(year: Int, month: Int, day: Int) -> PrayerDay {
        let raw = calculator.times(year: year, month: month, day: day, timeZone: timeZone)
        let times = Prayer.allCases.compactMap { prayer in
            raw[prayer.timeName].map { PrayerTime(prayer: prayer, date: $0) }
        }
        let start = calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
        return PrayerDay(day: start, timeZone: timeZone, times: times)
    }

    /// The prayer day containing the instant `date` at the location.
    public func day(containing date: Date) -> PrayerDay {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return day(year: c.year!, month: c.month!, day: c.day!)
    }

    /// The prayer day for the calendar day `date` falls on in `localCalendar`
    /// (e.g. a date picked in a calendar on the device).
    public func day(for date: Date, in localCalendar: Calendar) -> PrayerDay {
        let c = localCalendar.dateComponents([.year, .month, .day], from: date)
        return day(year: c.year!, month: c.month!, day: c.day!)
    }

    /// Consecutive prayer days starting with the day containing `date`.
    public func days(startingAt date: Date, count: Int) -> [PrayerDay] {
        let cal = calendar
        let start = cal.startOfDay(for: date)
        return (0..<max(0, count)).compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            // Use noon to be safe against DST transitions at midnight.
            let noon = cal.date(byAdding: .hour, value: 12, to: d) ?? d
            return day(containing: noon)
        }
    }

    // MARK: Events

    /// All times in `[start, end)` for `prayers`, sorted by date.
    public func events(from start: Date, to end: Date, prayers: Set<Prayer> = Set(Prayer.allCases)) -> [PrayerTime] {
        guard end > start else { return [] }
        let dayCount = Int((end.timeIntervalSince(start) / 86_400).rounded(.up)) + 3
        let yesterday = start.addingTimeInterval(-86_400)
        return days(startingAt: yesterday, count: dayCount)
            .flatMap(\.times)
            .filter { prayers.contains($0.prayer) && $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }
    }

    /// The previous/next prayer at `date`.
    /// - Parameters:
    ///   - includeSunrise: treat sunrise as an event.
    ///   - recentWindow: how long after a time started it counts as `recent`.
    public func status(at date: Date, includeSunrise: Bool = true, recentWindow: TimeInterval = 0) -> PrayerStatus? {
        let prayers = Set(Prayer.allCases.filter { includeSunrise || $0 != .sunrise })
        let events = events(from: date.addingTimeInterval(-2 * 86_400),
                            to: date.addingTimeInterval(3 * 86_400),
                            prayers: prayers)
        guard let next = events.first(where: { $0.date > date }) else { return nil }
        let previous = events.last(where: { $0.date <= date })
        var recent: PrayerTime?
        if let previous, recentWindow > 0, date.timeIntervalSince(previous.date) < recentWindow {
            recent = previous
        }
        return PrayerStatus(previous: previous, next: next, recent: recent)
    }

    /// Instants in `(start, end]` at which `status(at:)` changes, useful for
    /// widget timelines.
    public func transitionDates(from start: Date, to end: Date, includeSunrise: Bool, recentWindow: TimeInterval) -> [Date] {
        let prayers = Set(Prayer.allCases.filter { includeSunrise || $0 != .sunrise })
        var dates = Set<Date>()
        for event in events(from: start.addingTimeInterval(-max(recentWindow, 0) - 1), to: end.addingTimeInterval(1), prayers: prayers) {
            dates.insert(event.date)
            if recentWindow > 0 { dates.insert(event.date.addingTimeInterval(recentWindow)) }
        }
        return dates.filter { $0 > start && $0 <= end }.sorted()
    }

    // MARK: Notifications

    /// Notifications to schedule from `now`, honouring the user's settings and
    /// the system limit of pending notifications.
    public func notificationPlan(from now: Date, days: Int = 14, limit: Int = 64) -> [PlannedNotification] {
        let config = settings.notifications
        guard config.isEnabled else { return [] }
        var plan: [PlannedNotification] = []
        for event in events(from: now, to: now.addingTimeInterval(Double(days) * 86_400)) {
            let prefs = config[event.prayer]
            guard prefs.alert != .off else { continue }
            let sound = prefs.alert == .sound
            if event.date > now {
                plan.append(PlannedNotification(prayer: event.prayer, prayerDate: event.date, fireDate: event.date,
                                                minutesBefore: 0, playsSound: sound))
            }
            if prefs.reminderMinutes > 0 {
                let fire = event.date.addingTimeInterval(-Double(prefs.reminderMinutes) * 60)
                if fire > now {
                    plan.append(PlannedNotification(prayer: event.prayer, prayerDate: event.date, fireDate: fire,
                                                    minutesBefore: prefs.reminderMinutes, playsSound: sound))
                }
            }
        }
        plan.sort { $0.fireDate == $1.fireDate ? $0.minutesBefore > $1.minutesBefore : $0.fireDate < $1.fireDate }
        return Array(plan.prefix(max(0, limit)))
    }

    // MARK: Hijri

    /// The Hijri date for the instant `date`, honouring the adjustment and
    /// (optionally) starting the new day at Maghrib.
    public func hijriDate(at date: Date, applyMaghribRule: Bool = true) -> Date {
        var result = date
        if applyMaghribRule, settings.hijriChangesAtMaghrib,
           let maghrib = day(containing: date)[.maghrib], date >= maghrib {
            result = calendar.date(byAdding: .day, value: 1, to: result) ?? result
        }
        if settings.hijriAdjustment != 0 {
            result = calendar.date(byAdding: .day, value: settings.hijriAdjustment, to: result) ?? result
        }
        return result
    }

    public func hijriString(at date: Date, style: HijriFormatter.Style = .long, applyMaghribRule: Bool = true) -> String {
        HijriFormatter(kind: settings.hijriCalendar, timeZone: timeZone, style: style)
            .string(from: hijriDate(at: date, applyMaghribRule: applyMaghribRule))
    }

    /// Hijri date string for a prayer day (no Maghrib rule).
    public func hijriString(for day: PrayerDay, style: HijriFormatter.Style = .long) -> String {
        hijriString(at: day.day.addingTimeInterval(12 * 3600), style: style, applyMaghribRule: false)
    }

    // MARK: Formatting

    public func timeFormatter(locale: Locale = .autoupdatingCurrent) -> PrayerTimeFormatter {
        PrayerTimeFormatter(format: settings.timeFormat, timeZone: timeZone, locale: locale)
    }
}
