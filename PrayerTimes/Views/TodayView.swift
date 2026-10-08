//
//  TodayView.swift
//  PrayerTimes
//

import PrayerKit
import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            Group {
                if let schedule = model.schedule {
                    // Re-render every minute so the highlighted prayer moves on.
                    TimelineView(.everyMinute) { context in
                        TodayList(schedule: schedule, now: context.date)
                    }
                    .navigationTitle(schedule.location.name)
                } else {
                    LocationRequiredView()
                        .navigationTitle("Today")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if model.isLocating {
                        ProgressView()
                    }
                }
            }
        }
    }
}

private struct TodayList: View {
    @Environment(AppModel.self) private var model
    let schedule: PrayerSchedule
    let now: Date

    /// How long after a prayer began the card mentions it.
    private let recentWindow: TimeInterval = 30 * 60

    var body: some View {
        let day = schedule.day(containing: now)
        let status = schedule.status(at: now, includeSunrise: true, recentWindow: recentWindow)
        let formatter = schedule.timeFormatter()
        let notifications = model.settings.notifications

        List {
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text(now.formatted(Date.FormatStyle(date: .complete, time: .omitted, timeZone: schedule.timeZone)))
                        .font(.headline)
                    Text(schedule.hijriString(at: now))
                        .foregroundStyle(.secondary)
                }
                if let status {
                    NextPrayerCard(status: status, formatter: formatter)
                }
            }

            Section {
                ForEach(day.times) { time in
                    PrayerTimeRow(
                        time: time,
                        formattedTime: formatter.string(from: time.date),
                        isNext: status?.next == time,
                        isPast: time.date <= now && status?.next != time,
                        alert: notifications.isEnabled ? notifications[time.prayer].alert : nil
                    )
                    .contextMenu {
                        if notifications.isEnabled {
                            Picker("Notification", selection: alertBinding(for: time.prayer)) {
                                ForEach(NotificationAlert.allCases) { alert in
                                    Label(alert.displayName, systemImage: alert.systemImage).tag(alert)
                                }
                            }
                        }
                    }
                }
            } footer: {
                Text("\(schedule.settings.calculationMethod.displayName) · Asr: \(schedule.settings.asrMethod.displayName)")
            }
        }
        .refreshable {
            if model.settings.useCurrentLocation {
                await model.refreshLocation()
            }
        }
    }

    private func alertBinding(for prayer: Prayer) -> Binding<NotificationAlert> {
        Binding(
            get: { model.settings.notifications[prayer].alert },
            set: { model.settings.notifications[prayer].alert = $0 }
        )
    }
}

#Preview {
    TodayView()
        .environment(AppModel())
}
