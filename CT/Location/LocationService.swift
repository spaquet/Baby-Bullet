//
//  LocationService.swift
//  CT
//

import CoreLocation
import Observation

/// Thin wrapper around CLLocationManager for the "nearest station" feature.
/// Location is optional everywhere — the app is fully usable without it.
@Observable
@MainActor
final class LocationService: NSObject {
    private(set) var currentCoordinate: CLLocationCoordinate2D?
    private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestAuthorization() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            currentCoordinate = coordinate
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location is best-effort; the app falls back to the saved home station.
    }
}

extension CLLocationCoordinate2D {
    /// Fast relative-distance comparator (no need for true meters to rank stations).
    func distanceSquared(to station: Station) -> Double {
        let dLat = latitude - station.latitude
        let dLon = longitude - station.longitude
        return dLat * dLat + dLon * dLon
    }
}
