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

  func loadAll(
    site: IEMRadarService.Site?,
    coordinate: CLLocationCoordinate2D
  ) async -> RadarDatasetResult {
    isLoading = true
    defer { isLoading = false }

    async let rainViewerLive = RainViewerRadarService.loadLiveFrames()

    let liveOutcome = await resolveLive(
      site: site,
      coordinate: coordinate,
      rainViewerLive: await rainViewerLive
    )
    let forecastOutcome = await resolveForecast()

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
    case .rainViewer, .iem:
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
    // Default Reflectivity uses the CONUS composite (N0Q). Single-site N0B/N0S load
    // only when the user picks Super-Res or SRV (see RadarState.setProduct).
    if IEMRadarService.isWithinCONUS(coordinate) {
      let conusFrames = await IEMRadarService.loadCONUSReflectivityFrames()
      if !conusFrames.isEmpty {
        print("[IEM] Loaded \(conusFrames.count) live scans — NWS CONUS composite")
        return LoadOutcome(
          frames: conusFrames,
          provider: .iem,
          availability: .available
        )
      }
    }

    // Single-site super-res when CONUS fails but a nearby site exists.
    if let site {
      let iemFrames = await IEMRadarService.loadSiteFrames(
        site: site.id,
        product: .superResReflectivity
      )
      if !iemFrames.isEmpty {
        print("[IEM] Loaded \(iemFrames.count) live scans — NWS \(site.id) (CONUS fallback)")
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
      print("[RainViewer] Loaded \(rainViewerLive.count) live frames (international fallback)")
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

  private func resolveForecast() async -> LoadOutcome {
    if XweatherRadarService.mapsAuthConfigured {
      let xwFrames = XweatherRadarService.loadForecastRadarFrames()
      if !xwFrames.isEmpty {
        let probeOK = await XweatherRadarService.probeForecastAvailability()
        if probeOK {
          print("[RadarLoader] Forecast timeline ready (\(xwFrames.count) frames) — Xweather fradar")
          return LoadOutcome(
            frames: xwFrames,
            provider: .xweather,
            availability: .available
          )
        }

        print("[RadarLoader] Xweather fradar probe failed — trying OpenWeatherMap fallback")
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