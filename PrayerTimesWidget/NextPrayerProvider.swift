//
//  NextPrayerProvider.swift
//  PrayerTimesWidget
//

import Foundation
import PrayerKit
import WidgetKit

/// Everything a widget view needs for one moment in time.
struct PrayerSnapshot {
    let date: Date
    let locationName: String
    let next: PrayerTime
    let previous: PrayerTime?
    /// Set while the previous prayer began less than the configured window ago.
    let recent: PrayerTime?
    /// Times of the day the next prayer belongs to.
    let times: [PrayerTime]
    let gregorianDate: String
    let hijriLong: String
    let hijriShort: String
    let formatter: PrayerTimeFormatter

    func time(_ date: Date) -> String { formatter.string(from: date) }

    func isPast(_ time: PrayerTime) -> Bool { time.date <= date && time != next }
}

struct NextPrayerEntry: TimelineEntry {
    let date: Date
    let configuration: NextPrayerConfigurationIntent
    /// `nil` when no location has been set in the app yet.
    let snapshot: PrayerSnapshot?
}

enum SnapshotFactory {
    static func snapshot(at date: Date, schedule: PrayerSchedule, configuration: NextPrayerConfigurationIntent) -> PrayerSnapshot? {
        guard let status = schedule.status(at: date,
                                           includeSunrise: configuration.includeSunrise,
                                           recentWindow: configuration.elapsedWindow.interval) else { return nil }
        let day = schedule.day(containing: status.next.date)
        let times = day.times.filter { configuration.includeSunrise || $0.prayer != .sunrise }

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = schedule.timeZone
        dateFormatter.setLocalizedDateFormatFromTemplate("EEEdMMM")

        return PrayerSnapshot(
            date: date,
            locationName: schedule.location.name,
            next: status.next,
            previous: status.previous,
            recent: status.recent,
            times: times,
            gregorianDate: dateFormatter.string(from: date),
            hijriLong: schedule.hijriString(at: date, style: .long),
            hijriShort: schedule.hijriString(at: date, style: .dayMonth),
            formatter: schedule.timeFormatter()
        )
    }

    /// Realistic data for the widget gallery and placeholders.
    static var sampleSchedule: PrayerSchedule {
        var settings = PrayerSettings()
        settings.location = SavedLocation(name: "Makkah", latitude: 21.4225, longitude: 39.8262,
                                          timeZoneIdentifier: "Asia/Riyadh")
        settings.calculationMethod = .makkah
        return PrayerSchedule(settings: settings)!
    }

    static func entries(from start: Date, schedule: PrayerSchedule, configuration: NextPrayerConfigurationIntent,
                        horizon: TimeInterval = 24 * 3600) -> [NextPrayerEntry] {
        let end = start.addingTimeInterval(horizon)
        var dates = Set(schedule.transitionDates(from: start, to: end,
                                                 includeSunrise: configuration.includeSunrise,
                                                 recentWindow: configuration.elapsedWindow.interval))
        dates.insert(start)

        // Refresh the date / Hijri date at midnight.
        let calendar = schedule.calendar
        var midnight = calendar.startOfDay(for: start)
        for _ in 0..<2 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: midnight) else { break }
            midnight = next
            if midnight > start && midnight <= end { dates.insert(midnight) }
        }

        return dates.sorted().map { date in
            NextPrayerEntry(date: date, configuration: configuration,
                            snapshot: snapshot(at: date, schedule: schedule, configuration: configuration))
        }
    }
}

struct NextPrayerProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NextPrayerEntry {
        sampleEntry(configuration: NextPrayerConfigurationIntent())
    }

    func snapshot(for configuration: NextPrayerConfigurationIntent, in context: Context) async -> NextPrayerEntry {
        let now = Date()
        guard let schedule = PrayerSchedule(settings: SettingsStore.load()) else {
            // Widget gallery before the app was set up: show sample data.
            return sampleEntry(configuration: configuration)
        }
        return NextPrayerEntry(date: now, configuration: configuration,
                               snapshot: SnapshotFactory.snapshot(at: now, schedule: schedule, configuration: configuration))
    }

    func timeline(for configuration: NextPrayerConfigurationIntent, in context: Context) async -> Timeline<NextPrayerEntry> {
        let now = Date()
        guard let schedule = PrayerSchedule(settings: SettingsStore.load()) else {
            let entry = NextPrayerEntry(date: now, configuration: configuration, snapshot: nil)
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(3600)))
        }
        let entries = SnapshotFactory.entries(from: now, schedule: schedule, configuration: configuration)
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func sampleEntry(configuration: NextPrayerConfigurationIntent) -> NextPrayerEntry {
        let now = Date()
        return NextPrayerEntry(date: now, configuration: configuration,
                               snapshot: SnapshotFactory.snapshot(at: now, schedule: SnapshotFactory.sampleSchedule,
                                                                  configuration: configuration))
    }
}
