import Foundation
import Observation

/// Owns CONUS HRRR 0–90 min precip slots for Minutecast + Grok.
/// WeatherStore only triggers `refresh(for:)` — it does not parse HRRR JSON.
@MainActor
@Observable
final class ShortTermPrecipStore {
  static let shared = ShortTermPrecipStore()

  private(set) var context: ShortTermPrecipContext = .empty()
  private(set) var lastRefresh: Date?
  private(set) var isRefreshing = false

  /// Cache window per location (plan: ~15–20 minutes).
  private let cacheTTL: TimeInterval = 18 * 60
  private var cachedLocationID: String?

  /// Monotonic generation so a slower older refresh cannot overwrite a newer one.
  private var refreshGeneration = 0

  private let hrrrService = OpenMeteoHRRRService()

  private init() {}

  func refresh(for location: SavedLocation, force: Bool = false) async {
    let locationKey = location.id.uuidString
    if !force,
      let lastRefresh,
      cachedLocationID == locationKey,
      Date().timeIntervalSince(lastRefresh) < cacheTTL,
      context.locationID == locationKey
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

    guard OpenMeteoHRRRService.isCONUS(
      latitude: location.latitude, longitude: location.longitude)
    else {
      guard generation == refreshGeneration else { return }
      context = .empty(locationID: locationKey)
      lastRefresh = Date()
      cachedLocationID = locationKey
      return
    }

    let slots = await hrrrService.fetchMinutely15(
      latitude: location.latitude, longitude: location.longitude)

    guard generation == refreshGeneration else { return }

    if let slots, !slots.isEmpty {
      let summary = MinutecastEngine.summary(from: slots)
      context = ShortTermPrecipContext(
        locationID: locationKey,
        fetchedAt: Date(),
        source: .hrrr,
        slots: slots,
        summary: summary
      )
    } else if context.locationID == locationKey, context.hasHRRRSlots {
      // Soft failure: keep last-good HRRR for this location.
      context = ShortTermPrecipContext(
        locationID: locationKey,
        fetchedAt: Date(),
        source: context.source,
        slots: context.slots,
        summary: context.summary
      )
    } else {
      context = .empty(locationID: locationKey)
    }

    lastRefresh = Date()
    cachedLocationID = locationKey
  }
}
