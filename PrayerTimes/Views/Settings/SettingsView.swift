//
//  SettingsView.swift
//  PrayerTimes
//

import PrayerKit
import SwiftUI

/// Minimal settings: location, calculation method, Asr method, and links to
/// notification and advanced settings.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            Form {
                Section {
                    Toggle("Use Current Location", isOn: $model.settings.useCurrentLocation)
                    if model.settings.useCurrentLocation {
                        LabeledContent("Location") {
                            if model.isLocating {
                                ProgressView()
                            } else {
                                Text(model.settings.location?.name ?? "Unknown")
                            }
                        }
                        Button("Update Location") {
                            Task { await model.refreshLocation() }
                        }
                        .disabled(model.isLocating)
                    } else {
                        NavigationLink {
                            LocationSearchView()
                        } label: {
                            LabeledContent("City", value: model.settings.location?.name ?? "Not Set")
                        }
                    }
                } header: {
                    Text("Location")
                } footer: {
                    if let error = model.locationError {
                        Text(error)
                    }
                }

                Section {
                    Picker("Method", selection: $model.settings.calculationMethod) {
                        ForEach(PrayerTimeCalculator.CalculationMethod.allCases) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Picker("Asr", selection: $model.settings.asrMethod) {
                        ForEach(PrayerTimeCalculator.JuristicMethod.allCases) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                } header: {
                    Text("Calculation")
                } footer: {
                    Text("Standard Asr is used by the Shafi'i, Maliki and Hanbali schools; Hanafi Asr is later.")
                }

                Section {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        LabeledContent {
                            Text(model.settings.notifications.isEnabled ? "On" : "Off")
                        } label: {
                            Label("Notifications", systemImage: "bell.badge")
                        }
                    }
                }

                Section {
                    NavigationLink {
                        AdvancedSettingsView()
                    } label: {
                        Label("Advanced Settings", systemImage: "slider.horizontal.3")
                    }
                } footer: {
                    Text("Prayer times are calculated on your device with the praytimes.org algorithm, based on PrayerTimes-Swift by Ashik Ahmad.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppModel())
}
