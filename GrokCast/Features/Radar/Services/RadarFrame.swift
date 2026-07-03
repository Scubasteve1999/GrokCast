import Foundation

/// Provider-agnostic descriptor for one radar animation frame.
struct RadarFrame: Equatable {
  let provider: RadarTileProvider
  let kind: Kind
  let tileEpoch: Int
  let timestamp: Date
  /// Mapbox raster source templates with `{z}`, `{x}`, `{y}` placeholders.
  let tileURLTemplates: [String]

  enum Kind: Equatable {
    case livePrecipitation
    case forecastPrecipitation
  }

  init(
    provider: RadarTileProvider,
    kind: Kind,
    tileEpoch: Int,
    timestamp: Date,
    tileURLTemplates: [String]
  ) {
    self.provider = provider
    self.kind = kind
    self.tileEpoch = tileEpoch
    self.timestamp = timestamp
    self.tileURLTemplates = tileURLTemplates
  }

  var tileKey: String {
    let templateFingerprint = tileURLTemplates.first?
      .suffix(24) ?? ""
    switch (provider, kind) {
    case (.rainViewer, .livePrecipitation):
      return "rv:radar:\(tileEpoch):\(templateFingerprint)"
    case (.rainViewer, .forecastPrecipitation):
      return "rv:nowcast:\(tileEpoch):\(templateFingerprint)"
    case (.xweather, .livePrecipitation):
      return "xw:radar:\(tileEpoch)"
    case (.xweather, .forecastPrecipitation):
      return "xw:fradar:\(tileEpoch)"
    case (.openWeatherMap, .livePrecipitation):
      return "owm:radar:\(tileEpoch)"
    case (.openWeatherMap, .forecastPrecipitation):
      return "owm:pr0:\(tileEpoch)"
    case (.iem, .livePrecipitation), (.iem, .forecastPrecipitation):
      // Fingerprint carries site + product + scan time from the ridge layer path.
      return "iem:\(tileEpoch):\(templateFingerprint)"
    }
  }

  func forecastLabel(anchor: Date?) -> String {
    guard let anchor else { return displayTime }
    let minutes = Int(timestamp.timeIntervalSince(anchor) / 60)
    if minutes <= 0 { return "Now" }
    if minutes < 60 { return "+\(minutes)m" }
    let hours = minutes / 60
    let rem = minutes % 60
    if rem == 0 { return "+\(hours)h" }
    return "+\(hours)h \(rem)m"
  }

  private static let displayTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    formatter.timeZone = .current
    return formatter
  }()

  var displayTime: String {
    Self.displayTimeFormatter.string(from: timestamp)
  }

  func timelineLabel(showingFuture: Bool, forecastAnchor: Date?) -> String {
    if showingFuture {
      return forecastLabel(anchor: forecastAnchor)
    }
    return Self.scrubberTimeFormatter.string(from: timestamp)
  }

  private static let scrubberTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    formatter.timeZone = .current
    return formatter
  }()
}