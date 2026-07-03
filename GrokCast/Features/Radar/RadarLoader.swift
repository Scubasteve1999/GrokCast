import Foundation

enum RadarTileAvailability: Equatable {
  case available
  case timelineOnly(message: String)
  case unavailable(message: String)

  var showsTiles: Bool {
    if case .available = self { return true }
    return false
  }

  var userMessage: String? {
    switch self {
    case .available:
      return nil
    case .timelineOnly(let message), .unavailable(let message):
      return message
    }
  }

  var hasFrames: Bool {
    switch self {
    case .unavailable:
      return false
    case .available, .timelineOnly:
      return true
    }
  }
}

struct RadarDatasetResult: Equatable {
  var live: [RadarFrame]
  var forecast: [RadarFrame]
  var liveProvider: RadarTileProvider?
  var forecastProvider: RadarTileProvider?
  var liveAvailability: RadarTileAvailability
  var forecastAvailability: RadarTileAvailability

  var liveUnavailableMessage: String? { liveAvailability.userMessage }
  var futureUnavailableMessage: String? { forecastAvailability.userMessage }

  static let empty = RadarDatasetResult(
    live: [],
    forecast: [],
    liveProvider: nil,
    forecastProvider: nil,
    liveAvailability: .unavailable(message: "Radar unavailable."),
    forecastAvailability: .unavailable(message: "Forecast radar unavailable.")
  )
}

@MainActor
@Observable
final class RadarLoader {
  private(set) var isLoading = false

  func loadAll(site: IEMRadarService.Site?) async -> RadarDatasetResult {
    isLoading = true
    defer { isLoading = false }

    async let rainViewer = RainViewerRadarService.loadDatasetFrames()
    async let owmProbeOK: Bool = {
      guard OpenWeatherMapRadarService.apiKeyConfigured else { return false }
      return await OpenWeatherMapRadarService.probeForecastAvailability()
    }()

    let rainViewerResult = await rainViewer
    let liveOutcome = await resolveLive(site: site, rainViewerLive: rainViewerResult.live)
    let forecastOutcome = await resolveForecast(
      rainViewerForecast: rainViewerResult.forecast,
      owmProbeOK: await owmProbeOK
    )

    return RadarDatasetResult(
      live: liveOutcome.frames,
      forecast: forecastOutcome.frames,
      liveProvider: liveOutcome.provider,
      forecastProvider: forecastOutcome.provider,
      liveAvailability: liveOutcome.availability,
      forecastAvailability: forecastOutcome.availability
    )
  }

  func refreshForecastAvailability(provider: RadarTileProvider) async -> RadarTileAvailability {
    switch provider {
    case .rainViewer:
      return .available
    case .iem:
      // Single-site NEXRAD products are live-only; never a forecast provider.
      return .unavailable(message: "Forecast radar unavailable.")
    case .xweather:
      if XweatherRadarService.mapsAuthConfigured {
        // Probe is advisory; serve as available so tiles can be attempted.
        Task { _ = await XweatherRadarService.probeForecastAvailability() }
        return .available
      }
      return .timelineOnly(message: "Xweather keys not configured for forecast.")
    case .openWeatherMap:
      guard OpenWeatherMapRadarService.apiKeyConfigured else {
        return .timelineOnly(message: "OpenWeatherMap API key not configured.")
      }

      let probeOK = await OpenWeatherMapRadarService.probeForecastAvailability()
      if probeOK {
        return .available
      }

      let message =
        OpenWeatherMapRadarService.userFacingUnavailableMessage
        ?? "OpenWeatherMap FUTURE tiles require a Maps-enabled key (see OpenWeatherMapKeys.swift)."
      print("[OpenWeatherMap] FUTURE probe failed — using timeline-only (optimistic)")
      return .timelineOnly(message: message)
    }
  }

  private struct LoadOutcome: Equatable {
    var frames: [RadarFrame]
    var provider: RadarTileProvider?
    var availability: RadarTileAvailability
  }

  private func resolveLive(
    site: IEMRadarService.Site?,
    rainViewerLive: [RadarFrame]
  ) async -> LoadOutcome {
    // Prefer real NWS NEXRAD super-res reflectivity when a site is nearby (US).
    if let site {
      let iemFrames = await IEMRadarService.loadSiteFrames(
        site: site.id,
        product: .superResReflectivity
      )
      if !iemFrames.isEmpty {
        print("[IEM] Loaded \(iemFrames.count) live scans — NWS \(site.id)")
        return LoadOutcome(
          frames: iemFrames,
          provider: .iem,
          availability: .available
        )
      }
    }

    if let openWeatherMap = await loadOpenWeatherMapLive() {
      return openWeatherMap
    }

    if !rainViewerLive.isEmpty {
      print("[RainViewer] Loaded \(rainViewerLive.count) live frames (fallback)")
      return LoadOutcome(
        frames: rainViewerLive,
        provider: .rainViewer,
        availability: .available
      )
    }

    print("[RadarLoader] Live radar unavailable — IEM, OpenWeatherMap, and RainViewer failed")
    return LoadOutcome(
      frames: [],
      provider: nil,
      availability: .unavailable(
        message: "Radar unavailable. No live source responded."
      )
    )
  }

  private func resolveForecast(
    rainViewerForecast: [RadarFrame],
    owmProbeOK: Bool
  ) async -> LoadOutcome {
    // Prefer OpenWeatherMap PR0 when the Maps subscription is active (probe ran
    // concurrently with the RainViewer fetch in loadAll).
    if OpenWeatherMapRadarService.apiKeyConfigured, owmProbeOK {
      let frames = OpenWeatherMapRadarService.loadForecastFrames()
      if !frames.isEmpty {
        print(
          "[RadarLoader] Forecast timeline ready (\(frames.count) frames) — OpenWeatherMap PR0"
        )
        return LoadOutcome(
          frames: frames,
          provider: .openWeatherMap,
          availability: .available
        )
      }
    }

    if !rainViewerForecast.isEmpty {
      print(
        "[RadarLoader] Forecast timeline ready (\(rainViewerForecast.count) frames) — RainViewer"
      )
      return LoadOutcome(
        frames: rainViewerForecast,
        provider: .rainViewer,
        availability: .available
      )
    }

    if XweatherRadarService.mapsAuthConfigured {
      let xwFrames = XweatherRadarService.loadForecastRadarFrames()
      if !xwFrames.isEmpty {
        Task { _ = await XweatherRadarService.probeForecastAvailability() }
        print("[RadarLoader] Forecast timeline ready (\(xwFrames.count) frames) — Xweather fradar (fallback)")
        return LoadOutcome(
          frames: xwFrames,
          provider: .xweather,
          availability: .available
        )
      }
    }

    let message =
      OpenWeatherMapRadarService.userFacingUnavailableMessage
      ?? XweatherRadarService.userFacingUnavailableMessage
      ?? "Forecast radar unavailable."
    print("[RadarLoader] Forecast timeline unavailable (no valid provider)")
    return LoadOutcome(
      frames: [],
      provider: nil,
      availability: .unavailable(message: message)
    )
  }

  private static func openWeatherMapUnavailableMessage() -> String {
    if !OpenWeatherMapRadarService.apiKeyConfigured {
      return "OpenWeatherMap API key not configured."
    }
    return OpenWeatherMapRadarService.userFacingUnavailableMessage
      ?? "OpenWeatherMap radar unavailable. Check connection or API key."
  }

  private func loadOpenWeatherMapLive() async -> LoadOutcome? {
    guard OpenWeatherMapRadarService.apiKeyConfigured else {
      print("[OpenWeatherMap] No API key configured — skipping live fallback")
      return nil
    }

    let frames = OpenWeatherMapRadarService.loadRecentFrames()
    guard !frames.isEmpty else { return nil }

    let probeOK = await OpenWeatherMapRadarService.probeAvailability()
    let availability: RadarTileAvailability
    if probeOK {
      availability = .available
    } else {
      availability = .timelineOnly(message: Self.openWeatherMapUnavailableMessage())
      print("[OpenWeatherMap] Live probe failed — serving timeline optimistically")
    }

    return LoadOutcome(
      frames: frames,
      provider: .openWeatherMap,
      availability: availability
    )
  }
}