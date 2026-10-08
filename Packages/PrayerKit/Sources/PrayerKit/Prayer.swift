//
//  Prayer.swift
//  PrayerKit
//

import Foundation

/// The daily times shown by the app.
public enum Prayer: String, CaseIterable, Codable, Sendable, Identifiable, Comparable {
    case fajr
    case sunrise
    case dhuhr
    case asr
    case maghrib
    case isha

    public var id: String { rawValue }

    /// Prayers for which notifications can be configured and that are shown in
    /// the list (in display order).
    public static let displayed: [Prayer] = Prayer.allCases

    /// The five obligatory prayers (sunrise excluded).
    public static let obligatory: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]

    public var isObligatory: Bool { self != .sunrise }

    public var displayName: String {
        switch self {
        case .fajr:    return "Fajr"
        case .sunrise: return "Sunrise"
        case .dhuhr:   return "Dhuhr"
        case .asr:     return "Asr"
        case .maghrib: return "Maghrib"
        case .isha:    return "Isha"
        }
    }

    /// SF Symbol representing the time of the day.
    public var systemImage: String {
        switch self {
        case .fajr:    return "sun.horizon"
        case .sunrise: return "sunrise"
        case .dhuhr:   return "sun.max"
        case .asr:     return "sun.min"
        case .maghrib: return "sunset"
        case .isha:    return "moon.stars"
        }
    }

    var timeName: PrayerTimeCalculator.TimeName {
        switch self {
        case .fajr:    return .fajr
        case .sunrise: return .sunrise
        case .dhuhr:   return .dhuhr
        case .asr:     return .asr
        case .maghrib: return .maghrib
        case .isha:    return .isha
        }
    }

    private var order: Int { Prayer.allCases.firstIndex(of: self)! }

    public static func < (lhs: Prayer, rhs: Prayer) -> Bool { lhs.order < rhs.order }
}

/// A single prayer occurrence.
public struct PrayerTime: Hashable, Sendable, Identifiable {
    public var prayer: Prayer
    public var date: Date

    public var id: String { "\(prayer.rawValue)-\(Int(date.timeIntervalSince1970))" }

    public init(prayer: Prayer, date: Date) {
        self.prayer = prayer
        self.date = date
    }
}

/// All prayer times of one calendar day at a location.
public struct PrayerDay: Hashable, Sendable, Identifiable {
    /// Start of the day in `timeZone`.
    public var day: Date
    public var timeZone: TimeZone
    /// Times in display order. Times that can't be computed are omitted.
    public var times: [PrayerTime]

    public var id: Date { day }

    public init(day: Date, timeZone: TimeZone, times: [PrayerTime]) {
        self.day = day
        self.timeZone = timeZone
        self.times = times
    }

    public func time(for prayer: Prayer) -> Date? {
        times.first { $0.prayer == prayer }?.date
    }

    public subscript(prayer: Prayer) -> Date? { time(for: prayer) }
}
