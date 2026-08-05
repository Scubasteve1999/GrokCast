import Foundation

struct MinutecastSummary: Equatable {
  enum Kind: Equatable {
    case clear
    case startsSoon
    case ongoing
    case stoppingSoon
  }

  let kind: Kind
  let message: String
  let icon: String
  /// Next 8 fifteen-minute slots for the strip (up to 2 hours).
  let strip: [MinutelyForecast]
}

enum MinutecastEngine {
  private static let chanceThreshold = 45
  /// Half a 15-minute slot — treat precip starting within this window as "now".
  private static let ongoingWindowMinutes = 8

  static func summary(
    from slots: [MinutelyForecast],
    units: TemperatureUnit = .fahrenheit,
    now: Date = Date()
  ) -> MinutecastSummary {
    let precipThreshold = units == .fahrenheit ? 0.008 : 0.2
    let upcoming = slots.filter { $0.time >= now.addingTimeInterval(-60) }.prefix(8)
    let strip = Array(upcoming)

    guard !strip.isEmpty else {
      return MinutecastSummary(
        kind: .clear,
        message: "Precipitation data unavailable",
        icon: "cloud.fill",
        strip: []
      )
    }

    func isWet(_ slot: MinutelyForecast) -> Bool {
      slot.precipitation >= precipThreshold || slot.precipChance >= chanceThreshold
    }

    func minutesUntil(_ slot: MinutelyForecast) -> Int {
      max(0, Int(slot.time.timeIntervalSince(now) / 60))
    }

    let wetIndices = strip.indices.filter { isWet(strip[$0]) }

    if wetIndices.isEmpty {
      return MinutecastSummary(
        kind: .clear,
        message: "No precipitation for at least 2 hours",
        icon: "sun.max.fill",
        strip: strip
      )
    }

    let firstWet = wetIndices[0]
    let minutesUntilFirst = minutesUntil(strip[firstWet])

    if minutesUntilFirst <= ongoingWindowMinutes {
      if wetIndices.count == strip.count {
        return MinutecastSummary(
          kind: .ongoing,
          message: "Precipitation likely for the next 2 hours",
          icon: "cloud.rain.fill",
          strip: strip
        )
      }
      if let lastWet = wetIndices.last, lastWet < strip.count - 1 {
        let stopMin = minutesUntil(strip[lastWet + 1])
        return MinutecastSummary(
          kind: .stoppingSoon,
          message: "Precipitation ending in ~\(stopMin) min",
          icon: "cloud.drizzle.fill",
          strip: strip
        )
      }
      return MinutecastSummary(
        kind: .ongoing,
        message: "Precipitation now",
        icon: "cloud.rain.fill",
        strip: strip
      )
    }

    let rounded = (minutesUntilFirst / 5) * 5
    let display = max(5, rounded)
    return MinutecastSummary(
      kind: .startsSoon,
      message: "Precipitation likely in ~\(display) min",
      icon: "cloud.rain.fill",
      strip: strip
    )
  }

  /// Index of the first wet slot in the upcoming strip, or `nil` if clear / empty.
  static func firstWetIndex(
    in slots: [MinutelyForecast],
    units: TemperatureUnit = .fahrenheit,
    now: Date = Date()
  ) -> Int? {
    let precipThreshold = units == .fahrenheit ? 0.008 : 0.2
    let strip = Array(
      slots.lazy.filter { $0.time >= now.addingTimeInterval(-60) }.prefix(8)
    )
    return strip.indices.first { index in
      let slot = strip[index]
      return slot.precipitation >= precipThreshold || slot.precipChance >= chanceThreshold
    }
  }
}

// MARK: - HRRR vs Open-Meteo agreement

enum MinutecastAgreement {
  enum Result: Equatable {
    case agree
    case disagree(preferred: MinutecastSummary, otherKind: MinutecastSummary.Kind)
  }

  /// Compare CONUS HRRR slots against Open-Meteo blended minutecast.
  /// Disagreement = kind differs or first-wet index differs by ≥ 2 (30+ min).
  static func compare(
    hrrr: [MinutelyForecast],
    openMeteo: [MinutelyForecast],
    units: TemperatureUnit = .fahrenheit,
    now: Date = Date()
  ) -> Result {
    guard !hrrr.isEmpty, !openMeteo.isEmpty else { return .agree }

    let preferred = MinutecastEngine.summary(from: hrrr, units: units, now: now)
    let other = MinutecastEngine.summary(from: openMeteo, units: units, now: now)

    let hrrrWet = MinutecastEngine.firstWetIndex(in: hrrr, units: units, now: now)
    let omWet = MinutecastEngine.firstWetIndex(in: openMeteo, units: units, now: now)

    let kindDiffers = preferred.kind != other.kind
    let timingDiffers: Bool = {
      switch (hrrrWet, omWet) {
      case (nil, nil):
        return false
      case (nil, _), (_, nil):
        return true
      case let (h?, o?):
        return abs(h - o) >= 2
      }
    }()

    guard kindDiffers || timingDiffers else { return .agree }
    return .disagree(preferred: preferred, otherKind: other.kind)
  }

  /// Quiet strip caption when sources disagree (HRRR remains primary).
  static func caption(for result: Result) -> String? {
    guard case .disagree(_, let otherKind) = result else { return nil }
    switch otherKind {
    case .clear:
      return "Sources differ · Open-Meteo clearer"
    case .startsSoon:
      return "Sources differ · Open-Meteo starts sooner"
    case .ongoing:
      return "Sources differ · Open-Meteo wetter now"
    case .stoppingSoon:
      return "Sources differ · Open-Meteo ending sooner"
    }
  }

  /// One-liner for Grok prompts.
  static func grokNote(for result: Result) -> String? {
    guard case .disagree(_, let otherKind) = result else { return nil }
    let label: String = {
      switch otherKind {
      case .clear: "clear / drier"
      case .startsSoon: "precip starting soon"
      case .ongoing: "precip ongoing"
      case .stoppingSoon: "precip ending soon"
      }
    }()
    return "Open-Meteo blended minutecast differs: \(label)"
  }
}
