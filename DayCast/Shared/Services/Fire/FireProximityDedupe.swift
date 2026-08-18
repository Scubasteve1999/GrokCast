import CoreLocation
import Foundation

struct FireNotifyConfig: Equatable, Sendable {
  /// Notify when a hotspot/incident is within this distance of the user location.
  var radiusMiles: Double = 25
  /// Spatial grid cell size for FIRMS hotspot dedupe (~0.015° ≈ 1.6 km).
  var hotspotGridDegrees: Double = 0.015
  /// Do not re-notify the same hotspot cell within this window.
  var hotspotCooldownHours: Double = 12

  static let `default` = FireNotifyConfig()
}

enum FireNotifyCandidate: Equatable, Sendable {
  /// Satellite detection — deduped by spatial grid cell + cooldown.
  case hotspot(latitude: Double, longitude: Double)
  /// Named NIFC incident — deduped by stable incident id (no re-notify on growth).
  case incident(id: String, name: String?, latitude: Double?, longitude: Double?)
}

struct FireNotifyHistory: Equatable, Sendable {
  /// Grid cell key → last notified date.
  var hotspotCells: [String: Date] = [:]
  /// NIFC / IRWIN ids already notified.
  var incidentIDs: Set<String> = []

  static let empty = FireNotifyHistory()
}

enum FireNotifyDecision: Equatable, Sendable {
  case notify(dedupeKey: String)
  case skip(SkipReason)

  enum SkipReason: Equatable, Sendable {
    case outsideRadius
    case cooldown
    case alreadyNotified
    case missingCoordinate
    case invalidCandidate
  }
}

/// Pure spatial + temporal dedupe for fire proximity notifications.
/// No UserNotifications / UserDefaults — history is passed in and returned via `applying`.
enum FireProximityDedupe {
  static func gridCell(
    latitude: Double,
    longitude: Double,
    degrees: Double = FireNotifyConfig.default.hotspotGridDegrees
  ) -> String {
    let step = max(degrees, 0.0001)
    let latCell = (latitude / step).rounded(.down)
    let lonCell = (longitude / step).rounded(.down)
    return "\(Int(latCell)):\(Int(lonCell))"
  }

  static func distanceMiles(
    from origin: CLLocationCoordinate2D,
    to target: CLLocationCoordinate2D
  ) -> Double {
    let earthRadiusMiles = 3958.7613
    let lat1 = origin.latitude * .pi / 180
    let lat2 = target.latitude * .pi / 180
    let dLat = (target.latitude - origin.latitude) * .pi / 180
    let dLon = (target.longitude - origin.longitude) * .pi / 180
    let a =
      sin(dLat / 2) * sin(dLat / 2)
      + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
    let c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return earthRadiusMiles * c
  }

  static func shouldNotify(
    candidate: FireNotifyCandidate,
    origin: CLLocationCoordinate2D,
    history: FireNotifyHistory,
    now: Date = Date(),
    config: FireNotifyConfig = .default
  ) -> FireNotifyDecision {
    switch candidate {
    case .hotspot(let latitude, let longitude):
      let target = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
      let miles = distanceMiles(from: origin, to: target)
      guard miles <= config.radiusMiles else { return .skip(.outsideRadius) }

      let key = "hotspot:" + gridCell(
        latitude: latitude,
        longitude: longitude,
        degrees: config.hotspotGridDegrees
      )
      if let last = history.hotspotCells[key] {
        let hours = now.timeIntervalSince(last) / 3600
        if hours < config.hotspotCooldownHours {
          return .skip(.cooldown)
        }
      }
      return .notify(dedupeKey: key)

    case .incident(let id, _, let latitude, let longitude):
      let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return .skip(.invalidCandidate) }

      if let latitude, let longitude {
        let miles = distanceMiles(
          from: origin,
          to: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        )
        guard miles <= config.radiusMiles else { return .skip(.outsideRadius) }
      }
      // Nil coordinates: candidate already came from regional bbox fetch — allow by id.

      let key = "incident:" + trimmed
      if history.incidentIDs.contains(trimmed) {
        return .skip(.alreadyNotified)
      }
      return .notify(dedupeKey: key)
    }
  }

  static func applying(
    _ decision: FireNotifyDecision,
    to history: FireNotifyHistory,
    now: Date = Date()
  ) -> FireNotifyHistory {
    guard case .notify(let key) = decision else { return history }
    var next = history
    if key.hasPrefix("hotspot:") {
      next.hotspotCells[key] = now
    } else if key.hasPrefix("incident:") {
      let id = String(key.dropFirst("incident:".count))
      next.incidentIDs.insert(id)
    }
    return next
  }

  /// Drop hotspot cells older than the cooldown window (keeps history bounded).
  static func pruned(
    _ history: FireNotifyHistory,
    now: Date = Date(),
    config: FireNotifyConfig = .default
  ) -> FireNotifyHistory {
    let cutoff = now.addingTimeInterval(-config.hotspotCooldownHours * 3600)
    var next = history
    next.hotspotCells = history.hotspotCells.filter { $0.value >= cutoff }
    return next
  }
}

/// Whether the Today feed should show a Fire card.
enum FireFeedVisibility {
  static func isFireWeatherAlert(_ alert: NWSAlert) -> Bool {
    let event = alert.event.lowercased()
    return event.contains("red flag") || event.contains("fire weather")
  }

  static func shouldShowCard(
    snapshot: FireSnapshot,
    origin: CLLocationCoordinate2D?,
    alerts: [NWSAlert],
    radiusMiles: Double = FireNotifyConfig.default.radiusMiles
  ) -> Bool {
    if alerts.contains(where: { !$0.isExpired && isFireWeatherAlert($0) }) {
      return true
    }
    guard let origin else { return false }

    let nearIncident = snapshot.incidents.contains { incident in
      guard let coordinate = incident.coordinate else {
        // Regional fetch without POO — still meaningful named fire context.
        return incident.name != nil
      }
      return FireProximityDedupe.distanceMiles(from: origin, to: coordinate) <= radiusMiles
    }
    if nearIncident { return true }

    return snapshot.hotspots.contains { spot in
      FireProximityDedupe.distanceMiles(from: origin, to: spot.coordinate) <= radiusMiles
    }
  }

  /// Best summary row for the feed card (nearest named incident, else nearest hotspot).
  /// Counts are detections within `radiusMiles` of the selected pin — not the FIRMS fetch box.
  static func summary(
    snapshot: FireSnapshot,
    origin: CLLocationCoordinate2D?,
    radiusMiles: Double = FireNotifyConfig.default.radiusMiles
  ) -> FireFeedSummary? {
    if let origin {
      let local = localDetections(in: snapshot, origin: origin, radiusMiles: radiusMiles)
      if let best = local.incidents.first {
        return FireFeedSummary(
          title: best.0.displayName,
          subtitle: String(format: "%.0f mi away", best.1),
          distanceMiles: best.1,
          hotspotCount: local.hotspots.count,
          incidentCount: local.incidents.count
        )
      }
      if let best = local.hotspots.first {
        return FireFeedSummary(
          title: "Active heat detection",
          subtitle: hotspotSubtitle(nearestMiles: best.1, localCount: local.hotspots.count),
          distanceMiles: best.1,
          hotspotCount: local.hotspots.count,
          incidentCount: local.incidents.count
        )
      }
    }

    if let named = snapshot.incidents.first(where: { $0.name != nil }) {
      return FireFeedSummary(
        title: named.displayName,
        subtitle: "Active wildfire in the region",
        distanceMiles: nil,
        hotspotCount: 0,
        incidentCount: snapshot.incidents.count
      )
    }
    if !snapshot.hotspots.isEmpty {
      return FireFeedSummary(
        title: "Active heat detections",
        subtitle: "\(snapshot.hotspots.count) satellite detections in the region",
        distanceMiles: nil,
        hotspotCount: snapshot.hotspots.count,
        incidentCount: 0
      )
    }
    return nil
  }

  static func hotspotSubtitle(nearestMiles: Double, localCount: Int) -> String {
    if localCount <= 1 {
      return String(format: "%.0f mi away", nearestMiles)
    }
    return String(format: "%.0f mi away · %d nearby", nearestMiles, localCount)
  }

  static func localDetections(
    in snapshot: FireSnapshot,
    origin: CLLocationCoordinate2D,
    radiusMiles: Double
  ) -> (hotspots: [(FireHotspot, Double)], incidents: [(FireIncident, Double)]) {
    let hotspots = snapshot.hotspots
      .map { ($0, FireProximityDedupe.distanceMiles(from: origin, to: $0.coordinate)) }
      .filter { $0.1 <= radiusMiles }
      .sorted { $0.1 < $1.1 }
    let incidents = snapshot.incidents.compactMap { incident -> (FireIncident, Double)? in
      guard let coordinate = incident.coordinate else { return nil }
      let miles = FireProximityDedupe.distanceMiles(from: origin, to: coordinate)
      guard miles <= radiusMiles else { return nil }
      return (incident, miles)
    }
    .sorted { $0.1 < $1.1 }
    return (hotspots, incidents)
  }
}

struct FireFeedSummary: Equatable, Sendable {
  var title: String
  var subtitle: String
  var distanceMiles: Double?
  var hotspotCount: Int
  var incidentCount: Int
}
