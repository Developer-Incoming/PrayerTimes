//
//  PrayerTimesWidget.swift
//  PrayerTimesWidget
//

import AppIntents
import PrayerKit
import SwiftUI
import WidgetKit

@main
struct PrayerTimesWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextPrayerWidget()
    }
}

struct NextPrayerWidget: Widget {
    let kind: String = "PrayerTimesNextPrayerWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: NextPrayerConfigurationIntent.self,
            provider: NextPrayerProvider()
        ) { entry in
            NextPrayerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Next Prayer")
        .description("Displays the next prayer time, live countdown, and elapsed time when a prayer has just started.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

struct NextPrayerWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextPrayerEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            Group {
                switch family {
                case .systemSmall:
                    SmallWidgetView(snapshot: snapshot, config: entry.configuration)
                case .systemMedium:
                    MediumWidgetView(snapshot: snapshot, config: entry.configuration)
                case .systemLarge:
                    LargeWidgetView(snapshot: snapshot, config: entry.configuration)
                case .accessoryInline:
                    InlineAccessoryView(snapshot: snapshot, config: entry.configuration)
                case .accessoryCircular:
                    CircularAccessoryView(snapshot: snapshot, config: entry.configuration)
                case .accessoryRectangular:
                    RectangularAccessoryView(snapshot: snapshot, config: entry.configuration)
                @unknown default:
                    SmallWidgetView(snapshot: snapshot, config: entry.configuration)
                }
            }
            .containerBackground(for: .widget) {
                Color.clear
            }
        } else {
            EmptyLocationWidgetView()
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
    }
}

// MARK: - Empty Location View

struct EmptyLocationWidgetView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "location.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Set Location")
                .font(.subheadline.weight(.semibold))
            Text("Open Prayer Times to configure your city.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(8)
    }
}

// MARK: - System Small View

struct SmallWidgetView: View {
    let snapshot: PrayerSnapshot
    let config: NextPrayerConfigurationIntent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                if config.showLocation {
                    Text(snapshot.locationName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if config.showHijriDate {
                    Text(snapshot.hijriShort)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            // Dynamic Elapsed Status banner (if prayer recently started)
            if let recent = snapshot.recent {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                    Text("\(recent.prayer.displayName) \(Text(recent.date, style: .relative)) ago")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
            }

            // Next Prayer info
            HStack(spacing: 6) {
                Image(systemName: snapshot.next.prayer.systemImage)
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 0) {
                    Text(snapshot.next.prayer.displayName)
                        .font(.headline.weight(.bold))
                        .lineLimit(1)
                    Text(snapshot.time(snapshot.next.date))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            // Countdown
            if config.showCountdown {
                HStack(spacing: 4) {
                    Text("in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(snapshot.next.date, style: .relative)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - System Medium View

struct MediumWidgetView: View {
    let snapshot: PrayerSnapshot
    let config: NextPrayerConfigurationIntent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Location & Hijri
            HStack(alignment: .firstTextBaseline) {
                if config.showLocation {
                    Label(snapshot.locationName, systemImage: "location.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if config.showHijriDate {
                    Text(snapshot.hijriLong)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Central: Next Prayer & dynamic recent banner
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: snapshot.next.prayer.systemImage)
                            .font(.title2)
                            .foregroundStyle(.tint)
                        Text(snapshot.next.prayer.displayName)
                            .font(.title3.weight(.bold))
                    }
                    if config.showCountdown {
                        Text("in \(Text(snapshot.next.date, style: .relative))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(snapshot.time(snapshot.next.date))
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.tint)

                    if let recent = snapshot.recent {
                        Text("\(recent.prayer.displayName) \(Text(recent.date, style: .relative)) ago")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Bottom: All Today's Times
            if config.showAllTimes {
                HStack(spacing: 4) {
                    ForEach(snapshot.times) { time in
                        let isNext = time == snapshot.next
                        let isPast = snapshot.isPast(time)
                        VStack(spacing: 2) {
                            Text(time.prayer.displayName)
                                .font(.system(size: 10, weight: isNext ? .bold : .regular))
                                .foregroundStyle(isNext ? .primary : .secondary)
                            Text(snapshot.time(time.date))
                                .font(.system(size: 10, weight: isNext ? .bold : .regular))
                                .monospacedDigit()
                                .foregroundStyle(isNext ? .primary : (isPast ? .tertiary : .secondary))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                        .background(isNext ? AnyShapeStyle(Color.accentColor.opacity(0.15)) : AnyShapeStyle(Color.clear), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - System Large View

struct LargeWidgetView: View {
    let snapshot: PrayerSnapshot
    let config: NextPrayerConfigurationIntent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top Header: Date, Location, Hijri
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.gregorianDate)
                        .font(.headline)
                    if config.showLocation {
                        Label(snapshot.locationName, systemImage: "location.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if config.showHijriDate {
                    Text(snapshot.hijriLong)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }

            Divider()

            // Dynamic Next Prayer Hero Card
            HStack(alignment: .center) {
                Image(systemName: snapshot.next.prayer.systemImage)
                    .font(.system(size: 36))
                    .foregroundStyle(.tint)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.next.prayer.isObligatory ? "Next Prayer" : "Next Event")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(snapshot.next.prayer.displayName)
                        .font(.title2.weight(.bold))
                    if let recent = snapshot.recent {
                        Text("\(recent.prayer.displayName) began \(Text(recent.date, style: .relative)) ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(snapshot.time(snapshot.next.date))
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.tint)
                    if config.showCountdown {
                        Text("in \(Text(snapshot.next.date, style: .relative))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .padding(.vertical, 4)

            Divider()

            // All Times List
            if config.showAllTimes {
                VStack(spacing: 6) {
                    ForEach(snapshot.times) { time in
                        let isNext = time == snapshot.next
                        let isPast = snapshot.isPast(time)
                        HStack {
                            Image(systemName: time.prayer.systemImage)
                                .font(.subheadline)
                                .foregroundStyle(isNext ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                                .frame(width: 24)
                            Text(time.prayer.displayName)
                                .font(.subheadline.weight(isNext ? .bold : .regular))
                                .foregroundStyle(isPast ? .secondary : .primary)
                            Spacer()
                            Text(snapshot.time(time.date))
                                .font(.subheadline.weight(isNext ? .bold : .regular))
                                .monospacedDigit()
                                .foregroundStyle(isNext ? AnyShapeStyle(.tint) : (isPast ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary)))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isNext ? AnyShapeStyle(Color.accentColor.opacity(0.12)) : AnyShapeStyle(Color.clear), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Lock Screen Accessories

struct InlineAccessoryView: View {
    let snapshot: PrayerSnapshot
    let config: NextPrayerConfigurationIntent

    var body: some View {
        if let recent = snapshot.recent {
            Text("\(recent.prayer.displayName) \(Text(recent.date, style: .relative)) ago · Next: \(snapshot.next.prayer.displayName)")
        } else {
            Text("\(snapshot.next.prayer.displayName) \(snapshot.time(snapshot.next.date))")
        }
    }
}

struct CircularAccessoryView: View {
    let snapshot: PrayerSnapshot
    let config: NextPrayerConfigurationIntent

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: snapshot.next.prayer.systemImage)
                    .font(.caption)
                Text(snapshot.next.prayer.displayName.prefix(3).uppercased())
                    .font(.system(size: 9, weight: .bold))
                Text(snapshot.time(snapshot.next.date))
                    .font(.system(size: 8, weight: .semibold))
                    .monospacedDigit()
            }
        }
    }
}

struct RectangularAccessoryView: View {
    let snapshot: PrayerSnapshot
    let config: NextPrayerConfigurationIntent

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: snapshot.next.prayer.systemImage)
                    .font(.caption)
                Text(snapshot.next.prayer.displayName)
                    .font(.headline.weight(.semibold))
                Spacer()
                Text(snapshot.time(snapshot.next.date))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }

            if let recent = snapshot.recent {
                Text("\(recent.prayer.displayName) \(Text(recent.date, style: .relative)) ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if config.showCountdown {
                Text("in \(Text(snapshot.next.date, style: .relative))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if config.showHijriDate {
                Text(snapshot.hijriShort)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
