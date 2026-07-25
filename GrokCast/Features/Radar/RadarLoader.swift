import CoreLocation
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

  /// Prefer OWM only when real scans are this old (OWM timestamps are synthesized).
  private static let realSourceStaleThreshold: TimeInterval = 25 * 60

  func loadAll(
    site: IEMRadarService.Site?,
    coordinate: CLLocationCoordinate2D
  ) async -> RadarDatasetResult {
    isLoading = true
    defer { isLoading = false }

    async let rainViewerDataset = RainViewerRadarService.loadDataset()

    let rainViewer = await rainViewerDataset
    let liveOutcome = await resolveLive(
      site: site,
      coordinate: coordinate,
      rainViewerLive: rainViewer.live
    )
    let forecastOutcome = await resolveForecast(rainViewerNowcast: rainViewer.nowcast)

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
      let nowcast = await RainViewerRadarService.loadNowcastFrames()
      if !nowcast.isEmpty {
        return .available
      }
      return .unavailable(message: "Forecast radar unavailable.")
    case .iem:
      return .unavailable(message: "Forecast radar unavailable.")
    case .xweather:
      if XweatherRadarService.mapsAuthConfigured {
        let probeOK = await XweatherRadarService.probeForecastAvailability()
        if probeOK {
          return .available
        }

        let message =
          XweatherRadarService.userFacingUnavailableMessage
          ?? "Xweather forecast radar unavailable."
        print("[Xweather] FUTURE probe failed — timeline-only")
        return .timelineOnly(message: message)
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
      print("[OpenWeatherMap] FUTURE probe failed — using timeline-only")
      return .timelineOnly(message: message)
    }
  }

  /// Loads OpenWeatherMap PR0 forecast frames when the probe succeeds.
  func loadOpenWeatherMapForecastIfAvailable() async -> (
    frames: [RadarFrame], availability: RadarTileAvailability
  )? {
    guard OpenWeatherMapRadarService.apiKeyConfigured else { return nil }
    let probeOK = await OpenWeatherMapRadarService.probeForecastAvailability()
    guard probeOK else { return nil }

    let frames = OpenWeatherMapRadarService.loadForecastFrames()
    guard !frames.isEmpty else { return nil }

    print("[RadarLoader] Forecast timeline ready (\(frames.count) frames) — OpenWeatherMap PR0")
    return (frames, .available)
  }

  private struct LoadOutcome: Equatable {
    var frames: [RadarFrame]
    var provider: RadarTileProvider?
    var availability: RadarTileAvailability
  }

  private func resolveLive(
    site: IEMRadarService.Site?,
    coordinate: CLLocationCoordinate2D,
    rainViewerLive: [RadarFrame]
  ) async -> LoadOutcome {
    // Collect real-scan candidates (IEM / RainViewer), then pick freshest last frame.
    // OWM timestamps are synthesized — only use when reals are missing or stale.
    var realCandidates: [(provider: RadarTileProvider, frames: [RadarFrame], label: String)] = []

    // Default Reflectivity uses the CONUS composite (N0Q). Single-site N0B/N0S load
    // only when the user picks Super-Res or SRV (see RadarState.setProduct).
    if IEMRadarService.isWithinCONUS(coordinate) {
      let conusFrames = await IEMRadarService.loadCONUSReflectivityFrames()
      if !conusFrames.isEmpty {
        realCandidates.append(
          (.iem, conusFrames, "NWS CONUS composite (\(conusFrames.count) scans)"))
      }
    }

    if realCandidates.isEmpty, let site {
      let iemFrames = await IEMRadarService.loadSiteFrames(
        site: site.id,
        product: .superResReflectivity
      )
      if !iemFrames.isEmpty {
        realCandidates.append(
          (.iem, iemFrames, "NWS \(site.id) (\(iemFrames.count) scans)"))
      }
    }

    if !rainViewerLive.isEmpty {
      realCandidates.append(
        (
          .rainViewer, rainViewerLive,
          "RainViewer (\(rainViewerLive.count) frames)"
        ))
    }

    if let bestReal = Self.freshestRealCandidate(realCandidates) {
      let age = Date().timeIntervalSince(bestReal.frames.last?.timestamp ?? .distantPast)
      if age <= Self.realSourceStaleThreshold {
        print("[RadarLoader] Live: \(bestReal.label) (freshest real, age \(Int(age / 60))m)")
        return LoadOutcome(
          frames: bestReal.frames,
          provider: bestReal.provider,
          availability: .available
        )
      }
      print(
        "[RadarLoader] Freshest real source stale (\(Int(age / 60))m) — trying OpenWeatherMap"
      )
    }

    if let openWeatherMap = await loadOpenWeatherMapLive() {
      print("[RadarLoader] Live: OpenWeatherMap (\(openWeatherMap.frames.count) frames)")
      return openWeatherMap
    }

    // Last resort: stale real source still better than nothing.
    if let bestReal = Self.freshestRealCandidate(realCandidates) {
      print("[RadarLoader] Live: \(bestReal.label) (stale real, OWM unavailable)")
      return LoadOutcome(
        frames: bestReal.frames,
        provider: bestReal.provider,
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

  private static func freshestRealCandidate(
    _ candidates: [(provider: RadarTileProvider, frames: [RadarFrame], label: String)]
  ) -> (provider: RadarTileProvider, frames: [RadarFrame], label: String)? {
    candidates.max { lhs, rhs in
      let left = lhs.frames.last?.timestamp ?? .distantPast
      let right = rhs.frames.last?.timestamp ?? .distantPast
      return left < right
    }
  }

  private func resolveForecast(rainViewerNowcast: [RadarFrame]) async -> LoadOutcome {
    if XweatherRadarService.mapsAuthConfigured {
      let xwFrames = XweatherRadarService.loadForecastRadarFrames()
      if !xwFrames.isEmpty {
        let probeOK = await XweatherRadarService.probeForecastAvailability()
        if probeOK {
          print("[RadarLoader] Forecast timeline ready (\(xwFrames.count) frames) — Xweather radar")
          return LoadOutcome(
            frames: xwFrames,
            provider: .xweather,
            availability: .available
          )
        }

        print("[RadarLoader] Xweather forecast probe failed — trying RainViewer nowcast / OWM")
        if !rainViewerNowcast.isEmpty {
          print(
            "[RadarLoader] Forecast timeline ready (\(rainViewerNowcast.count) frames) — RainViewer nowcast"
          )
          return LoadOutcome(
            frames: rainViewerNowcast,
            provider: .rainViewer,
            availability: .available
          )
        }
        if let owmOutcome = await loadOpenWeatherMapForecastIfAvailable() {
          return LoadOutcome(
            frames: owmOutcome.frames,
            provider: .openWeatherMap,
            availability: owmOutcome.availability
          )
        }

        let message =
          XweatherRadarService.userFacingUnavailableMessage
          ?? "Xweather forecast radar unavailable."
        print("[RadarLoader] Xweather tiles unavailable — timeline-only (\(xwFrames.count) frames)")
        return LoadOutcome(
          frames: xwFrames,
          provider: .xweather,
          availability: .timelineOnly(message: message)
        )
      }
    }

    if !rainViewerNowcast.isEmpty {
      print(
        "[RadarLoader] Forecast timeline ready (\(rainViewerNowcast.count) frames) — RainViewer nowcast"
      )
      return LoadOutcome(
        frames: rainViewerNowcast,
        provider: .rainViewer,
        availability: .available
      )
    }

    if let owmOutcome = await loadOpenWeatherMapForecastIfAvailable() {
      return LoadOutcome(
        frames: owmOutcome.frames,
        provider: .openWeatherMap,
        availability: owmOutcome.availability
      )
    }

    let message =
      XweatherRadarService.userFacingUnavailableMessage
      ?? OpenWeatherMapRadarService.userFacingUnavailableMessage
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