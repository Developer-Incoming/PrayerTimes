//
//  NextPrayerIntent.swift
//  PrayerTimesWidget
//

import AppIntents
import WidgetKit

/// How long after a prayer began the widget shows the elapsed time.
enum ElapsedTimeWindow: Int, AppEnum {
    case off = 0
    case tenMinutes = 10
    case fifteenMinutes = 15
    case twentyMinutes = 20
    case thirtyMinutes = 30
    case fortyFiveMinutes = 45
    case oneHour = 60

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Time Since Prayer"
    }

    static var caseDisplayRepresentations: [ElapsedTimeWindow: DisplayRepresentation] {
        [
            .off: "Off",
            .tenMinutes: "For 10 Minutes",
            .fifteenMinutes: "For 15 Minutes",
            .twentyMinutes: "For 20 Minutes",
            .thirtyMinutes: "For 30 Minutes",
            .fortyFiveMinutes: "For 45 Minutes",
            .oneHour: "For 1 Hour"
        ]
    }

    var interval: TimeInterval { TimeInterval(rawValue * 60) }
}

/// Options shown when the user edits the widget.
struct NextPrayerConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Next Prayer" }
    static var description: IntentDescription { "Shows the next prayer time with a live countdown." }

    @Parameter(title: "Show Hijri Date", default: true)
    var showHijriDate: Bool

    @Parameter(title: "Show Countdown", default: true)
    var showCountdown: Bool

    @Parameter(title: "Show Time Since Prayer Began", default: .thirtyMinutes)
    var elapsedWindow: ElapsedTimeWindow

    @Parameter(title: "Include Sunrise", default: false)
    var includeSunrise: Bool

    @Parameter(title: "Show Location", default: true)
    var showLocation: Bool

    @Parameter(title: "Show All Times (Medium & Large)", default: true)
    var showAllTimes: Bool

    init() {}

    init(showHijriDate: Bool,
         showCountdown: Bool,
         elapsedWindow: ElapsedTimeWindow,
         includeSunrise: Bool,
         showLocation: Bool,
         showAllTimes: Bool) {
        self.showHijriDate = showHijriDate
        self.showCountdown = showCountdown
        self.elapsedWindow = elapsedWindow
        self.includeSunrise = includeSunrise
        self.showLocation = showLocation
        self.showAllTimes = showAllTimes
    }
}
