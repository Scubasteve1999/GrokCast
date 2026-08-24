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

  /// Monotonic generation so a slower older refresh cannot overwrite a newer one.
  private var refreshGeneration = 0

  private let spcService = SPCSevereService()
  private let nwsService = NWSService()

  /// Settings → Storm reports. Default off. LSRs still fetch for Grok either way.
  private var _showsStormReports = StormReportsPreference.isEnabled
  var showsStormReports: Bool {
    get { _showsStormReports }
    set {
      guard newValue != _showsStormReports else { return }
      _showsStormReports = newValue
      StormReportsPreference.isEnabled = newValue
    }
  }

  private init() {}

  /// Refresh severe products for `location`.
  /// - Parameter alerts: CAP alerts already fetched by WeatherStore (preferred). When nil,
  ///   this store may fetch its own; when non-nil (including `[]`), that list is authoritative.
  func refresh(
    for location: SavedLocation,
    force: Bool = false,
    alerts: [NWSAlert]? = nil
  ) async {
    let locationKey = location.id.uuidString
    if !force,
      let lastRefresh,
      cachedLocationID == locationKey,
      Date().timeIntervalSince(lastRefresh) < cacheTTL,
      context.locationID == locationKey
    {
      // Still accept fresher CAP alerts from WeatherStore without re-hitting SPC.
      if let alerts {
        context = SevereWeatherContext(
          locationID: context.locationID,
          fetchedAt: context.fetchedAt,
          day1Outlook: context.day1Outlook,
          mesoscaleDiscussions: context.mesoscaleDiscussions,
          localStormReports: context.localStormReports,
          alerts: alerts
        )
      }
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

    async let outlookResult = spcService.fetchDay1Outlook(
      latitude: location.latitude, longitude: location.longitude)
    async let mdResult = spcService.fetchMesoscaleDiscussions(
      latitude: location.latitude, longitude: location.longitude)
    async let lsrResult = spcService.fetchLocalStormReports(
      latitude: location.latitude, longitude: location.longitude)

    let resolvedAlerts: [NWSAlert]
    if let alerts {
      resolvedAlerts = alerts
    } else {
      do {
        resolvedAlerts = try await nwsService.fetchActiveAlerts(for: location)
      } catch {
        // Keep prior alerts for this location on soft NWS failure.
        resolvedAlerts =
          (context.locationID == locationKey) ? context.alerts : []
      }
    }

    let day1 = await outlookResult
    let discussions = await mdResult
    let reports = await lsrResult

    guard generation == refreshGeneration else { return }

    let anySPCTransportOK =
      day1.succeeded || discussions.succeeded || reports.succeeded
    let assembled = SevereWeatherContext(
      locationID: locationKey,
      fetchedAt: Date(),
      day1Outlook: day1.outlook,
      mesoscaleDiscussions: discussions.items,
      localStormReports: reports.items,
      alerts: resolvedAlerts
    )

    // Soft total SPC failure: keep last-good SPC sections for this location.
    if !anySPCTransportOK,
      context.locationID == locationKey,
      context.hasSPCContent
    {
      context = SevereWeatherContext(
        locationID: locationKey,
        fetchedAt: Date(),
        day1Outlook: context.day1Outlook,
        mesoscaleDiscussions: context.mesoscaleDiscussions,
        localStormReports: context.localStormReports,
        alerts: resolvedAlerts
      )
    } else {
      context = assembled
    }

    lastRefresh = Date()
    cachedLocationID = locationKey
  }
}
