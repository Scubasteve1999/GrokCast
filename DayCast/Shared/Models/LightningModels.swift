import CoreLocation
import Foundation

/// One cloud-to-ground pulse from Xweather `/lightning`.
struct LightningStrike: Identifiable, Equatable, Sendable {
  let id: String
  let latitude: Double
  let longitude: Double
  let time: Date
  let pulseType: String
  let peakAmps: Double?

  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }

  func ageMinutes(now: Date = Date()) -> Double {
    max(0, now.timeIntervalSince(time) / 60)
  }
}

enum LightningFetchQuietReason: Equatable, Sendable {
  case missingKey
  case insufficientScope
  case network
  case empty
}

struct LightningSnapshot: Equatable, Sendable {
  var strikes: [LightningStrike] = []
  var lastUpdated: Date?
  var quietReason: LightningFetchQuietReason?

  /// Shown on Live Radar while the overlay is on.
  static let attribution = "Vaisala Xweather"
}

/// Rolling window: Xweather standard access only returns ~5 minutes per request,
/// so the store merges polls and drops anything older than `maxAge`.
enum LightningStrikeWindow {
  static let maxAge: TimeInterval = 20 * 60
  static let maxCount = 2500

  static func prune(
    _ strikes: [LightningStrike],
    now: Date = Date(),
    maxAge: TimeInterval = maxAge,
    maxCount: Int = maxCount
  ) -> [LightningStrike] {
    strikes
      .filter { now.timeIntervalSince($0.time) <= maxAge }
      .sorted { $0.time > $1.time }
      .prefix(maxCount)
      .map { $0 }
  }

  static func merging(
    existing: [LightningStrike],
    incoming: [LightningStrike],
    now: Date = Date(),
    maxAge: TimeInterval = maxAge,
    maxCount: Int = maxCount
  ) -> [LightningStrike] {
    var byID: [String: LightningStrike] = [:]
    byID.reserveCapacity(existing.count + incoming.count)
    for strike in existing { byID[strike.id] = strike }
    for strike in incoming { byID[strike.id] = strike }
    return prune(Array(byID.values), now: now, maxAge: maxAge, maxCount: maxCount)
  }
}
