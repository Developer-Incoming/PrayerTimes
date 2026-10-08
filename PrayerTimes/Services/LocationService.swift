//
//  LocationService.swift
//  PrayerTimes
//

import CoreLocation
import Foundation
import PrayerKit

enum LocationError: LocalizedError {
    case denied
    case restricted
    case unavailable

    var errorDescription: String? {
        switch self {
        case .denied:
            return "Location access is turned off. Allow it in Settings or choose a city manually."
        case .restricted:
            return "Location access is restricted on this device. Choose a city manually."
        case .unavailable:
            return "Your location couldn't be determined. Try again or choose a city manually."
        }
    }
}

/// One-shot location lookup with async/await on top of `CLLocationManager`.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var locationContinuations: [CheckedContinuation<CLLocation, Error>] = []
    private var authorizationContinuations: [CheckedContinuation<CLAuthorizationStatus, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
        // City level accuracy is plenty for prayer times and is fast.
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    func currentLocation() async throws -> CLLocation {
        var status = manager.authorizationStatus
        if status == .notDetermined {
            status = await withCheckedContinuation { continuation in
                authorizationContinuations.append(continuation)
                manager.requestWhenInUseAuthorization()
            }
        }
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            break
        case .restricted:
            throw LocationError.restricted
        default:
            throw LocationError.denied
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuations.append(continuation)
            if locationContinuations.count == 1 {
                manager.requestLocation()
            }
        }
    }

    /// Reverse geocodes a location into a named `SavedLocation` with the
    /// correct time zone (falls back to the device time zone when offline).
    func describe(_ location: CLLocation) async -> SavedLocation {
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        let placemark = placemarks?.first
        let name = placemark?.locality
            ?? placemark?.subAdministrativeArea
            ?? placemark?.administrativeArea
            ?? placemark?.name
            ?? "Current Location"
        let timeZone = placemark?.timeZone ?? .current
        return SavedLocation(name: name,
                             latitude: location.coordinate.latitude,
                             longitude: location.coordinate.longitude,
                             timeZoneIdentifier: timeZone.identifier)
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.finishLocation(with: .success(location))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let clError = (error as? CLError)?.code
        Task { @MainActor in
            // `locationUnknown` is transient; Core Location keeps trying.
            if clError == .locationUnknown { return }
            self.finishLocation(with: .failure(clError == .denied ? LocationError.denied : LocationError.unavailable))
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard status != .notDetermined else { return }
            let waiting = self.authorizationContinuations
            self.authorizationContinuations.removeAll()
            waiting.forEach { $0.resume(returning: status) }
        }
    }

    private func finishLocation(with result: Result<CLLocation, Error>) {
        let waiting = locationContinuations
        locationContinuations.removeAll()
        waiting.forEach { $0.resume(with: result) }
    }
}
