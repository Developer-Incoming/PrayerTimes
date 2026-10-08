//
//  Components.swift
//  PrayerTimes
//

import PrayerKit
import SwiftUI

extension NotificationAlert {
    var systemImage: String {
        switch self {
        case .off:    return "bell.slash"
        case .silent: return "bell"
        case .sound:  return "bell.and.waves.left.and.right"
        }
    }
}

/// A standard list row: icon, prayer name, notification indicator and time.
struct PrayerTimeRow: View {
    let time: PrayerTime
    let formattedTime: String
    var isNext = false
    var isPast = false
    /// `nil` hides the notification indicator.
    var alert: NotificationAlert?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: time.prayer.systemImage)
                .foregroundStyle(isNext ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: 28)
            Text(time.prayer.displayName)
            Spacer()
            if let alert, alert != .off {
                Image(systemName: alert.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(alert == .sound ? "Notification with sound" : "Silent notification")
            }
            Text(formattedTime)
                .monospacedDigit()
        }
        .fontWeight(isNext ? .semibold : .regular)
        .foregroundStyle(isPast ? HierarchicalShapeStyle.secondary : HierarchicalShapeStyle.primary)
        .accessibilityElement(children: .combine)
    }
}

/// Summary of the upcoming prayer with a live countdown and, shortly after a
/// prayer began, the time elapsed since then.
struct NextPrayerCard: View {
    let status: PrayerStatus
    let formatter: PrayerTimeFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let recent = status.recent {
                Label {
                    Text("\(recent.prayer.displayName) began \(Text(recent.date, style: .relative)) ago")
                } icon: {
                    Image(systemName: recent.prayer.systemImage)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.next.prayer.isObligatory ? "Next Prayer" : "Next")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(status.next.prayer.displayName)
                        .font(.title2.weight(.semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatter.string(from: status.next.date))
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.tint)
                    Text("in \(Text(status.next.date, style: .relative))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// Shown when no location is known yet.
struct LocationRequiredView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ContentUnavailableView {
            Label("Location Needed", systemImage: "location.slash")
        } description: {
            Text(model.locationError ?? "Prayer times are calculated for where you are.")
        } actions: {
            Button {
                Task { await model.useCurrentLocation() }
            } label: {
                if model.isLocating {
                    ProgressView()
                } else {
                    Text("Use Current Location")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isLocating)

            NavigationLink("Choose a City") {
                LocationSearchView()
            }
        }
    }
}
