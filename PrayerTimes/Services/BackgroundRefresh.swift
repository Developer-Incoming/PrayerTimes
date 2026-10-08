//
//  BackgroundRefresh.swift
//  PrayerTimes
//

import BackgroundTasks
import Foundation
import PrayerKit
import WidgetKit

/// Background app refresh keeps the rolling window of scheduled prayer
/// notifications filled even if the app isn't opened for a while.
enum BackgroundRefresh {
    /// Must match `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
    static let identifier = (Bundle.main.bundleIdentifier ?? "PrayerTimes") + ".refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date().addingTimeInterval(6 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func handle() async {
        schedule()
        let settings = SettingsStore.load()
        await NotificationScheduler.reschedule(settings: settings)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
