import Foundation

/// App Group persistence for widget weather snapshots and saved locations.
enum WidgetDataStore {
  static let snapshotsKey = "grokcast_widget_weather_snapshots"
  static let legacySnapshotKey = "grokcast_widget_weather_snapshot"
  static let alertSummariesKey = "grokcast_widget_alert_summaries"
  static let savedLocationsKey = "grokcast_saved_locations"

  private static var groupDefaults: UserDefaults? {
    guard let defaults = WidgetAppGroup.userDefaults else {
      return nil
    }
    return defaults
  }

  // MARK: - Snapshots (keyed by location.id)

  static func saveSnapshot(_ snapshot: WidgetWeatherSnapshot) {
    guard let defaults = groupDefaults else { return }
    var snapshots = loadAllSnapshots()
    snapshots[snapshot.location.id.uuidString] = snapshot
    guard let data = try? JSONEncoder().encode(snapshots) else { return }
    defaults.set(data, forKey: snapshotsKey)
  }

  static func loadSnapshot(for locationID: UUID?) -> WidgetWeatherSnapshot? {
    let snapshots = loadAllSnapshots()
    if let locationID {
      return snapshots[locationID.uuidString]
    }
    return snapshots.values.max(by: { $0.fetchedAt < $1.fetchedAt })
  }

  static func loadAllSnapshots() -> [String: WidgetWeatherSnapshot] {
    guard let defaults = groupDefaults,
      let data = defaults.data(forKey: snapshotsKey),
      let snapshots = try? JSONDecoder().decode([String: WidgetWeatherSnapshot].self, from: data)
    else { return [:] }
    return snapshots
  }

  // MARK: - Alert Summaries (keyed by location.id)

  static func saveAlertSummary(_ summary: WidgetAlertSummary?, for locationID: UUID) {
    guard let defaults = groupDefaults else { return }
    var summaries = loadAllAlertSummaries()
    if let summary {
      summaries[locationID.uuidString] = summary
    } else {
      summaries.removeValue(forKey: locationID.uuidString)
    }
    guard let data = try? JSONEncoder().encode(summaries) else { return }
    defaults.set(data, forKey: alertSummariesKey)
  }

  static func loadAlertSummary(for locationID: UUID?, at date: Date = Date()) -> WidgetAlertSummary?
  {
    let summaries = loadAllAlertSummaries()
    let summary: WidgetAlertSummary?
    if let locationID {
      summary = summaries[locationID.uuidString]
    } else {
      summary = summaries.values.max(by: { $0.updatedAt < $1.updatedAt })
    }
    guard let summary, summary.isActive(relativeTo: date) else { return nil }
    return summary
  }

  /// Removes cached weather snapshot and alert summary for a deleted location.
  static func removeData(for locationID: UUID) {
    guard let defaults = groupDefaults else { return }

    var snapshots = loadAllSnapshots()
    snapshots.removeValue(forKey: locationID.uuidString)
    if let data = try? JSONEncoder().encode(snapshots) {
      defaults.set(data, forKey: snapshotsKey)
    }

    var summaries = loadAllAlertSummaries()
    summaries.removeValue(forKey: locationID.uuidString)
    if let data = try? JSONEncoder().encode(summaries) {
      defaults.set(data, forKey: alertSummariesKey)
    }
  }

  static func loadAllAlertSummaries() -> [String: WidgetAlertSummary] {
    guard let defaults = groupDefaults,
      let data = defaults.data(forKey: alertSummariesKey),
      let summaries = try? JSONDecoder().decode([String: WidgetAlertSummary].self, from: data)
    else { return [:] }
    return summaries
  }

  // MARK: - Saved Locations

  static func saveLocations(_ locations: [SavedLocation]) {
    guard let defaults = groupDefaults,
      let data = try? JSONEncoder().encode(locations)
    else { return }
    defaults.set(data, forKey: savedLocationsKey)
  }

  static func loadLocations() -> [SavedLocation] {
    guard let defaults = groupDefaults,
      let data = defaults.data(forKey: savedLocationsKey),
      let locations = try? JSONDecoder().decode([SavedLocation].self, from: data)
    else { return [] }
    return locations
  }

  /// App Group locations when available; otherwise standard UserDefaults (pre-widget / unsigned builds).
  static func loadLocationsPreferringAppGroup() -> [SavedLocation]? {
    let groupLocations = loadLocations()
    if !groupLocations.isEmpty { return groupLocations }

    guard
      let legacyData = UserDefaults.standard.data(forKey: savedLocationsKey),
      let legacyLocations = try? JSONDecoder().decode([SavedLocation].self, from: legacyData),
      !legacyLocations.isEmpty
    else { return nil }

    return legacyLocations
  }

  /// One-time migration from standard UserDefaults (pre-widget installs).
  static func migrateLegacySavedLocationsIfNeeded() {
    guard let groupDefaults = groupDefaults else { return }
    if groupDefaults.data(forKey: savedLocationsKey) != nil { return }
    if let legacy = UserDefaults.standard.data(forKey: savedLocationsKey) {
      groupDefaults.set(legacy, forKey: savedLocationsKey)
    }
  }

  /// One-time migration from single snapshot to location-keyed dictionary.
  static func migrateLegacySnapshotIfNeeded() {
    guard let defaults = groupDefaults else { return }
    if defaults.data(forKey: snapshotsKey) != nil { return }
    guard let data = defaults.data(forKey: legacySnapshotKey),
      let snapshot = try? JSONDecoder().decode(WidgetWeatherSnapshot.self, from: data)
    else { return }
    saveSnapshot(snapshot)
    defaults.removeObject(forKey: legacySnapshotKey)
  }
}
