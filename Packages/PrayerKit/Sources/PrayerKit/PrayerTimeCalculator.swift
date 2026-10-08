//
//  PrayerTimeCalculator.swift
//  PrayerKit
//
//  Astronomical prayer time calculation.
//
//  Ported from `AKPrayerTime.swift` by Ashik Ahmad
//  (https://github.com/ashikahmad/PrayerTimes-Swift), which is "mostly converted
//  from the Objective‑C version of the similar class from praytimes.org".
//  The algorithm, method parameters and naming follow that implementation.
//
//  Changes compared to the original class:
//  * Value type, `Sendable`, Foundation only (no UIKit) so it is usable from a
//    widget extension and unit‑testable on any platform.
//  * `julianDate(from:)` used `Date()` instead of the requested date, so every
//    date returned today's times. Fixed.
//  * Julian date month correction used `month < 2` instead of `month <= 2`
//    (wrong times for every February). Fixed.
//  * `numIterations` re‑computed with the default times instead of feeding the
//    previous result back in. Fixed.
//  * The time zone offset is resolved for the requested date (DST aware)
//    instead of "now", and results are returned as absolute `Date`s.
//  * Rounding to minutes is done on the absolute instant (the original could
//    yield "hh:60").
//  * A few additional, widely used angle based methods were added.
//

import Foundation

public struct PrayerTimeCalculator: Sendable {

    // MARK: - Types

    /// Prayer calculation methods.
    public enum CalculationMethod: String, CaseIterable, Codable, Sendable, Identifiable {
        /// Muslim World League
        case mwl
        /// Islamic Society of North America
        case isna
        /// Egyptian General Authority of Survey
        case egypt
        /// Umm al-Qura University, Makkah
        case makkah
        /// University of Islamic Sciences, Karachi
        case karachi
        /// Institute of Geophysics, University of Tehran
        case tehran
        /// Shia Ithna Ashari, Leva Research Institute, Qum
        case jafari
        /// Gulf Region
        case gulf
        /// Kuwait
        case kuwait
        /// Qatar
        case qatar
        /// Majlis Ugama Islam Singapura
        case singapore
        /// Union des Organisations Islamiques de France
        case france
        /// Diyanet İşleri Başkanlığı, Turkey
        case turkey
        /// Spiritual Administration of Muslims of Russia
        case russia
        /// Dubai
        case dubai
        /// Custom, these can be changed as user sets.
        case custom

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .mwl:       return "Muslim World League"
            case .isna:      return "Islamic Society of North America"
            case .egypt:     return "Egyptian General Authority of Survey"
            case .makkah:    return "Umm al-Qura University, Makkah"
            case .karachi:   return "University of Islamic Sciences, Karachi"
            case .tehran:    return "Institute of Geophysics, University of Tehran"
            case .jafari:    return "Shia Ithna Ashari (Jafari)"
            case .gulf:      return "Gulf Region"
            case .kuwait:    return "Kuwait"
            case .qatar:     return "Qatar"
            case .singapore: return "Singapore (MUIS)"
            case .france:    return "France (UOIF)"
            case .turkey:    return "Turkey (Diyanet)"
            case .russia:    return "Russia"
            case .dubai:     return "Dubai"
            case .custom:    return "Custom"
            }
        }

        public var shortName: String {
            switch self {
            case .mwl:       return "MWL"
            case .isna:      return "ISNA"
            case .egypt:     return "Egypt"
            case .makkah:    return "Umm al-Qura"
            case .karachi:   return "Karachi"
            case .tehran:    return "Tehran"
            case .jafari:    return "Jafari"
            case .gulf:      return "Gulf"
            case .kuwait:    return "Kuwait"
            case .qatar:     return "Qatar"
            case .singapore: return "Singapore"
            case .france:    return "France"
            case .turkey:    return "Turkey"
            case .russia:    return "Russia"
            case .dubai:     return "Dubai"
            case .custom:    return "Custom"
            }
        }

        /// Default parameters for the method (`custom` starts out as MWL).
        public var parameters: MethodParameters {
            switch self {
            case .mwl:       return MethodParameters(fajrAngle: 18,   maghrib: .minutes(0), isha: .angle(17))
            case .isna:      return MethodParameters(fajrAngle: 15,   maghrib: .minutes(0), isha: .angle(15))
            case .egypt:     return MethodParameters(fajrAngle: 19.5, maghrib: .minutes(0), isha: .angle(17.5))
            case .makkah:    return MethodParameters(fajrAngle: 18.5, maghrib: .minutes(0), isha: .minutes(90))
            case .karachi:   return MethodParameters(fajrAngle: 18,   maghrib: .minutes(0), isha: .angle(18))
            case .tehran:    return MethodParameters(fajrAngle: 17.7, maghrib: .angle(4.5), isha: .angle(14))
            case .jafari:    return MethodParameters(fajrAngle: 16,   maghrib: .angle(4),   isha: .angle(14))
            case .gulf:      return MethodParameters(fajrAngle: 19.5, maghrib: .minutes(0), isha: .minutes(90))
            case .kuwait:    return MethodParameters(fajrAngle: 18,   maghrib: .minutes(0), isha: .angle(17.5))
            case .qatar:     return MethodParameters(fajrAngle: 18,   maghrib: .minutes(0), isha: .minutes(90))
            case .singapore: return MethodParameters(fajrAngle: 20,   maghrib: .minutes(0), isha: .angle(18))
            case .france:    return MethodParameters(fajrAngle: 12,   maghrib: .minutes(0), isha: .angle(12))
            case .turkey:    return MethodParameters(fajrAngle: 18,   maghrib: .minutes(0), isha: .angle(17))
            case .russia:    return MethodParameters(fajrAngle: 16,   maghrib: .minutes(0), isha: .angle(15))
            case .dubai:     return MethodParameters(fajrAngle: 18.2, maghrib: .minutes(0), isha: .angle(18.2))
            case .custom:    return CalculationMethod.mwl.parameters
            }
        }
    }

    /// Asr calculation (juristic) method.
    public enum JuristicMethod: String, CaseIterable, Codable, Sendable, Identifiable {
        /// Shafi'i, Maliki, Ja'fari, and Hanbali
        case shafii
        /// Hanafi
        case hanafi

        public var id: String { rawValue }

        /// Shadow length factor used by the Asr formula.
        public var shadowFactor: Double {
            switch self {
            case .shafii: return 1
            case .hanafi: return 2
            }
        }

        public var displayName: String {
            switch self {
            case .shafii: return "Standard"
            case .hanafi: return "Hanafi"
            }
        }

        public var detail: String {
            switch self {
            case .shafii: return "Shafi'i, Maliki, Hanbali, Ja'fari"
            case .hanafi: return "Hanafi"
            }
        }
    }

    /// Adjustment options for higher latitudes.
    public enum HigherLatitudeAdjustment: String, CaseIterable, Codable, Sendable, Identifiable {
        case none
        case midNight
        case oneSeventh
        case angleBased

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .none:       return "None"
            case .midNight:   return "Middle of the Night"
            case .oneSeventh: return "One Seventh of the Night"
            case .angleBased: return "Angle Based"
            }
        }
    }

    /// A Maghrib/Isha parameter, either a sun depression angle or a number of
    /// minutes (Maghrib: after sunset, Isha: after Maghrib).
    public enum TwilightRule: Codable, Hashable, Sendable {
        case angle(Double)
        case minutes(Double)

        public var value: Double {
            switch self {
            case .angle(let v), .minutes(let v): return v
            }
        }

        public var isMinutes: Bool {
            if case .minutes = self { return true }
            return false
        }
    }

    /// The equivalent of the original `methodParams` five element arrays
    /// `[fa, ms, mv, is, iv]` as a typed value.
    public struct MethodParameters: Codable, Hashable, Sendable {
        public var fajrAngle: Double
        public var maghrib: TwilightRule
        public var isha: TwilightRule

        public init(fajrAngle: Double, maghrib: TwilightRule, isha: TwilightRule) {
            self.fajrAngle = fajrAngle
            self.maghrib = maghrib
            self.isha = isha
        }
    }

    /// Time names, matching `AKPrayerTime.TimeNames`.
    public enum TimeName: Int, CaseIterable, Codable, Sendable, Comparable {
        case fajr    = 0
        case sunrise = 1
        case dhuhr   = 2
        case asr     = 3
        case sunset  = 4
        case maghrib = 5
        case isha    = 6

        public static func < (lhs: TimeName, rhs: TimeName) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public struct Coordinate: Codable, Hashable, Sendable {
        public var latitude: Double
        public var longitude: Double

        public init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }
    }

    // MARK: - Settings

    /// Coordinate of the place times will be calculated for.
    public var coordinate: Coordinate
    /// Prayer calculation method.
    public var calculationMethod: CalculationMethod = .mwl
    /// Parameters used when `calculationMethod == .custom`.
    public var customParameters: MethodParameters = CalculationMethod.mwl.parameters
    /// Asr method, `shafii` or `hanafi`.
    public var asrJuristic: JuristicMethod = .shafii
    /// Adjustment for higher latitudes.
    public var highLatitudeAdjustment: HigherLatitudeAdjustment = .midNight
    /// Minutes added to Dhuhr after the sun's zenith.
    public var dhuhrMinutes: Double = 0
    /// Per time offsets in minutes ("tune").
    public var offsets: [TimeName: Double] = [:]
    /// Number of iterations used to refine the times. The original defaulted
    /// to 1 (and its loop had no effect); 2 iterations agree with independent
    /// implementations to within rounding (see the unit tests).
    public var numIterations: Int = 2

    public init(coordinate: Coordinate) {
        self.coordinate = coordinate
    }

    public init(latitude: Double, longitude: Double) {
        self.init(coordinate: Coordinate(latitude: latitude, longitude: longitude))
    }

    /// The parameters that are effectively used.
    public var parameters: MethodParameters {
        calculationMethod == .custom ? customParameters : calculationMethod.parameters
    }

    // MARK: - Public API

    /// Prayer times as absolute dates for the given local calendar day in
    /// `timeZone`. A value is `nil` when it can't be computed (e.g. polar day
    /// with no high latitude adjustment).
    public func times(year: Int, month: Int, day: Int, timeZone: TimeZone) -> [TimeName: Date] {
        let offset = Self.utcOffsetHours(year: year, month: month, day: day, timeZone: timeZone)
        let hours = floatTimes(year: year, month: month, day: day, timeZoneOffset: offset)

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        guard let utcMidnight = utcCalendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return [:]
        }

        var result: [TimeName: Date] = [:]
        for (name, h) in hours where h.isFinite {
            // Hours are local clock hours for `offset`; convert to UT.
            let minutes = ((h - offset) * 60).rounded()
            result[name] = utcMidnight.addingTimeInterval(minutes * 60)
        }
        return result
    }

    /// Prayer times for the calendar day containing `date` in `timeZone`.
    public func times(on date: Date, timeZone: TimeZone) -> [TimeName: Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return times(year: c.year!, month: c.month!, day: c.day!, timeZone: timeZone)
    }

    /// Prayer times as floating point local hours (e.g. 13.5 == 13:30) for the
    /// given date and UTC offset in hours. Values may lie outside 0..<24 and
    /// are `NaN` when they cannot be computed.
    public func floatTimes(year: Int, month: Int, day: Int, timeZoneOffset: Double) -> [TimeName: Double] {
        let jDate = Self.julianDate(year: year, month: month, day: day) - coordinate.longitude / (15.0 * 24.0)
        return computeDayTimes(jDate: jDate, timeZone: timeZoneOffset)
    }

    // MARK: - Utility

    /// UTC offset in hours of `timeZone` at local noon of the given day.
    public static func utcOffsetHours(year: Int, month: Int, day: Int, timeZone: TimeZone) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let noon = cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
        return Double(timeZone.secondsFromGMT(for: noon)) / 3600.0
    }

    // MARK: - Julian Date Calculation

    static func julianDate(year: Int, month: Int, day: Int) -> Double {
        var yyear = year, mmonth = month
        if mmonth <= 2 {
            yyear -= 1
            mmonth += 12
        }

        let A = floor(Double(yyear) / 100.0)
        let B = 2.0 - A + floor(A / 4.0)

        return floor(365.25 * (Double(yyear) + 4716.0))
            + floor(30.6001 * (Double(mmonth) + 1.0))
            + Double(day) + B - 1524.5
    }

    // MARK: - Calculation Functions
    // References: http://praytimes.org/calculation/

    /// Compute declination angle of sun and equation of time.
    private func sunPosition(_ jd: Double) -> (declination: Double, equation: Double) {
        let D = jd - 2451545.0
        let g = DMath.fixAngle(357.529 + 0.98560028 * D)
        let q = DMath.fixAngle(280.459 + 0.98564736 * D)
        let L = DMath.fixAngle(q + (1.915 * DMath.dSin(g)) + (0.020 * DMath.dSin(2 * g)))

        let e = 23.439 - (0.00000036 * D)
        var RA = DMath.dArcTan2(DMath.dCos(e) * DMath.dSin(L), x: DMath.dCos(L)) / 15.0
        RA = fixHour(RA)

        let d = DMath.dArcSin(DMath.dSin(e) * DMath.dSin(L))
        let EqT = q / 15.0 - RA

        return (d, EqT)
    }

    /// Compute mid-day (Dhuhr, Zawal) time.
    private func computeMidDay(jDate: Double, _ t: Double) -> Double {
        let T = sunPosition(jDate + t).equation
        return fixHour(12 - T)
    }

    /// Compute time for a given angle G.
    private func computeTime(jDate: Double, _ G: Double, t: Double) -> Double {
        let D = sunPosition(jDate + t).declination
        let Z = computeMidDay(jDate: jDate, t)
        let lat = coordinate.latitude
        let V = DMath.dArcCos((-DMath.dSin(G) - (DMath.dSin(D) * DMath.dSin(lat))) / (DMath.dCos(D) * DMath.dCos(lat))) / 15.0

        return G > 90 ? Z - V : Z + V
    }

    /// Compute the time of Asr. Shafii: step=1, Hanafi: step=2
    private func computeAsr(jDate: Double, step: Double, t: Double) -> Double {
        let d = sunPosition(jDate + t).declination
        let g = -DMath.dArcCot(step + DMath.dTan(abs(coordinate.latitude - d)))
        return computeTime(jDate: jDate, g, t: t)
    }

    /// Compute the difference between two times.
    private func timeDiff(_ time1: Double, _ time2: Double) -> Double {
        fixHour(time2 - time1)
    }

    // MARK: - Compute Prayer Times

    private static let defaultDayTimes: [TimeName: Double] = [
        .fajr: 5.0, .sunrise: 6.0, .dhuhr: 12.0, .asr: 13.0,
        .sunset: 18.0, .maghrib: 18.0, .isha: 18.0
    ]

    /// Compute prayer times at given julian date.
    private func computeTimes(jDate: Double, _ times: [TimeName: Double]) -> [TimeName: Double] {
        let t = dayPortion(times)
        let params = parameters

        let fajr    = computeTime(jDate: jDate, 180.0 - params.fajrAngle, t: t[.fajr]!)
        let sunrise = computeTime(jDate: jDate, 180.0 - 0.833, t: t[.sunrise]!)
        let dhuhr   = computeMidDay(jDate: jDate, t[.dhuhr]!)
        let asr     = computeAsr(jDate: jDate, step: asrJuristic.shadowFactor, t: t[.asr]!)
        let sunset  = computeTime(jDate: jDate, 0.833, t: t[.sunset]!)
        let maghrib = computeTime(jDate: jDate, params.maghrib.isMinutes ? 0.833 : params.maghrib.value, t: t[.maghrib]!)
        let isha    = computeTime(jDate: jDate, params.isha.isMinutes ? 18 : params.isha.value, t: t[.isha]!)

        return [
            .fajr: fajr, .sunrise: sunrise, .dhuhr: dhuhr, .asr: asr,
            .sunset: sunset, .maghrib: maghrib, .isha: isha
        ]
    }

    private func computeDayTimes(jDate: Double, timeZone: Double) -> [TimeName: Double] {
        var times = Self.defaultDayTimes
        for _ in 0..<max(1, numIterations) {
            times = computeTimes(jDate: jDate, times)
        }
        times = adjustTimes(times, timeZone: timeZone)
        return tuneTimes(times)
    }

    /// Apply the per time offsets.
    private func tuneTimes(_ times: [TimeName: Double]) -> [TimeName: Double] {
        var ttimes = times
        for (name, time) in times {
            ttimes[name] = time + (offsets[name] ?? 0) / 60.0
        }
        return ttimes
    }

    /// Range reduce hours to 0..23
    private func fixHour(_ a: Double) -> Double {
        DMath.wrap(a, min: 0, max: 24)
    }

    /// Adjust times in a prayer time array.
    private func adjustTimes(_ times: [TimeName: Double], timeZone: Double) -> [TimeName: Double] {
        var ttimes = times
        for (name, time) in ttimes {
            ttimes[name] = time + (timeZone - coordinate.longitude / 15.0)
        }

        ttimes[.dhuhr] = ttimes[.dhuhr]! + dhuhrMinutes / 60.0

        let params = parameters
        if case .minutes(let m) = params.maghrib {
            ttimes[.maghrib] = ttimes[.sunset]! + m / 60.0
        }
        if case .minutes(let m) = params.isha {
            ttimes[.isha] = ttimes[.maghrib]! + m / 60.0
        }

        if highLatitudeAdjustment != .none {
            ttimes = adjustHighLatTimes(ttimes)
        }
        return ttimes
    }

    /// Adjust Fajr, Isha and Maghrib for locations in higher latitudes.
    private func adjustHighLatTimes(_ times: [TimeName: Double]) -> [TimeName: Double] {
        var ttimes = times
        let params = parameters
        guard let sunrise = ttimes[.sunrise], let sunset = ttimes[.sunset],
              sunrise.isFinite, sunset.isFinite else { return ttimes }

        let nightTime = timeDiff(sunset, sunrise) // sunset to sunrise

        // Adjust Fajr
        let fajrDiff = nightPortion(angle: params.fajrAngle) * nightTime
        if ttimes[.fajr]!.isNaN || timeDiff(ttimes[.fajr]!, sunrise) > fajrDiff {
            ttimes[.fajr] = sunrise - fajrDiff
        }

        // Adjust Isha
        let ishaAngle = params.isha.isMinutes ? 18.0 : params.isha.value
        let ishaDiff = nightPortion(angle: ishaAngle) * nightTime
        if ttimes[.isha]!.isNaN || timeDiff(sunset, ttimes[.isha]!) > ishaDiff {
            ttimes[.isha] = sunset + ishaDiff
        }

        // Adjust Maghrib
        let maghribAngle = params.maghrib.isMinutes ? 4.0 : params.maghrib.value
        let maghribDiff = nightPortion(angle: maghribAngle) * nightTime
        if ttimes[.maghrib]!.isNaN || timeDiff(sunset, ttimes[.maghrib]!) > maghribDiff {
            ttimes[.maghrib] = sunset + maghribDiff
        }

        return ttimes
    }

    /// The night portion used for adjusting times in higher latitudes.
    private func nightPortion(angle: Double) -> Double {
        switch highLatitudeAdjustment {
        case .none:       return 0.0
        case .angleBased: return angle / 60.0
        case .midNight:   return 0.5
        case .oneSeventh: return 1.0 / 7.0
        }
    }

    /// Convert hours to day portions.
    private func dayPortion(_ times: [TimeName: Double]) -> [TimeName: Double] {
        times.mapValues { $0 / 24.0 }
    }
}

// MARK: - Trigonometric Functions

enum DMath {
    static func wrap(_ a: Double, min: Double, max: Double) -> Double {
        var aa = a
        let range = max - min
        aa.formTruncatingRemainder(dividingBy: range)
        if aa < min { aa += range }
        if aa > max { aa -= range }
        return aa
    }

    /// Range reduce angle in degrees.
    static func fixAngle(_ a: Double) -> Double { wrap(a, min: 0, max: 360) }

    static func radiansToDegrees(_ alpha: Double) -> Double { (alpha * 180.0) / Double.pi }
    static func degreesToRadians(_ alpha: Double) -> Double { (alpha * Double.pi) / 180.0 }

    static func dSin(_ d: Double) -> Double { sin(degreesToRadians(d)) }
    static func dCos(_ d: Double) -> Double { cos(degreesToRadians(d)) }
    static func dTan(_ d: Double) -> Double { tan(degreesToRadians(d)) }

    static func dArcSin(_ x: Double) -> Double { radiansToDegrees(asin(x)) }
    static func dArcCos(_ x: Double) -> Double { radiansToDegrees(acos(x)) }
    static func dArcTan(_ x: Double) -> Double { radiansToDegrees(atan(x)) }
    static func dArcTan2(_ y: Double, x: Double) -> Double { radiansToDegrees(atan2(y, x)) }
    static func dArcCot(_ x: Double) -> Double { radiansToDegrees(atan2(1.0, x)) }
}
