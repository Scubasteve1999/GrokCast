import CoreLocation
import Foundation
import UserNotifications

/// Local notifications for new nearby wildfire activity (FIRMS / NIFC).
/// Red Flag / Fire Weather Watch stay on `AlertNotificationService` (NWS severe path).
@MainActor
enum FireNotificationService {
  static let categoryIdentifier = "DAYCAST_FIRE_ALERT"
  static let historyKey = "daycast_fire_notify_history"

  private struct PersistedHistory: Codable {
    var hotspotCells: [String: Date]
    var incidentIDs: [String]
  }

  static func loadHistory() -> FireNotifyHistory {
    guard let data = UserDefaults.standard.data(forKey: historyKey),
      let decoded = try? JSONDecoder().decode(PersistedHistory.self, from: data)
    else { return .empty }
    return FireNotifyHistory(
      hotspotCells: decoded.hotspotCells,
      incidentIDs: Set(decoded.incidentIDs)
    )
  }

  static func saveHistory(_ history: FireNotifyHistory) {
    let pruned = FireProximityDedupe.pruned(history)
    let payload = PersistedHistory(
      hotspotCells: pruned.hotspotCells,
      incidentIDs: Array(pruned.incidentIDs)
    )
    guard let data = try? JSONEncoder().encode(payload) else { return }
    UserDefaults.standard.set(data, forKey: historyKey)
  }

  static func notifyIfNeeded(
    snapshot: FireSnapshot,
    origin: CLLocationCoordinate2D,
    enabled: Bool,
    radiusMiles: Double,
    taskStart: CFAbsoluteTime? = nil
  ) async {
    guard enabled else { return }

    let settings = await UNUserNotificationCenter.current().notificationSettings()
    guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    else { return }

    let config = FireNotifyConfig(radiusMiles: radiusMiles)
    var history = FireProximityDedupe.pruned(loadHistory(), config: config)
    var posted = 0

    // Prefer named incidents; then a single representative hotspot.
    let candidates: [FireNotifyCandidate] =
      snapshot.incidents.map {
        .incident(
          id: $0.id,
          name: $0.name,
          latitude: $0.latitude,
          longitude: $0.longitude
        )
      }
      + snapshot.hotspots.prefix(40).map {
        .hotspot(latitude: $0.latitude, longitude: $0.longitude)
      }

    for candidate in candidates {
      if let taskStart, CFAbsoluteTimeGetCurrent() - taskStart >= 20 { break }

      let decision = FireProximityDedupe.shouldNotify(
        candidate: candidate,
        origin: origin,
        history: history,
        config: config
      )
      guard case .notify = decision else { continue }

      let postedOK = await post(candidate: candidate, origin: origin)
      guard postedOK else { continue }

      history = FireProximityDedupe.applying(decision, to: history)
      posted += 1
      Analytics.track(
        .fireProximityNotify,
        parameters: [
          "kind": {
            switch candidate {
            case .hotspot: return "hotspot"
            case .incident: return "incident"
            }
          }()
        ]
      )
      // Cap per wake so we don't spam when many cells light up at once.
      if posted >= 3 { break }
    }

    if posted > 0 {
      saveHistory(history)
    }
  }

  private static func post(
    candidate: FireNotifyCandidate,
    origin: CLLocationCoordinate2D
  ) async -> Bool {
    let title: String
    let body: String
    let identifier: String

    switch candidate {
    case .hotspot(let latitude, let longitude):
      let miles = FireProximityDedupe.distanceMiles(
        from: origin,
        to: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
      )
      title = "Fire activity nearby"
      body = String(
        format: "Satellite heat detection about %.0f miles from your location.",
        miles
      )
      identifier =
        "fire.hotspot."
        + FireProximityDedupe.gridCell(latitude: latitude, longitude: longitude)

    case .incident(let id, let name, let latitude, let longitude):
      let display = (name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
        $0.isEmpty ? nil : $0
      } ?? "A wildfire"
      if let latitude, let longitude {
        let miles = FireProximityDedupe.distanceMiles(
          from: origin,
          to: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        )
        title = "Wildfire nearby"
        body = String(format: "%@ is about %.0f miles away.", display, miles)
      } else {
        title = "Wildfire in your area"
        body = "\(display) is active in the region."
      }
      identifier = "fire.incident.\(id)"
    }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.interruptionLevel = .timeSensitive
    content.categoryIdentifier = categoryIdentifier
    content.threadIdentifier = "daycast-fire-alerts"
    content.userInfo = ["deepLink": DayCastDeepLinks.radarURL.absoluteString]

    let request = UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: nil
    )

    do {
      try await UNUserNotificationCenter.current().add(request)
      return true
    } catch {
      return false
    }
  }
}
