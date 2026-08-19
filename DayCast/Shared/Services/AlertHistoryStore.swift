import Foundation

/// Lightweight UserDefaults persistence for NWS alert history and notification deduplication.
///
/// v1 uses `UserDefaults.standard` for full alert history (app-only). Widgets read lightweight
/// `WidgetAlertSummary` via `WidgetDataStore` in the App Group — not this store.
enum AlertHistoryStore {
  /// Legacy unscoped array. Discarded on first keyed read so another city's
  /// recents cannot paint the current Alerts tab.
  static let historyKey = "daycast_alert_history"
  static let historyByLocationKey = "daycast_alert_history_by_location"
  static let notifiedIDsKey = "daycast_notified_alert_ids"
  static let initialSyncKey = "daycast_has_completed_initial_alert_sync"
  static let retentionDays = 14

  static func loadHistory(for locationID: UUID?) -> [NWSAlert] {
    guard let locationID else { return [] }
    return loadAll()[locationID.uuidString] ?? []
  }

  static func saveHistory(_ alerts: [NWSAlert], for locationID: UUID) {
    var all = loadAll()
    let pruned = prune(alerts)
    if pruned.isEmpty {
      all.removeValue(forKey: locationID.uuidString)
    } else {
      all[locationID.uuidString] = pruned
    }
    saveAll(all)
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
          containsSelectedPoint: alert.containsSelectedPoint,
          geometryVertexCount: alert.geometryVertexCount ?? prior.geometryVertexCount,
          geometryBBoxSummary: alert.geometryBBoxSummary ?? prior.geometryBBoxSummary,
          polygonCoordinates: alert.polygonCoordinates ?? prior.polygonCoordinates,
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
          containsSelectedPoint: alert.containsSelectedPoint,
          geometryVertexCount: alert.geometryVertexCount,
          geometryBBoxSummary: alert.geometryBBoxSummary,
          polygonCoordinates: alert.polygonCoordinates,
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
    let historyIDs = Set(loadAll().values.flatMap { $0.map(\.id) })
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

  private static func loadAll() -> [String: [NWSAlert]] {
    if let data = UserDefaults.standard.data(forKey: historyByLocationKey),
      let decoded = try? JSONDecoder().decode([String: [NWSAlert]].self, from: data)
    {
      return decoded.mapValues { prune($0) }
    }
    // Old builds stored one mixed array. Drop it rather than attach Olive Branch
    // heat warnings to Seattle.
    UserDefaults.standard.removeObject(forKey: historyKey)
    return [:]
  }

  private static func saveAll(_ byLocation: [String: [NWSAlert]]) {
    guard let data = try? JSONEncoder().encode(byLocation) else { return }
    UserDefaults.standard.set(data, forKey: historyByLocationKey)
  }
}
