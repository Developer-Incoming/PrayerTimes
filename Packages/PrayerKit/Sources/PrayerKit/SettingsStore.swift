//
//  SettingsStore.swift
//  PrayerKit
//

import Foundation

/// Persists `PrayerSettings` in the shared App Group container so the widget
/// extension sees the same settings as the app.
public enum SettingsStore {
    /// Info.plist key holding the App Group identifier (set from the
    /// `APP_GROUP_ID` build setting in both the app and widget targets).
    public static let appGroupInfoKey = "AppGroupIdentifier"
    static let settingsKey = "PrayerSettings.v1"

    public static var appGroupIdentifier: String? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: appGroupInfoKey) as? String,
              !id.isEmpty, !id.contains("$(") else { return nil }
        return id
    }

    /// Shared defaults (falls back to `.standard` when the App Group is not
    /// configured, e.g. in unit tests).
    public static var defaults: UserDefaults {
        if let id = appGroupIdentifier, let shared = UserDefaults(suiteName: id) {
            return shared
        }
        return .standard
    }

    public static func load(from defaults: UserDefaults = SettingsStore.defaults) -> PrayerSettings {
        guard let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(PrayerSettings.self, from: data) else {
            return PrayerSettings()
        }
        return settings
    }

    public static func save(_ settings: PrayerSettings, to defaults: UserDefaults = SettingsStore.defaults) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: settingsKey)
    }
}
