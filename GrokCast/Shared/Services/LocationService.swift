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

  /// Unified, clear entry point used by the first-launch explanation "Continue",
  /// the ENABLE button, and the pre-step in useCurrentDeviceLocation().
  /// Explicitly handles every state:
  /// - .notDetermined → requests WhenInUse + Always (enables Significant Location Changes).
  /// - denied/restricted → publishes error so UI can show friendly recovery without a pending location request.
  /// - already authorized (WhenInUse or Always) → ensures Significant Location Changes is active.
  ///
  /// Signature is intentionally synchronous (fire-and-forget the system prompts for WhenInUse + Always).
  /// The async location result (with continuation from delegate) comes from the separate
  /// `requestLocation() async throws`. This matches the expected signature per call sites and design.
  @MainActor
  public func requestLocationPermission() {
    error = nil
    if authorizationStatus == .denied || authorizationStatus == .restricted {
      error = CLError(.denied)
      return
    }
    if authorizationStatus == .notDetermined {
      manager.requestWhenInUseAuthorization()
      manager.requestAlwaysAuthorization()
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

    // Async wrapper over CLLocationManager's delegate-based requestLocation().
    // Uses CheckedContinuation internally as the *standard* bridge from the callback/delegate
    // (didUpdateLocations / didFailWithError / auth change) to the async/await caller.
    // This is the correct, idiomatic pattern; public API remains clean `async throws`.
    // Event-driven `significantLocationHandler` closure is intentionally kept (per spec)
    // for background Significant Location Changes updates (wired by WeatherStore).
    return try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation

      if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
        manager.requestLocation()
      } else {
        manager.requestWhenInUseAuthorization()
        manager.requestAlwaysAuthorization()
        // Will continue in delegate
      }
    }
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
      print("Reverse geocode error: \(error)")
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
      UserDefaults.standard.object(forKey: "grokcast_significant_location_updates_enabled") as? Bool
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

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    self.error = error
    continuation?.resume(throwing: error)
    continuation = nil
    isLoading = false
  }
}
