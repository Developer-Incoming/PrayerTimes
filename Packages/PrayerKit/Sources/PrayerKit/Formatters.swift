//
//  Formatters.swift
//  PrayerKit
//

import Foundation

/// Formats prayer times in the location's time zone using the user's
/// 12/24‑hour preference.
public final class PrayerTimeFormatter: @unchecked Sendable {
    private let formatter: DateFormatter

    public init(format: TimeFormatPreference, timeZone: TimeZone, locale: Locale = .autoupdatingCurrent) {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = timeZone
        switch format {
        case .system:
            f.dateStyle = .none
            f.timeStyle = .short
        case .twelveHour:
            f.dateFormat = DateFormatter.dateFormat(fromTemplate: "hmma", options: 0, locale: locale) ?? "h:mm a"
        case .twentyFourHour:
            f.dateFormat = DateFormatter.dateFormat(fromTemplate: "HHmm", options: 0, locale: locale) ?? "HH:mm"
        }
        formatter = f
    }

    public func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}

/// Formats Hijri dates.
public struct HijriFormatter: Sendable {
    public enum Style: Sendable {
        /// e.g. "Rabiʻ II 25, 1448 AH"
        case long
        /// e.g. "Rabiʻ II 25"
        case dayMonth
        /// e.g. "25/4/1448 AH"
        case numeric
    }

    public var kind: HijriCalendarKind
    public var timeZone: TimeZone
    public var style: Style
    public var locale: Locale

    public init(kind: HijriCalendarKind, timeZone: TimeZone, style: Style = .long, locale: Locale = .autoupdatingCurrent) {
        self.kind = kind
        self.timeZone = timeZone
        self.style = style
        self.locale = locale
    }

    public func string(from date: Date) -> String {
        var calendar = Calendar(identifier: kind.identifier)
        calendar.timeZone = timeZone
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = locale
        f.timeZone = timeZone
        let template: String
        switch style {
        case .long:     template = "dMMMMyG"
        case .dayMonth: template = "dMMMM"
        case .numeric:  template = "dMyG"
        }
        f.dateFormat = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: locale) ?? "d MMMM y G"
        return f.string(from: date)
    }

    /// Hijri day, month and year numbers.
    public func components(from date: Date) -> (day: Int, month: Int, year: Int) {
        var calendar = Calendar(identifier: kind.identifier)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.day, .month, .year], from: date)
        return (c.day ?? 0, c.month ?? 0, c.year ?? 0)
    }
}
