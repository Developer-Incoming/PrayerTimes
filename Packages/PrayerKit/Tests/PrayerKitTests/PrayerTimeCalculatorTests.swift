//
//  PrayerTimeCalculatorTests.swift
//  PrayerKitTests
//

import XCTest
@testable import PrayerKit

final class PrayerTimeCalculatorTests: XCTestCase {

    private struct Row {
        var city: String, lat: Double, lng: Double, tz: String
        var year: Int, month: Int, day: Int
        var method: PrayerTimeCalculator.CalculationMethod
        var asr: PrayerTimeCalculator.JuristicMethod
        var expected: [PrayerTimeCalculator.TimeName: Date]
    }

    private func referenceRows() throws -> [Row] {
        let raw = try JSONSerialization.jsonObject(with: Data(referenceJSON.utf8)) as! [[Any]]
        return raw.map { r in
            let names: [PrayerTimeCalculator.TimeName] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]
            var expected: [PrayerTimeCalculator.TimeName: Date] = [:]
            for (i, name) in names.enumerated() {
                expected[name] = Date(timeIntervalSince1970: (r[9 + i] as! NSNumber).doubleValue)
            }
            return Row(city: r[0] as! String,
                       lat: (r[1] as! NSNumber).doubleValue, lng: (r[2] as! NSNumber).doubleValue,
                       tz: r[3] as! String,
                       year: (r[4] as! NSNumber).intValue, month: (r[5] as! NSNumber).intValue,
                       day: (r[6] as! NSNumber).intValue,
                       method: PrayerTimeCalculator.CalculationMethod(rawValue: r[7] as! String)!,
                       asr: PrayerTimeCalculator.JuristicMethod(rawValue: r[8] as! String)!,
                       expected: expected)
        }
    }

    /// The port must agree with an independent implementation within a
    /// couple of minutes (algorithms differ slightly in precision).
    func testMatchesIndependentReference() throws {
        let rows = try referenceRows()
        XCTAssertGreaterThan(rows.count, 300)
        var maxDiff: TimeInterval = 0
        var worst = ""
        for row in rows {
            var calc = PrayerTimeCalculator(latitude: row.lat, longitude: row.lng)
            calc.calculationMethod = row.method
            calc.asrJuristic = row.asr
            let times = calc.times(year: row.year, month: row.month, day: row.day,
                                   timeZone: TimeZone(identifier: row.tz)!)
            for (name, expected) in row.expected {
                guard let actual = times[name] else {
                    XCTFail("Missing \(name) for \(row.city) \(row.year)-\(row.month)-\(row.day)")
                    continue
                }
                let diff = abs(actual.timeIntervalSince(expected))
                if diff > maxDiff {
                    maxDiff = diff
                    worst = "\(row.city) \(row.year)-\(row.month)-\(row.day) \(row.method) \(row.asr) \(name)"
                }
                XCTAssertLessThanOrEqual(diff, 60, "\(row.city) \(row.year)-\(row.month)-\(row.day) \(row.method) \(row.asr) \(name)")
            }
        }
        print("Max difference vs reference: \(maxDiff / 60) min (\(worst))")
    }

    /// The original `julianDate(from:)` ignored the date and always used today.
    func testDifferentDatesGiveDifferentTimes() {
        let calc = PrayerTimeCalculator(latitude: 51.5074, longitude: -0.1278)
        let tz = TimeZone(identifier: "Europe/London")!
        let winter = calc.times(year: 2026, month: 1, day: 1, timeZone: tz)
        let summer = calc.times(year: 2026, month: 7, day: 1, timeZone: tz)
        let winterLength = winter[.sunset]!.timeIntervalSince(winter[.sunrise]!)
        let summerLength = summer[.sunset]!.timeIntervalSince(summer[.sunrise]!)
        XCTAssertGreaterThan(summerLength - winterLength, 7 * 3600)
    }

    /// The original compared `month < 2`, which broke all February dates.
    func testFebruaryIsContinuous() {
        let calc = PrayerTimeCalculator(latitude: 23.810332, longitude: 90.4125181)
        let tz = TimeZone(identifier: "Asia/Dhaka")!
        let jan31 = calc.times(year: 2026, month: 1, day: 31, timeZone: tz)
        let feb1 = calc.times(year: 2026, month: 2, day: 1, timeZone: tz)
        let feb28 = calc.times(year: 2026, month: 2, day: 28, timeZone: tz)
        let mar1 = calc.times(year: 2026, month: 3, day: 1, timeZone: tz)
        for name in PrayerTimeCalculator.TimeName.allCases {
            XCTAssertEqual(feb1[name]!.timeIntervalSince(jan31[name]!), 86_400, accuracy: 180, "\(name)")
            XCTAssertEqual(mar1[name]!.timeIntervalSince(feb28[name]!), 86_400, accuracy: 180, "\(name)")
        }
    }

    func testJulianDate() {
        // 2000-01-01 00:00 UT == JD 2451544.5
        XCTAssertEqual(PrayerTimeCalculator.julianDate(year: 2000, month: 1, day: 1), 2451544.5)
        // 2026-02-15 00:00 UT == JD 2461086.5
        XCTAssertEqual(PrayerTimeCalculator.julianDate(year: 2026, month: 2, day: 15), 2461086.5)
        XCTAssertEqual(PrayerTimeCalculator.julianDate(year: 2024, month: 3, day: 1), 2460370.5)
    }

    func testTimesAreOrderedAndRoundedToMinutes() {
        let calc = PrayerTimeCalculator(latitude: 21.4225, longitude: 39.8262)
        let t = calc.times(year: 2026, month: 10, day: 7, timeZone: TimeZone(identifier: "Asia/Riyadh")!)
        let order: [PrayerTimeCalculator.TimeName] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]
        for (a, b) in zip(order, order.dropFirst()) {
            XCTAssertLessThan(t[a]!, t[b]!, "\(a) < \(b)")
        }
        for date in t.values {
            XCTAssertEqual(date.timeIntervalSince1970.truncatingRemainder(dividingBy: 60), 0)
        }
    }

    func testHanafiAsrIsLater() {
        var calc = PrayerTimeCalculator(latitude: 24.8607, longitude: 67.0011)
        let tz = TimeZone(identifier: "Asia/Karachi")!
        let shafii = calc.times(year: 2026, month: 10, day: 7, timeZone: tz)[.asr]!
        calc.asrJuristic = .hanafi
        let hanafi = calc.times(year: 2026, month: 10, day: 7, timeZone: tz)[.asr]!
        XCTAssertGreaterThan(hanafi.timeIntervalSince(shafii), 30 * 60)
    }

    func testMinuteBasedIsha() {
        var calc = PrayerTimeCalculator(latitude: 21.4225, longitude: 39.8262)
        calc.calculationMethod = .makkah
        let t = calc.times(year: 2026, month: 10, day: 7, timeZone: TimeZone(identifier: "Asia/Riyadh")!)
        XCTAssertEqual(t[.isha]!.timeIntervalSince(t[.maghrib]!), 90 * 60, accuracy: 60)
    }

    func testCustomParametersAndOffsets() {
        var calc = PrayerTimeCalculator(latitude: 40.7128, longitude: -74.006)
        let tz = TimeZone(identifier: "America/New_York")!
        let base = calc.times(year: 2026, month: 10, day: 7, timeZone: tz)
        calc.calculationMethod = .custom
        calc.customParameters = .init(fajrAngle: 15, maghrib: .minutes(3), isha: .minutes(60))
        calc.offsets = [.dhuhr: 5]
        let custom = calc.times(year: 2026, month: 10, day: 7, timeZone: tz)
        XCTAssertGreaterThan(custom[.fajr]!, base[.fajr]!) // smaller angle == later
        XCTAssertEqual(custom[.maghrib]!.timeIntervalSince(custom[.sunset]!), 3 * 60, accuracy: 60)
        XCTAssertEqual(custom[.isha]!.timeIntervalSince(custom[.maghrib]!), 60 * 60, accuracy: 60)
        XCTAssertEqual(custom[.dhuhr]!.timeIntervalSince(base[.dhuhr]!), 5 * 60, accuracy: 60)
    }

    func testDaylightSavingTransition() {
        // DST starts in New York on 2026-03-08 at 02:00.
        let calc = PrayerTimeCalculator(latitude: 40.7128, longitude: -74.006)
        let tz = TimeZone(identifier: "America/New_York")!
        let before = calc.times(year: 2026, month: 3, day: 7, timeZone: tz)
        let after = calc.times(year: 2026, month: 3, day: 8, timeZone: tz)
        // Absolute instants move by ~1 day, the local clock by ~1 hour.
        XCTAssertEqual(after[.dhuhr]!.timeIntervalSince(before[.dhuhr]!), 86_400, accuracy: 60)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        XCTAssertEqual(cal.component(.hour, from: before[.dhuhr]!), 12)
        XCTAssertEqual(cal.component(.hour, from: after[.dhuhr]!), 13)
    }

    func testHighLatitudeAdjustment() {
        // Tromsø around the summer solstice: the sun never sets.
        var calc = PrayerTimeCalculator(latitude: 69.6492, longitude: 18.9553)
        let tz = TimeZone(identifier: "Europe/Oslo")!
        calc.highLatitudeAdjustment = .none
        let none = calc.times(year: 2026, month: 6, day: 21, timeZone: tz)
        XCTAssertNil(none[.fajr])
        XCTAssertNil(none[.isha])
        XCTAssertNotNil(none[.dhuhr])

        // London in June: no true night for 18°, adjustments must kick in.
        calc = PrayerTimeCalculator(latitude: 51.5074, longitude: -0.1278)
        let london = TimeZone(identifier: "Europe/London")!
        calc.highLatitudeAdjustment = .none
        XCTAssertNil(calc.times(year: 2026, month: 6, day: 21, timeZone: london)[.fajr])
        for rule in [PrayerTimeCalculator.HigherLatitudeAdjustment.midNight, .oneSeventh, .angleBased] {
            calc.highLatitudeAdjustment = rule
            let t = calc.times(year: 2026, month: 6, day: 21, timeZone: london)
            XCTAssertNotNil(t[.fajr], "\(rule)")
            XCTAssertNotNil(t[.isha], "\(rule)")
            XCTAssertLessThan(t[.fajr]!, t[.sunrise]!, "\(rule)")
            XCTAssertGreaterThan(t[.isha]!, t[.maghrib]!, "\(rule)")
        }
    }

    func testFloatTimesMatchOriginalApiShape() {
        let calc = PrayerTimeCalculator(latitude: 23.810332, longitude: 90.4125181)
        let hours = calc.floatTimes(year: 2026, month: 10, day: 7, timeZoneOffset: 6)
        XCTAssertEqual(hours.count, 7)
        XCTAssertEqual(hours[.dhuhr]!, 11.75, accuracy: 0.1) // ~11:45 in Dhaka
    }

    func testAllMethodsProduceOrderedTimes() {
        for method in PrayerTimeCalculator.CalculationMethod.allCases {
            var calc = PrayerTimeCalculator(latitude: 30.0444, longitude: 31.2357)
            calc.calculationMethod = method
            let t = calc.times(year: 2026, month: 10, day: 7, timeZone: TimeZone(identifier: "Africa/Cairo")!)
            let order: [PrayerTimeCalculator.TimeName] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]
            for (a, b) in zip(order, order.dropFirst()) {
                XCTAssertLessThan(t[a]!, t[b]!, "\(method): \(a) < \(b)")
            }
        }
    }
}
