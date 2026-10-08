//
//  AdvancedSettingsView.swift
//  PrayerTimes
//

import PrayerKit
import SwiftUI

struct AdvancedSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var showResetConfirmation = false

    private typealias Params = PrayerTimeCalculator.MethodParameters
    private typealias Rule = PrayerTimeCalculator.TwilightRule

    var body: some View {
        @Bindable var model = model

        Form {
            // MARK: Angles
            Section {
                if model.settings.calculationMethod == .custom {
                    customParameterControls
                } else {
                    parameterSummary(model.settings.effectiveParameters)
                    Button("Customize Angles") {
                        var s = model.settings
                        s.customParameters = s.calculationMethod.parameters
                        s.calculationMethod = .custom
                        model.settings = s
                    }
                }
            } header: {
                Text("Angles")
            } footer: {
                Text(model.settings.calculationMethod == .custom
                     ? "Custom parameters are used. Choose another method in Settings to go back."
                     : "Parameters of \(model.settings.calculationMethod.displayName). Customizing switches the method to Custom.")
            }

            // MARK: High latitudes
            Section {
                Picker("High Latitude Rule", selection: $model.settings.highLatitudeRule) {
                    ForEach(PrayerTimeCalculator.HigherLatitudeAdjustment.allCases) { rule in
                        Text(rule.displayName).tag(rule)
                    }
                }
            } header: {
                Text("High Latitudes")
            } footer: {
                Text("Used where twilight lasts all night (typically above 48°), so Fajr and Isha can't be found by angle alone.")
            }

            // MARK: Manual adjustments
            Section {
                ForEach(Prayer.allCases) { prayer in
                    Stepper(value: offsetBinding(for: prayer), in: -30...30) {
                        LabeledContent(prayer.displayName, value: offsetText(model.settings.offset(for: prayer)))
                    }
                }
                if model.settings.hasOffsets {
                    Button("Reset Adjustments") {
                        model.settings.resetOffsets()
                    }
                }
            } header: {
                Text("Adjustments")
            } footer: {
                Text("Add or subtract minutes, for example to match your local mosque.")
            }

            // MARK: Display
            Section("Display") {
                Picker("Time Format", selection: $model.settings.timeFormat) {
                    ForEach(TimeFormatPreference.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
            }

            // MARK: Hijri
            Section {
                Picker("Calendar", selection: $model.settings.hijriCalendar) {
                    ForEach(HijriCalendarKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                Stepper(value: $model.settings.hijriAdjustment, in: -2...2) {
                    LabeledContent("Adjustment", value: dayAdjustmentText(model.settings.hijriAdjustment))
                }
                Toggle("New Day Begins at Maghrib", isOn: $model.settings.hijriChangesAtMaghrib)
                if let schedule = model.schedule {
                    LabeledContent("Today", value: schedule.hijriString(at: Date()))
                }
            } header: {
                Text("Hijri Date")
            } footer: {
                Text("Adjust by a day if your community's moon sighting differs from the calculated calendar.")
            }

            // MARK: Location
            Section("Location") {
                if let location = model.settings.location {
                    LabeledContent("Coordinates", value: location.coordinateDescription)
                    LabeledContent("Time Zone", value: location.timeZoneIdentifier)
                }
                NavigationLink("Enter Coordinates Manually") {
                    ManualLocationView()
                }
            }

            // MARK: Reset
            Section {
                Button("Reset All Settings", role: .destructive) {
                    showResetConfirmation = true
                }
            }
        }
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Reset all settings?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                model.resetSettings()
            }
        } message: {
            Text("Calculation, display and notification preferences return to their defaults. Your location is kept.")
        }
    }

    // MARK: - Parameters

    @ViewBuilder
    private func parameterSummary(_ params: Params) -> some View {
        LabeledContent("Fajr", value: degrees(params.fajrAngle))
        LabeledContent("Maghrib", value: ruleText(params.maghrib, minutesSuffix: "after sunset"))
        LabeledContent("Isha", value: ruleText(params.isha, minutesSuffix: "after Maghrib"))
    }

    @ViewBuilder
    private var customParameterControls: some View {
        let params = model.settings.customParameters

        Stepper(value: fajrAngleBinding, in: 5...25, step: 0.5) {
            LabeledContent("Fajr Angle", value: degrees(params.fajrAngle))
        }

        Picker("Maghrib", selection: isMinutesBinding(\.maghrib, angle: 4, minutes: 0)) {
            Text("Angle").tag(false)
            Text("Minutes after Sunset").tag(true)
        }
        Stepper(value: ruleValueBinding(\.maghrib),
                in: params.maghrib.isMinutes ? 0...30 : 1...20,
                step: params.maghrib.isMinutes ? 1 : 0.5) {
            LabeledContent("Maghrib", value: ruleText(params.maghrib, minutesSuffix: "after sunset"))
        }

        Picker("Isha", selection: isMinutesBinding(\.isha, angle: 17, minutes: 90)) {
            Text("Angle").tag(false)
            Text("Minutes after Maghrib").tag(true)
        }
        Stepper(value: ruleValueBinding(\.isha),
                in: params.isha.isMinutes ? 0...180 : 5...25,
                step: params.isha.isMinutes ? 5 : 0.5) {
            LabeledContent("Isha", value: ruleText(params.isha, minutesSuffix: "after Maghrib"))
        }
    }

    private var fajrAngleBinding: Binding<Double> {
        Binding(
            get: { model.settings.customParameters.fajrAngle },
            set: { model.settings.customParameters.fajrAngle = $0 }
        )
    }

    private func isMinutesBinding(_ keyPath: WritableKeyPath<Params, Rule>, angle: Double, minutes: Double) -> Binding<Bool> {
        Binding(
            get: { model.settings.customParameters[keyPath: keyPath].isMinutes },
            set: { useMinutes in
                guard useMinutes != model.settings.customParameters[keyPath: keyPath].isMinutes else { return }
                model.settings.customParameters[keyPath: keyPath] = useMinutes ? .minutes(minutes) : .angle(angle)
            }
        )
    }

    private func ruleValueBinding(_ keyPath: WritableKeyPath<Params, Rule>) -> Binding<Double> {
        Binding(
            get: { model.settings.customParameters[keyPath: keyPath].value },
            set: { value in
                let isMinutes = model.settings.customParameters[keyPath: keyPath].isMinutes
                model.settings.customParameters[keyPath: keyPath] = isMinutes ? .minutes(value) : .angle(value)
            }
        )
    }

    private func offsetBinding(for prayer: Prayer) -> Binding<Int> {
        Binding(
            get: { model.settings.offset(for: prayer) },
            set: { model.settings.setOffset($0, for: prayer) }
        )
    }

    // MARK: - Formatting

    private func degrees(_ value: Double) -> String {
        String(format: "%.1f°", value)
    }

    private func ruleText(_ rule: Rule, minutesSuffix: String) -> String {
        switch rule {
        case .angle(let value):
            return degrees(value)
        case .minutes(let value):
            return value == 0 ? "At sunset" : "\(Int(value)) min \(minutesSuffix)"
        }
    }

    private func offsetText(_ minutes: Int) -> String {
        minutes == 0 ? "None" : String(format: "%+d min", minutes)
    }

    private func dayAdjustmentText(_ days: Int) -> String {
        switch days {
        case 0: return "None"
        case 1, -1: return String(format: "%+d day", days)
        default: return String(format: "%+d days", days)
        }
    }
}

#Preview {
    NavigationStack {
        AdvancedSettingsView()
    }
    .environment(AppModel())
}
