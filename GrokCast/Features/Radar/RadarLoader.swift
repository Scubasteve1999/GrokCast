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

  func loadAll() async -> RadarDatasetResult {
    isLoading = true
    defer { isLoading = false }

    let rainViewer = await RainViewerRadarService.loadDatasetFrames()
    let liveOutcome = await resolveLive(rainViewerLive: rainViewer.live)
    let forecastOutcome = await resolveForecast(rainViewerForecast: rainViewer.forecast)

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

  private func resolveLive(rainViewerLive: [RadarFrame]) async -> LoadOutcome {
    let preferredLive = RadarTileProvider.preferredLive

    if preferredLive == .rainViewer {
      if !rainViewerLive.isEmpty {
        print("[RainViewer] Loaded \(rainViewerLive.count) live frames")
        return LoadOutcome(
          frames: rainViewerLive,
          provider: .rainViewer,
          availability: .available
        )
      }

      print("[RainViewer] No live frames returned")
      if let openWeatherMap = await loadOpenWeatherMapLive() {
        return openWeatherMap
      }
    } else {
      let openWeatherMapLive = await loadOpenWeatherMapLive()
      if let openWeatherMap = openWeatherMapLive {
        return openWeatherMap
      }

      if !rainViewerLive.isEmpty {
        print("[RainViewer] Loaded \(rainViewerLive.count) live frames (secondary)")
        return LoadOutcome(
          frames: rainViewerLive,
          provider: .rainViewer,
          availability: .available
        )
      }
    }

    print("[RadarLoader] Live radar unavailable — RainViewer and OpenWeatherMap both failed")
    return LoadOutcome(
      frames: [],
      provider: nil,
      availability: .unavailable(
        message: "Radar unavailable. RainViewer and OpenWeatherMap both failed."
      )
    )
  }

  private func resolveForecast(rainViewerForecast: [RadarFrame]) async -> LoadOutcome {
    // Prefer Xweather (fradar) when its keys are present — primary for FUTURE per current architecture.
    // Tiles attempted optimistically (probe is only for status messaging).
    if XweatherRadarService.mapsAuthConfigured {
      let xwFrames = XweatherRadarService.loadForecastRadarFrames()
      if !xwFrames.isEmpty {
        // Fire probe in background for better messaging, but don't block frames.
        Task {
          _ = await XweatherRadarService.probeForecastAvailability()
        }
        print("[RadarLoader] Forecast timeline ready (\(xwFrames.count) frames) — Xweather fradar")
        return LoadOutcome(
          frames: xwFrames,
          provider: .xweather,
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

    // Last resort: OpenWeatherMap PR0 (often requires paid Maps sub for forecast tiles).
    let forecastProvider = RadarTileProvider.preferredForecast
    guard OpenWeatherMapRadarService.apiKeyConfigured else {
      return LoadOutcome(
        frames: [],
        provider: nil,
        availability: .unavailable(message: "OpenWeatherMap API key not configured.")
      )
    }

    let probeOK = await OpenWeatherMapRadarService.probeForecastAvailability()
    if probeOK {
      let frames = OpenWeatherMapRadarService.loadForecastFrames()
      if !frames.isEmpty {
        print(
          "[RadarLoader] Forecast timeline ready (\(frames.count) frames) — \(forecastProvider.displayName) PR0 (fallback)"
        )
        return LoadOutcome(
          frames: frames,
          provider: forecastProvider,
          availability: .available
        )
      }
    }

    // No valid forecast data source
    let message = OpenWeatherMapRadarService.userFacingUnavailableMessage
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