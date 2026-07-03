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
}
