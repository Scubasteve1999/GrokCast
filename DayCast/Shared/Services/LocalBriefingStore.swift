import Foundation
import Observation

/// Owns NWS AFD KEY MESSAGES + filtered PNS cards for the Alerts tab.
/// WeatherStore only triggers `refresh(for:)` — it does not parse products.
@MainActor
@Observable
final class LocalBriefingStore {
  static let shared = LocalBriefingStore()

  private(set) var items: [LocalBriefingItem] = []
  private(set) var locationID: String?
  private(set) var lastRefresh: Date?
  private(set) var isRefreshing = false

  /// Same ~20 min window as `SevereWeatherStore`.
  private let cacheTTL: TimeInterval = 20 * 60
  private var cachedLocationID: String?

  /// Monotonic generation so a slower MEG response cannot overwrite Tampa.
  private var refreshGeneration = 0

  private let nwsService = NWSService()
  private var officeNameByCWA: [String: String] = [:]

  private init() {}

  func refresh(for location: SavedLocation, force: Bool = false) async {
    let locationKey = location.id.uuidString
    if !force,
      let lastRefresh,
      cachedLocationID == locationKey,
      Date().timeIntervalSince(lastRefresh) < cacheTTL,
      locationID == locationKey
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

    do {
      try Task.checkCancellation()
      let cwa = await nwsService.fetchCWA(for: location)
      guard generation == refreshGeneration else { return }

      guard let cwa else {
        items = []
        locationID = locationKey
        lastRefresh = Date()
        cachedLocationID = locationKey
        return
      }

      async let afdList = nwsService.fetchTextProductSummaries(type: "AFD", cwa: cwa)
      async let pnsList = nwsService.fetchTextProductSummaries(type: "PNS", cwa: cwa)
      async let resolvedOffice = officeName(for: cwa)

      let afdSummaries = await afdList
      let pnsSummaries = await pnsList
      let officeName = await resolvedOffice
      if let officeName {
        officeNameByCWA[cwa] = officeName
      }

      guard generation == refreshGeneration else { return }
      try Task.checkCancellation()

      let now = Date()
      let afdSummary = afdSummaries.first { summary in
        guard let issued = LocalBriefingParser.parseIssuance(summary.issuanceTime) else {
          return false
        }
        return LocalBriefingParser.isAFDFresh(issued, now: now)
      }
      let pnsFresh = pnsSummaries.filter { summary in
        guard let issued = LocalBriefingParser.parseIssuance(summary.issuanceTime) else {
          return false
        }
        return LocalBriefingParser.isPNSFresh(issued, now: now)
      }

      var afdPayload: (id: String, issuedAt: Date, text: String)?
      if let afdSummary {
        if let product = await nwsService.fetchTextProduct(id: afdSummary.id),
          let issued = LocalBriefingParser.parseIssuance(product.issuanceTime)
            ?? LocalBriefingParser.parseIssuance(afdSummary.issuanceTime)
        {
          afdPayload = (product.id, issued, product.productText ?? "")
        }
      }

      var pnsPayload: [(id: String, issuedAt: Date, text: String)] = []
      for summary in pnsFresh.prefix(3) {
        guard generation == refreshGeneration else { return }
        guard let product = await nwsService.fetchTextProduct(id: summary.id),
          let issued = LocalBriefingParser.parseIssuance(product.issuanceTime)
            ?? LocalBriefingParser.parseIssuance(summary.issuanceTime)
        else { continue }
        pnsPayload.append((product.id, issued, product.productText ?? ""))
      }

      guard generation == refreshGeneration else { return }

      items = LocalBriefingParser.assemble(
        cwa: cwa,
        officeName: officeName,
        afd: afdPayload,
        pns: pnsPayload,
        now: now
      )
      locationID = locationKey
      lastRefresh = Date()
      cachedLocationID = locationKey
    } catch is CancellationError {
      return
    } catch {
      guard generation == refreshGeneration else { return }
      if locationID != locationKey {
        items = []
        locationID = locationKey
      }
      lastRefresh = Date()
      cachedLocationID = locationKey
    }
  }

  private func officeName(for cwa: String) async -> String? {
    if let cached = officeNameByCWA[cwa] { return cached }
    return await nwsService.fetchOfficeName(cwa: cwa)
  }
}
