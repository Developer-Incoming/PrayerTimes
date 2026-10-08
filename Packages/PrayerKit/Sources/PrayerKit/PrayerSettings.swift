//
//  PrayerSettings.swift
//  PrayerKit
//

import Foundation

/// A location times are calculated for.
public struct SavedLocation: Codable, Hashable, Sendable {
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var timeZoneIdentifier: String

    public init(name: String, latitude: Double, longitude: Double, timeZoneIdentifier: String) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }

    public var coordinate: PrayerTimeCalculator.Coordinate {
        .init(latitude: latitude, longitude: longitude)
    }

    /// e.g. "21.4225° N, 39.8262° E"
    public var coordinateDescription: String {
        let lat = String(format: "%.4f° %@", abs(latitude), latitude >= 0 ? "N" : "S")
        let lng = String(format: "%.4f° %@", abs(longitude), longitude >= 0 ? "E" : "W")
        return "\(lat), \(lng)"
    }
}

public enum TimeFormatPreference: String, CaseIterable, Codable, Sendable, Identifiable {
    case system
    case twelveHour
    case twentyFourHour

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system:         return "System"
        case .twelveHour:     return "12-Hour"
        case .twentyFourHour: return "24-Hour"
        }
    }
}

public enum HijriCalendarKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case ummAlQura
    case civil
    case tabular
    case astronomical

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .ummAlQura:    return "Umm al-Qura"
        case .civil:        return "Civil"
        case .tabular:      return "Tabular"
        case .astronomical: return "Astronomical"
        }
    }

    public var identifier: Calendar.Identifier {
        switch self {
        case .ummAlQura:    return .islamicUmmAlQura
        case .civil:        return .islamicCivil
        case .tabular:      return .islamicTabular
        case .astronomical: return .islamic
        }
    }
}

/// How a prayer time notification is delivered.
public enum NotificationAlert: String, CaseIterable, Codable, Sendable, Identifiable {
    case off
    case silent
    case sound

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .off:    return "Off"
        case .silent: return "Silent"
        case .sound:  return "Sound"
        }
    }

    public var detail: String {
        switch self {
        case .off:    return "No notification"
        case .silent: return "Notification without sound"
        case .sound:  return "Notification with the default sound"
        }
    }
}

/// Notification preferences for one prayer.
public struct PrayerNotificationSettings: Codable, Hashable, Sendable {
    public var alert: NotificationAlert
    /// Minutes before the prayer time for an additional reminder, 0 = none.
    public var reminderMinutes: Int

    public static let reminderChoices = [0, 5, 10, 15, 20, 30, 45, 60]

    public init(alert: NotificationAlert = .sound, reminderMinutes: Int = 0) {
        self.alert = alert
        self.reminderMinutes = reminderMinutes
    }

    public static func defaultSettings(for prayer: Prayer) -> PrayerNotificationSettings {
        PrayerNotificationSettings(alert: prayer == .sunrise ? .off : .sound, reminderMinutes: 0)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        alert = c.value(.alert, default: .sound)
        reminderMinutes = c.value(.reminderMinutes, default: 0)
    }
}

public struct NotificationSettings: Codable, Hashable, Sendable {
    /// Master switch.
    public var isEnabled: Bool
    /// Deliver prayer notifications as Time Sensitive (breaks through Focus).
    public var timeSensitive: Bool
    /// Keyed by `Prayer.rawValue`.
    private var prayers: [String: PrayerNotificationSettings]

    public init(isEnabled: Bool = false, timeSensitive: Bool = true) {
        self.isEnabled = isEnabled
        self.timeSensitive = timeSensitive
        self.prayers = [:]
    }

    public subscript(prayer: Prayer) -> PrayerNotificationSettings {
        get { prayers[prayer.rawValue] ?? .defaultSettings(for: prayer) }
        set { prayers[prayer.rawValue] = newValue }
    }

    /// Whether any notification would be delivered at all.
    public var hasActiveAlerts: Bool {
        isEnabled && Prayer.allCases.contains { self[$0].alert != .off }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = c.value(.isEnabled, default: false)
        timeSensitive = c.value(.timeSensitive, default: true)
        prayers = c.value(.prayers, default: [:])
    }
}

/// All user settings shared between the app and the widget.
public struct PrayerSettings: Codable, Hashable, Sendable {
    // Location
    public var useCurrentLocation: Bool = true
    public var location: SavedLocation?

    // Calculation
    public var calculationMethod: PrayerTimeCalculator.CalculationMethod = .mwl
    public var asrMethod: PrayerTimeCalculator.JuristicMethod = .shafii
    public var highLatitudeRule: PrayerTimeCalculator.HigherLatitudeAdjustment = .midNight
    public var customParameters: PrayerTimeCalculator.MethodParameters = PrayerTimeCalculator.CalculationMethod.mwl.parameters
    /// Manual per prayer adjustment in minutes keyed by `Prayer.rawValue`.
    private var offsets: [String: Int] = [:]

    // Display
    public var timeFormat: TimeFormatPreference = .system
    public var hijriCalendar: HijriCalendarKind = .ummAlQura
    /// Days added to the computed Hijri date (-2...2).
    public var hijriAdjustment: Int = 0
    /// Start the next Hijri day at Maghrib instead of midnight.
    public var hijriChangesAtMaghrib: Bool = false

    // Notifications
    public var notifications = NotificationSettings()

    public init() {}

    public func offset(for prayer: Prayer) -> Int { offsets[prayer.rawValue] ?? 0 }

    public mutating func setOffset(_ minutes: Int, for prayer: Prayer) {
        offsets[prayer.rawValue] = minutes == 0 ? nil : minutes
    }

    public var hasOffsets: Bool { offsets.values.contains { $0 != 0 } }

    public mutating func resetOffsets() { offsets = [:] }

    /// Effective calculation parameters.
    public var effectiveParameters: PrayerTimeCalculator.MethodParameters {
        calculationMethod == .custom ? customParameters : calculationMethod.parameters
    }

    /// A configured calculator, or `nil` when no location is known yet.
    public var calculator: PrayerTimeCalculator? {
        guard let location else { return nil }
        var calc = PrayerTimeCalculator(coordinate: location.coordinate)
        calc.calculationMethod = calculationMethod
        calc.customParameters = customParameters
        calc.asrJuristic = asrMethod
        calc.highLatitudeAdjustment = highLatitudeRule
        var tune: [PrayerTimeCalculator.TimeName: Double] = [:]
        for prayer in Prayer.allCases {
            tune[prayer.timeName] = Double(offset(for: prayer))
        }
        calc.offsets = tune
        return calc
    }

    /// Settings that change the computed times (used to decide when to
    /// reschedule notifications and reload widgets).
    public var calculationSignature: String {
        let enc = JSONEncoder()
        enc.outputFormatting = .sortedKeys
        struct Sig: Encodable {
            var location: SavedLocation?
            var method: PrayerTimeCalculator.CalculationMethod
            var asr: PrayerTimeCalculator.JuristicMethod
            var highLat: PrayerTimeCalculator.HigherLatitudeAdjustment
            var custom: PrayerTimeCalculator.MethodParameters
            var offsets: [String: Int]
        }
        let sig = Sig(location: location, method: calculationMethod, asr: asrMethod,
                      highLat: highLatitudeRule, custom: customParameters, offsets: offsets)
        return (try? enc.encode(sig)).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }

    // MARK: Codable (tolerant to missing keys so new settings never wipe old ones)

    private enum CodingKeys: String, CodingKey {
        case useCurrentLocation, location, calculationMethod, asrMethod, highLatitudeRule,
             customParameters, offsets, timeFormat, hijriCalendar, hijriAdjustment,
             hijriChangesAtMaghrib, notifications
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PrayerSettings()
        useCurrentLocation = c.value(.useCurrentLocation, default: d.useCurrentLocation)
        location = c.value(.location, default: d.location)
        calculationMethod = c.value(.calculationMethod, default: d.calculationMethod)
        asrMethod = c.value(.asrMethod, default: d.asrMethod)
        highLatitudeRule = c.value(.highLatitudeRule, default: d.highLatitudeRule)
        customParameters = c.value(.customParameters, default: d.customParameters)
        offsets = c.value(.offsets, default: d.offsets)
        timeFormat = c.value(.timeFormat, default: d.timeFormat)
        hijriCalendar = c.value(.hijriCalendar, default: d.hijriCalendar)
        hijriAdjustment = c.value(.hijriAdjustment, default: d.hijriAdjustment)
        hijriChangesAtMaghrib = c.value(.hijriChangesAtMaghrib, default: d.hijriChangesAtMaghrib)
        notifications = c.value(.notifications, default: d.notifications)
    }
}

extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key, default defaultValue: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? defaultValue
    }
}
