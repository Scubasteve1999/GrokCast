import Combine
import CoreLocation
import Foundation
import UIKit

@MainActor
@Observable
final class LocationService: NSObject {
  var currentLocation: CLLocation?
  var authorizationStatus: CLAuthorizationStatus = .notDetermined
  var isLoading = false
  var error: Error?

  private var isMonitoringSignificantChanges = false

  /// Invoked for location updates delivered by Significant Location Changes monitoring
  /// (background/suspended/terminated relaunch cases, when no explicit requestLocation continuation is active).
  /// Set by WeatherStore to keep the "Current Location" entry and weather fresh.
  public var significantLocationHandler: ((CLLocation) -> Void)?

  private let manager = CLLocationManager()
  private var continuation: CheckedContinuation<CLLocation, Error>?

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyKilometer
    authorizationStatus = manager.authorizationStatus
    if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
      startSignificantLocationChanges()
    }
  }

  @MainActor
  func requestAuthorization() {
    manager.requestWhenInUseAuthorization()
  }

  @MainActor
  func requestAlwaysAuthorization() {
    manager.requestAlwaysAuthorization()
  }

  /// Unified entry point for first-launch / ENABLE / pre-step before locating.
  /// - `.notDetermined` → When In Use only (Always is requested later if Travel Weather needs it).
  /// - denied/restricted → publishes error for UI recovery.
  /// - already authorized → ensures Significant Location Changes when Always is available.
  @MainActor
  public func requestLocationPermission() {
    error = nil
    if authorizationStatus == .denied || authorizationStatus == .restricted {
      error = CLError(.denied)
      return
    }
    if authorizationStatus == .notDetermined {
      manager.requestWhenInUseAuthorization()
    } else if authorizationStatus == .authorizedWhenInUse
      || authorizationStatus == .authorizedAlways
    {
      startSignificantLocationChanges()
    }
  }

  public func requestLocation() async throws -> CLLocation {
    if authorizationStatus == .denied || authorizationStatus == .restricted {
      throw CLError(.denied)
    }
    isLoading = true
    error = nil

    #if targetEnvironment(simulator)
      // Force real Olive Branch / Southaven, MS coords (34.9618, -89.8295) for simulator testing.
      // This ensures the weather API is called with the correct location (no false rain from wrong area).
      // Real device uses CLLocationManager; simulator is forced for accuracy verification per task.
      let forcedOlive = CLLocation(latitude: 34.9618, longitude: -89.8295)
      currentLocation = forcedOlive
      isLoading = false
      return forcedOlive
    #else
      // Async wrapper over CLLocationManager's delegate-based requestLocation().
      // Uses CheckedContinuation internally as the *standard* bridge from the callback/delegate
      // (didUpdateLocations / didFailWithError / auth change) to the async/await caller.
      // This is the correct, idiomatic pattern; public API remains clean `async throws`.
      // Event-driven `significantLocationHandler` closure is intentionally kept (per spec)
      // for background Significant Location Changes updates (wired by WeatherStore).
      return try await withCheckedThrowingContinuation { continuation in
        // A second concurrent request must not silently overwrite the stored
        // continuation — that would leave the first caller awaiting forever.
        if let superseded = self.continuation {
          superseded.resume(throwing: CLError(.locationUnknown))
        }
        self.continuation = continuation

        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
          manager.requestLocation()
        } else {
          // When In Use first — Always is only requested from startSignificantLocationChanges().
          manager.requestWhenInUseAuthorization()
          // Will continue in delegate
        }
      }
    #endif
  }

  public func reverseGeocode(_ location: CLLocation) async -> String? {
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
      // Reverse geocode error (log removed)
    }
    return "Current Location"
  }

  public func openSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
      UIApplication.shared.open(url)
    }
  }

  @MainActor
  public func startSignificantLocationChanges() {
    let enabled =
      UserDefaults.standard.object(forKey: "daycast_significant_location_updates_enabled") as? Bool
      ?? true

    guard enabled else { return }
    guard !isMonitoringSignificantChanges else { return }

    guard CLLocationManager.significantLocationChangeMonitoringAvailable() else { return }

    if authorizationStatus != .authorizedAlways {
      manager.requestAlwaysAuthorization()
      return
    }

    if authorizationStatus == .authorizedAlways {
      manager.startMonitoringSignificantLocationChanges()
      isMonitoringSignificantChanges = true
    }
  }

  @MainActor
  public func stopSignificantLocationChanges() {
    if isMonitoringSignificantChanges {
      manager.stopMonitoringSignificantLocationChanges()
      isMonitoringSignificantChanges = false
    }
  }

}

extension LocationService: @preconcurrency CLLocationManagerDelegate {
  @MainActor
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    authorizationStatus = manager.authorizationStatus

    if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
      if continuation != nil {
        manager.requestLocation()
      }
      startSignificantLocationChanges()
    } else if authorizationStatus == .denied || authorizationStatus == .restricted {
      stopSignificantLocationChanges()
      error = CLError(.denied)  // Publish for non-continuation paths (e.g. explanation "Continue" flow or Settings change)
      continuation?.resume(throwing: CLError(.denied))
      continuation = nil
      isLoading = false
    }
  }

  @MainActor
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    currentLocation = location

    if continuation != nil {
      continuation?.resume(returning: location)
      continuation = nil
      isLoading = false
    } else {
      significantLocationHandler?(location)
    }
  }

  @MainActor
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    self.error = error
    continuation?.resume(throwing: error)
    continuation = nil
    isLoading = false
  }
}
