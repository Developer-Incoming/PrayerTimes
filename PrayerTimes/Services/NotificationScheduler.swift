//
//  NotificationScheduler.swift
//  PrayerTimes
//

import Foundation
import PrayerKit
import UserNotifications

/// Schedules standard iOS local notifications for prayer times.
///
/// iOS keeps at most 64 pending local notifications per app, so a rolling
/// window is scheduled and refreshed whenever the app becomes active, the
/// settings change, or a background app refresh runs.
enum NotificationScheduler {
    static let identifierPrefix = "prayer."
    static let threadIdentifier = "prayer-times"
    /// Leave a little room below the system limit of 64.
    static let maximumPending = 60

    private static var center: UNUserNotificationCenter { .current() }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    /// Replaces all pending prayer notifications. Returns the number scheduled.
    @discardableResult
    static func reschedule(settings: PrayerSettings, now: Date = Date()) async -> Int {
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        guard settings.notifications.isEnabled, let schedule = PrayerSchedule(settings: settings) else { return 0 }
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral: break
        default: return 0
        }

        let formatter = schedule.timeFormatter()
        let plan = schedule.notificationPlan(from: now, days: 14, limit: maximumPending)
        var count = 0
        for item in plan {
            let request = UNNotificationRequest(
                identifier: item.id, // already starts with `identifierPrefix`
                content: content(for: item, settings: settings, formatter: formatter),
                trigger: trigger(for: item.fireDate)
            )
            do {
                try await center.add(request)
                count += 1
            } catch {
                continue
            }
        }
        return count
    }

    /// Delivers a sample notification after a few seconds.
    static func sendTest(settings: PrayerSettings) async {
        let content = UNMutableNotificationContent()
        let formatter = PrayerSchedule(settings: settings)?.timeFormatter()
            ?? PrayerTimeFormatter(format: settings.timeFormat, timeZone: .current)
        let time = formatter.string(from: Date().addingTimeInterval(5))
        content.title = Prayer.dhuhr.displayName
        content.body = "It's time for \(Prayer.dhuhr.displayName) prayer (\(time)). This is a test notification."
        content.sound = .default
        content.threadIdentifier = threadIdentifier
        let request = UNNotificationRequest(identifier: "test.\(UUID().uuidString)",
                                            content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))
        try? await center.add(request)
    }

    // MARK: - Building requests

    static func content(for item: PlannedNotification, settings: PrayerSettings, formatter: PrayerTimeFormatter) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        let name = item.prayer.displayName
        let time = formatter.string(from: item.prayerDate)

        if item.isReminder {
            content.title = "\(name) in \(item.minutesBefore) minutes"
            content.body = "\(name) begins at \(time)."
        } else if item.prayer == .sunrise {
            content.title = name
            content.body = "The sun rises at \(time). The time for Fajr has ended."
        } else {
            content.title = name
            content.body = "It's time for \(name) prayer (\(time))."
        }

        content.threadIdentifier = threadIdentifier
        content.sound = item.playsSound ? .default : nil
        content.interruptionLevel = (settings.notifications.timeSensitive && !item.isReminder) ? .timeSensitive : .active
        content.relevanceScore = item.isReminder ? 0.5 : 1.0
        content.userInfo = [
            "prayer": item.prayer.rawValue,
            "prayerDate": item.prayerDate.timeIntervalSince1970
        ]
        return content
    }

    static func trigger(for date: Date) -> UNCalendarNotificationTrigger {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}
