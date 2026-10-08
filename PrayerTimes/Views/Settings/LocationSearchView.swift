//
//  LocationSearchView.swift
//  PrayerTimes
//

import CoreLocation
import MapKit
import PrayerKit
import SwiftUI

/// Search for a city with MapKit, or fall back to current location / manual
/// coordinates.
struct LocationSearchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false

    struct SearchResult: Identifiable, Hashable {
        let id = UUID()
        let location: SavedLocation
        let subtitle: String
    }

    var body: some View {
        List {
            if query.isEmpty {
                Section {
                    Button {
                        Task {
                            await model.useCurrentLocation()
                            if model.locationError == nil { dismiss() }
                        }
                    } label: {
                        Label("Use Current Location", systemImage: "location")
                    }
                    NavigationLink {
                        ManualLocationView()
                    } label: {
                        Label("Enter Coordinates", systemImage: "globe")
                    }
                } footer: {
                    if let error = model.locationError {
                        Text(error)
                    }
                }
            }

            if !results.isEmpty {
                Section("Results") {
                    ForEach(results) { result in
                        Button {
                            model.selectLocation(result.location)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.location.name)
                                    .foregroundStyle(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } else if query.trimmingCharacters(in: .whitespaces).count >= 2 && !isSearching {
                ContentUnavailableView.search(text: query)
            }
        }
        .overlay {
            if isSearching && results.isEmpty {
                ProgressView()
            }
        }
        .navigationTitle("Choose City")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "City or address")
        .autocorrectionDisabled()
        .task(id: query) {
            await search()
        }
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2 else {
            results = []
            return
        }
        // Debounce typing; the task is cancelled when the query changes.
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }

        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.resultTypes = .address
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard !Task.isCancelled else { return }
            results = response.mapItems.compactMap(Self.result(from:))
        } catch {
            if !Task.isCancelled { results = [] }
        }
    }

    private static func result(from item: MKMapItem) -> SearchResult? {
        let placemark = item.placemark
        let coordinate = placemark.coordinate
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        let name = placemark.locality ?? item.name ?? placemark.name ?? "Unknown"
        let subtitle = [placemark.administrativeArea, placemark.country]
            .compactMap { $0 }
            .filter { $0 != name }
            .joined(separator: ", ")
        let timeZone = item.timeZone ?? .current
        let location = SavedLocation(name: name,
                                     latitude: coordinate.latitude,
                                     longitude: coordinate.longitude,
                                     timeZoneIdentifier: timeZone.identifier)
        return SearchResult(location: location, subtitle: subtitle)
    }
}

/// Manual latitude/longitude entry.
struct ManualLocationView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var timeZoneIdentifier = TimeZone.current.identifier
    @State private var didLoad = false

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("Latitude, e.g. 21.4225", text: $latitude)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Longitude, e.g. 39.8262", text: $longitude)
                    .keyboardType(.numbersAndPunctuation)
            } footer: {
                Text("Use negative values for southern latitudes and western longitudes.")
            }

            Section {
                Picker("Time Zone", selection: $timeZoneIdentifier) {
                    ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { identifier in
                        Text(identifier.replacingOccurrences(of: "_", with: " ")).tag(identifier)
                    }
                }
                .pickerStyle(.navigationLink)
            }
        }
        .navigationTitle("Coordinates")
        .navigationBarTitleDisplayMode(.inline)
        .autocorrectionDisabled()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(parsedCoordinate == nil)
            }
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            if let location = model.settings.location {
                name = location.name
                latitude = String(format: "%.4f", location.latitude)
                longitude = String(format: "%.4f", location.longitude)
                timeZoneIdentifier = location.timeZoneIdentifier
            }
        }
    }

    private var parsedCoordinate: (latitude: Double, longitude: Double)? {
        func parse(_ text: String) -> Double? {
            Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
        }
        guard let lat = parse(latitude), let lng = parse(longitude),
              (-90...90).contains(lat), (-180...180).contains(lng) else { return nil }
        return (lat, lng)
    }

    private func save() {
        guard let coordinate = parsedCoordinate else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        model.selectLocation(SavedLocation(
            name: trimmed.isEmpty ? "Custom Location" : trimmed,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            timeZoneIdentifier: timeZoneIdentifier
        ))
        dismiss()
    }
}

#Preview {
    NavigationStack {
        LocationSearchView()
    }
    .environment(AppModel())
}
