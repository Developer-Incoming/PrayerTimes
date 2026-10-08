//
//  NotificationSettingsView.swift
//  PrayerTimes
//

import PrayerKit
import SwiftUI
import UIKit

struct NotificationSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var testSent = false

    var body: some View {
        @Bindable var model = model

        Form {
            Section {
                Toggle("Prayer Notifications", isOn: Binding(
                    get: { model.settings.notifications.isEnabled },
                    set: { enabled in Task { await model.setNotificationsEnabled(enabled) } }
                ))
            } footer: {
                if model.notificationsDenied {
                    Text("Notifications for Prayer Times are turned off in the Settings app.")
                } else {
                    Text("Receive a standard iOS notification when each prayer time begins.")
                }
            }

            if model.notificationsDenied {
                Section {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    }
                }
            }

            if model.settings.notifications.isEnabled {
                Section("Prayers") {
                    ForEach(Prayer.allCases) { prayer in
                        NavigationLink {
                            PrayerNotificationSettingsView(prayer: prayer)
                        } label: {
                            LabeledContent {
                                Text(summary(for: prayer))
                            } label: {
                                Label(prayer.displayName, systemImage: prayer.systemImage)
                            }
                        }
                    }
                }

                Section {
                    Toggle("Time Sensitive", isOn: $model.settings.notifications.timeSensitive)
                } footer: {
                    Text("Time Sensitive notifications are delivered immediately, even during a Focus, and stay on the Lock Screen for an hour. Reminders are always delivered as regular notifications.")
                }

                Section {
                    Button("Send Test Notification") {
                        Task {
                            await model.sendTestNotification()
                            testSent = true
                        }
                    }
                } footer: {
                    if testSent {
                        Text("A test notification will arrive in 5 seconds.")
                    } else if model.scheduledNotificationCount > 0 {
                        Text("\(model.scheduledNotificationCount) upcoming notifications are scheduled. Open the app now and then to keep them coming.")
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .task {
            await model.refreshNotificationStatus()
        }
    }

    private func summary(for prayer: Prayer) -> String {
        let prefs = model.settings.notifications[prayer]
        guard prefs.alert != .off else { return "Off" }
        if prefs.reminderMinutes > 0 {
            return "\(prefs.alert.displayName), \(prefs.reminderMinutes) min before"
        }
        return prefs.alert.displayName
    }
}

/// How to be notified for a single prayer.
struct PrayerNotificationSettingsView: View {
    @Environment(AppModel.self) private var model
    let prayer: Prayer

    private var preferences: Binding<PrayerNotificationSettings> {
        Binding(
            get: { model.settings.notifications[prayer] },
            set: { model.settings.notifications[prayer] = $0 }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("Alert", selection: preferences.alert) {
                    ForEach(NotificationAlert.allCases) { alert in
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(alert.displayName)
                                Text(alert.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: alert.systemImage)
                        }
                        .tag(alert)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text(prayer == .sunrise ? "At Sunrise" : "At Prayer Time")
            }

            Section {
                Picker("Reminder", selection: preferences.reminderMinutes) {
                    ForEach(PrayerNotificationSettings.reminderChoices, id: \.self) { minutes in
                        Text(minutes == 0 ? "None" : "\(minutes) minutes before")
                            .tag(minutes)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .disabled(preferences.wrappedValue.alert == .off)
            } header: {
                Text("Reminder")
            } footer: {
                Text(prayer == .sunrise
                     ? "An extra notification before sunrise, when the time for Fajr ends."
                     : "An extra notification before \(prayer.displayName) begins.")
            }
        }
        .navigationTitle(prayer.displayName)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
    .environment(AppModel())
}
