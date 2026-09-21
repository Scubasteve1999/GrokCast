import Foundation
import Observation

/// Today chip state for REFS timing confidence. Not the honesty strip.
@MainActor
@Observable
final class RefsAgreementStore {
  static let shared = RefsAgreementStore()

  private(set) var payload: RefsAgreementPayload?
  private(set) var locationID: String?

  private let cacheTTL: TimeInterval = 10 * 60
  private var lastRefresh: Date?
  private var refreshGeneration = 0
  private let service: RefsAgreementService

  init(service: RefsAgreementService = RefsAgreementService()) {
    self.service = service
  }

  func payload(for locationID: String?) -> RefsAgreementPayload? {
    guard let locationID, self.locationID == locationID else { return nil }
    return payload
  }

  func refresh(for location: SavedLocation, timeZone: TimeZone, force: Bool = false) async {
    let locationKey = location.id.uuidString
    #if DEBUG
      if UserDefaults.standard.bool(forKey: RefsAgreementConfiguration.forceKey) {
        payload = RefsAgreement.debugSample
        locationID = locationKey
        lastRefresh = Date()
        return
      }
    #endif
    if !force,
      let lastRefresh,
      self.locationID == locationKey,
      Date().timeIntervalSince(lastRefresh) < cacheTTL,
      payload != nil
    {
      return
    }

    refreshGeneration += 1
    let generation = refreshGeneration
    let fetched = await service.fetch(
      latitude: location.latitude,
      longitude: location.longitude,
      timeZone: timeZone
    )
    guard generation == refreshGeneration else { return }
    payload = fetched
    locationID = locationKey
    lastRefresh = Date()
  }
}
