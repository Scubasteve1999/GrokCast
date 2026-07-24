import Foundation
import Observation

/// Owns SPC outlooks / MDs / LSRs + enriched CAP alert snapshot for severe context.
/// WeatherStore only triggers `refresh(for:)` — it does not parse SPC products.
@MainActor
@Observable
final class SevereWeatherStore {
  static let shared = SevereWeatherStore()

  private(set) var context: SevereWeatherContext = .empty()
  private(set) var lastRefresh: Date?
  private(set) var isRefreshing = false

  /// Cache window per location (plan: ~15–30 minutes).
  private let cacheTTL: TimeInterval = 20 * 60
  private var cachedLocationID: String?

  private let spcService = SPCSevereService()
  private let nwsService = NWSService()

  private init() {}

  /// Refresh severe products for `location`. Silent / additive on failure.
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

    isRefreshing = true
    defer { isRefreshing = false }

    async let outlook = spcService.fetchDay1Outlook(
      latitude: location.latitude, longitude: location.longitude)
    async let mds = spcService.fetchMesoscaleDiscussions(
      latitude: location.latitude, longitude: location.longitude)
    async let lsrs = spcService.fetchLocalStormReports(
      latitude: location.latitude, longitude: location.longitude)
    async let alerts: [NWSAlert] = {
      do {
        return try await nwsService.fetchActiveAlerts(for: location)
      } catch {
        return []
      }
    }()

    let day1 = await outlook
    let discussions = await mds
    let reports = await lsrs
    let fetchedAlerts = await alerts

    // Empty sections are valid (quiet US day / non-US). Soft failures inside SPC/NWS
    // already return empty arrays rather than throwing.
    context = SevereWeatherContext(
      locationID: locationKey,
      fetchedAt: Date(),
      day1Outlook: day1,
      mesoscaleDiscussions: discussions,
      localStormReports: reports,
      alerts: fetchedAlerts
    )
    lastRefresh = Date()
    cachedLocationID = locationKey
  }
}
