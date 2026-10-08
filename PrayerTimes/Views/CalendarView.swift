//
//  CalendarView.swift
//  PrayerTimes
//

import PrayerKit
import SwiftUI

struct CalendarView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }

                if let schedule = model.schedule {
                    let day = schedule.day(for: selectedDate, in: Calendar.current)
                    let formatter = schedule.timeFormatter()
                    Section {
                        ForEach(day.times) { time in
                            PrayerTimeRow(time: time, formattedTime: formatter.string(from: time.date))
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedDate.formatted(date: .complete, time: .omitted))
                            Text(schedule.hijriString(for: day))
                        }
                        .textCase(nil)
                    } footer: {
                        Text(schedule.location.name)
                    }
                } else {
                    Section {
                        LocationRequiredView()
                    }
                }
            }
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Today") {
                        withAnimation { selectedDate = Date() }
                    }
                    .disabled(Calendar.current.isDateInToday(selectedDate))
                }
            }
        }
    }
}

#Preview {
    CalendarView()
        .environment(AppModel())
}
