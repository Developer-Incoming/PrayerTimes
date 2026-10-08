//
//  AppModel.swift
//  PrayerTimes
//

import CoreLocation
import Foundation
import Observation
import PrayerKit
import UserNotifications
import WidgetKit

/// Central app state: settings, computed schedule, location and notification
/// status. Every settings change is persisted to the shared App Group, and
/// notifications and widgets are refreshed (debounced).
@MainActor
@Observable
final class AppModel {
    private var storedSettings: PrayerSettings
    private(set) var schedule: PrayerSchedule?
    private(set) var isLocating = false
    private(set) var locationError: String?
    private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var scheduledNotificationCount = 0

    private let locationService = LocationService()
    @ObservationIgnored private var syncTask: Task<Void, Never>?

    init() {
        let loaded = SettingsStore.load()
        storedSettings = loaded
        schedule = PrayerSchedule(settings: loaded)
    }

    /// User settings. Assigning (or mutating a nested property) persists the
    /// change and refreshes everything that depends on it.
    var settings: PrayerSettings {
        get { storedSettings }
        set {
            guard newValue != storedSettings else { return }
            let old = storedSettings
            storedSettings = newValue
            settingsDidChange(from: old)
        }
    }

    // MARK: - Lifecycle

    func didBecomeActive() async {
        await refreshNotificationStatus()
        if storedSettings.useCurrentLocation {
            await refreshLocation()
        }
        // Keep the rolling window of scheduled notifications filled.
        scheduleSync()
    }

    /// Re-schedules notifications and reloads widgets shortly (coalesces
    /// rapid changes such as stepper taps).
    func scheduleSync() {
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await syncNow()
        }
    }

    func syncNow() async {
        scheduledNotificationCount = await NotificationScheduler.reschedule(settings: storedSettings)
        notificationStatus = await NotificationScheduler.authorizationStatus()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func settingsDidChange(from old: PrayerSettings) {
        SettingsStore.save(storedSettings)
        schedule = PrayerSchedule(settings: storedSettings)

        if storedSettings.useCurrentLocation && !old.useCurrentLocation {
            Task { await refreshLocation() }
        }
        scheduleSync()
    }

    // MARK: - Location

    var locationAuthorization: CLAuthorizationStatus { locationService.authorizationStatus }

    func useCurrentLocation() async {
        var s = storedSettings
        s.useCurrentLocation = true
        // Assigning directly would start a second refresh through
        // `settingsDidChange`, so store the flag first and refresh once.
        storedSettings = s
        SettingsStore.save(s)
        await refreshLocation()
    }

    func refreshLocation() async {
        guard !isLocating else { return }
        isLocating = true
        defer { isLocating = false }
        do {
            let current = try await locationService.currentLocation()
            if let existing = storedSettings.location,
               CLLocation(latitude: existing.latitude, longitude: existing.longitude).distance(from: current) < 1_000 {
                locationError = nil
                return
            }
            let saved = await locationService.describe(current)
            var s = storedSettings
            s.location = saved
            s.useCurrentLocation = true
            settings = s
            locationError = nil
        } catch {
            locationError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func selectLocation(_ location: SavedLocation) {
        var s = storedSettings
        s.location = location
        s.useCurrentLocation = false
        settings = s
        locationError = nil
    }

    // MARK: - Notifications

    var notificationsAuthorized: Bool {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    var notificationsDenied: Bool { notificationStatus == .denied }

    func refreshNotificationStatus() async {
        notificationStatus = await NotificationScheduler.authorizationStatus()
        // Permission revoked in the Settings app: reflect it in the toggle.
        if notificationStatus == .denied && storedSettings.notifications.isEnabled {
            settings.notifications.isEnabled = false
        }
    }

    func setNotificationsEnabled(_ enabled: Bool) async {
        guard enabled else {
            settings.notifications.isEnabled = false
            return
        }
        var status = await NotificationScheduler.authorizationStatus()
        if status == .notDetermined {
            _ = await NotificationScheduler.requestAuthorization()
            status = await NotificationScheduler.authorizationStatus()
        }
        notificationStatus = status
        settings.notifications.isEnabled = notificationsAuthorized
    }

    func sendTestNotification() async {
        await NotificationScheduler.sendTest(settings: storedSettings)
    }

    // MARK: - Reset

    func resetSettings() {
        var fresh = PrayerSettings()
        fresh.location = storedSettings.location
        fresh.useCurrentLocation = storedSettings.useCurrentLocation
        fresh.notifications.isEnabled = storedSettings.notifications.isEnabled
        settings = fresh
    }
}
