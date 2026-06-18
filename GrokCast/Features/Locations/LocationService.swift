import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
  static let shared = LocationService()
  
  private let manager = CLLocationManager()
  private var locationContinuation: CheckedContinuation<CLLocation, Error>?
  
  var significantLocationHandler: ((CLLocation) -> Void)?
  
  var authorizationStatus: CLAuthorizationStatus {
    manager.authorizationStatus
  }
  
  override init() {
    super.init()
    manager.delegate = self
  }
  
  func requestLocationPermission() {
    manager.requestWhenInUseAuthorization()
  }
  
  func requestLocation() async throws -> CLLocation {
    return try await withCheckedThrowingContinuation { continuation in
      self.locationContinuation = continuation
      manager.requestLocation()
    }
  }
  
  func startSignificantLocationChanges() {
    manager.startMonitoringSignificantLocationChanges()
  }
  
  func stopSignificantLocationChanges() {
    manager.stopMonitoringSignificantLocationChanges()
  }
  
  func reverseGeocode(_ location: CLLocation) async -> String? {
    let geocoder = CLGeocoder()
    do {
      let placemarks = try await geocoder.reverseGeocodeLocation(location)
      if let place = placemarks.first {
        return place.locality ?? place.name ?? "Unknown Location"
      }
      return nil
    } catch {
      print("Geocoding error: \(error)")
      return nil
    }
  }
  
  // MARK: - CLLocationManagerDelegate
  
  nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    
    Task { @MainActor in
      if let continuation = locationContinuation {
        locationContinuation = nil
        continuation.resume(returning: location)
      } else {
        // Significant location change
        significantLocationHandler?(location)
      }
    }
  }
  
  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    Task { @MainActor in
      locationContinuation?.resume(throwing: error)
      locationContinuation = nil
    }
  }
  
  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    // Handle authorization changes if needed
  }
}
