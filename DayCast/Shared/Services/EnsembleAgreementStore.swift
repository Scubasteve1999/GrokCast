import Foundation
import Observation

/// Owns the latest Open-Meteo ensemble precip members for the honesty strip.
/// WeatherStore only triggers `refresh(for:)` — it does not parse ensemble JSON.
/// Soft-fail: empty snapshot, MVP1 strip stays.
@MainActor
@Observable
final class EnsembleAgreementStore {
  static let shared = EnsembleAgreementStore()

  private(set) var snapshot: EnsemblePrecipSnapshot = .empty()
  private(set) var lastRefresh: Date?
  private(set) var isRefreshing = false

  private let cacheTTL: TimeInterval = 20 * 60
  private var cachedLocationID: String?
  private var refreshGeneration = 0

  private let service: OpenMeteoEnsembleService

  init(service: OpenMeteoEnsembleService = OpenMeteoEnsembleService()) {
    self.service = service
  }

  func snapshot(for locationID: String?) -> EnsemblePrecipSnapshot? {
    guard let locationID, snapshot.locationID == locationID, snapshot.isUsable()
    else { return nil }
    return snapshot
  }

  func refresh(for location: SavedLocation, force: Bool = false) async {
    let locationKey = location.id.uuidString
    if !force,
      let lastRefresh,
      cachedLocationID == locationKey,
      Date().timeIntervalSince(lastRefresh) < cacheTTL,
      snapshot.locationID == locationKey,
      snapshot.isUsable()
    {
      return
    }

    refreshGeneration += 1
    let generation = refreshGeneration
    isRefreshing = true
    defer {
      if generation == refreshGeneration {
        isRefreshing = false
      }
    }

    let fetched = await service.fetchPrecipMembers(
      latitude: location.latitude,
      longitude: location.longitude
    )

    guard generation == refreshGeneration else { return }

    if let fetched {
      snapshot = fetched.withLocationID(locationKey)
    } else if snapshot.locationID == locationKey, snapshot.hasMembers {
      snapshot = EnsemblePrecipSnapshot.keepingLastGood(snapshot, locationID: locationKey)
    } else {
      snapshot = .empty(locationID: locationKey)
    }

    lastRefresh = Date()
    cachedLocationID = locationKey
  }
}
