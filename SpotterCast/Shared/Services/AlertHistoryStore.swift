import Foundation

/// Lightweight UserDefaults persistence for NWS alert history and notification deduplication.
///
/// v1 uses `UserDefaults.standard` for full alert history (app-only). Widgets read lightweight
/// `WidgetAlertSummary` via `WidgetDataStore` in the App Group — not this store.
enum AlertHistoryStore {
  static let historyKey = "grokcast_alert_history"
  static let notifiedIDsKey = "grokcast_notified_alert_ids"
  static let initialSyncKey = "grokcast_has_completed_initial_alert_sync"
  static let retentionDays = 14

  static func loadHistory() -> [NWSAlert] {
    guard let data = UserDefaults.standard.data(forKey: historyKey),
      let alerts = try? JSONDecoder().decode([NWSAlert].self, from: data)
    else { return [] }
    return prune(alerts)
  }

  static func saveHistory(_ alerts: [NWSAlert]) {
    let pruned = prune(alerts)
    guard let data = try? JSONEncoder().encode(pruned) else { return }
    UserDefaults.standard.set(data, forKey: historyKey)
  }

  /// Merges freshly fetched alerts into persisted history (preserves firstSeen for existing IDs).
  static func merge(fetched: [NWSAlert], into existing: [NWSAlert]) -> [NWSAlert] {
    var byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
    let now = Date()

    for alert in fetched {
      if let prior = byID[alert.id] {
        byID[alert.id] = NWSAlert(
          id: alert.id,
          event: alert.event,
          severity: alert.severity,
          headline: alert.headline,
          description: alert.description,
          instruction: alert.instruction,
          sent: alert.sent ?? prior.sent,
          expires: alert.expires ?? prior.expires,
          areaDesc: alert.areaDesc,
          latitude: alert.latitude ?? prior.latitude,
          longitude: alert.longitude ?? prior.longitude,
          firstSeen: prior.firstSeen
        )
      } else {
        byID[alert.id] = NWSAlert(
          id: alert.id,
          event: alert.event,
          severity: alert.severity,
          headline: alert.headline,
          description: alert.description,
          instruction: alert.instruction,
          sent: alert.sent,
          expires: alert.expires,
          areaDesc: alert.areaDesc,
          latitude: alert.latitude,
          longitude: alert.longitude,
          firstSeen: now
        )
      }
    }

    return prune(Array(byID.values))
  }

  static func prune(_ alerts: [NWSAlert]) -> [NWSAlert] {
    let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
    return alerts.filter { $0.sortDate >= cutoff }
  }

  static func loadNotifiedIDs() -> Set<String> {
    let ids = UserDefaults.standard.stringArray(forKey: notifiedIDsKey) ?? []
    return Set(ids)
  }

  static func markNotified(ids: [String]) {
    guard !ids.isEmpty else { return }
    var current = loadNotifiedIDs()
    current.formUnion(ids)
    // Keep notified set bounded (same retention window as history).
    let historyIDs = Set(loadHistory().map(\.id))
    let pruned = current.intersection(historyIDs).union(ids)
    UserDefaults.standard.set(Array(pruned), forKey: notifiedIDsKey)
  }

  /// True after the first successful alert sync has seeded notified IDs (prevents launch burst).
  static func hasCompletedInitialAlertSync() -> Bool {
    UserDefaults.standard.bool(forKey: initialSyncKey)
  }

  static func markInitialAlertSyncComplete() {
    UserDefaults.standard.set(true, forKey: initialSyncKey)
  }
}
