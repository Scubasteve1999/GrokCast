import Foundation
import CoreLocation
import Combine

@Observable
final class LocationService: NSObject {
    var currentLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isLoading = false
    var error: Error?

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = manager.authorizationStatus
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() async throws -> CLLocation {
        isLoading = true
        error = nil

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            } else {
                manager.requestWhenInUseAuthorization()
                // Will continue in delegate
            }
        }
    }

    func reverseGeocode(_ location: CLLocation) async -> String? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                if let city = placemark.locality {
                    if let state = placemark.administrativeArea {
                        return "\(city), \(state)"
                    }
                    return city
                }
                return placemark.name
            }
        } catch {
            print("Reverse geocode error: \(error)")
        }
        return "Current Location"
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            if let cont = continuation {
                manager.requestLocation()
            }
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            continuation?.resume(throwing: CLError(.denied))
            continuation = nil
            isLoading = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        continuation?.resume(returning: location)
        continuation = nil
        isLoading = false
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = error
        continuation?.resume(throwing: error)
        continuation = nil
        isLoading = false
    }
}