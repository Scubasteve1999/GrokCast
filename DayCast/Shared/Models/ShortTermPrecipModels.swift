import Foundation

// MARK: - Short-term precip snapshot (immutable; owned by ShortTermPrecipStore)

/// Where the 0–90 min slots came from.
enum ShortTermPrecipSource: String, Codable, Equatable, Sendable {
  case hrrr
  case openMeteoFallback
  case none
}

/// CONUS HRRR (or empty) short-term precip context for Minutecast + Grok.
struct ShortTermPrecipContext: Equatable {
  let locationID: String
  let fetchedAt: Date
  let source: ShortTermPrecipSource
  /// Next ~6×15 min slots (0–90 min) when `source == .hrrr`.
  let slots: [MinutelyForecast]
  /// Precomputed strip summary from `MinutecastEngine` when slots are present.
  let summary: MinutecastSummary?

  static func empty(locationID: String = "") -> ShortTermPrecipContext {
    ShortTermPrecipContext(
      locationID: locationID,
      fetchedAt: .distantPast,
      source: .none,
      slots: [],
      summary: nil
    )
  }

  var hasHRRRSlots: Bool {
    source == .hrrr && !slots.isEmpty
  }

  /// Soft-fail / display cutoff. Older than this is not "now" — fall back to Open-Meteo minutely.
  static let maxUsableAge: TimeInterval = 45 * 60

  func isUsableHRRR(at now: Date = Date()) -> Bool {
    hasHRRRSlots && now.timeIntervalSince(fetchedAt) < Self.maxUsableAge
  }

  /// Soft-fail keeps last-good slots and the **original** `fetchedAt`. Drops HRRR when too old.
  static func keepingLastGood(
    _ previous: ShortTermPrecipContext,
    locationID: String,
    at now: Date = Date()
  ) -> ShortTermPrecipContext {
    guard previous.locationID == locationID, previous.isUsableHRRR(at: now) else {
      return .empty(locationID: locationID)
    }
    return previous
  }
}
