//
//  ContentView.swift
//  PrayerTimes
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "clock") }
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
