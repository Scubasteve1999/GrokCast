import WidgetKit

enum WidgetEmptyReason: Equatable {
  case none
  case noData
  case locationMismatch(locationName: String)
}

struct WeatherWidgetEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetWeatherSnapshot?
  let alertSummary: WidgetAlertSummary?
  let isStale: Bool
  let emptyReason: WidgetEmptyReason

  var hasActiveAlert: Bool {
    guard snapshot != nil else { return false }
    return alertSummary?.isActive(relativeTo: date) == true
  }
}

struct ResolvedWidgetWeather {
  let snapshot: WidgetWeatherSnapshot?
  let alertSummary: WidgetAlertSummary?
  let isStale: Bool
  let emptyReason: WidgetEmptyReason
}

struct WeatherTimelineProvider: AppIntentTimelineProvider {
  typealias Entry = WeatherWidgetEntry
  typealias Intent = WidgetLocationSelectionIntent

  private static let staleThreshold: TimeInterval = 3 * 3600
  private static let relativeLabelOffsetsMinutes = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]
  private static let dataRefreshIntervalMinutes = 45

  func placeholder(in context: Context) -> WeatherWidgetEntry {
    WeatherWidgetEntry(
      date: Date(),
      snapshot: .preview,
      alertSummary: nil,
      isStale: false,
      emptyReason: .none
    )
  }

  func snapshot(for configuration: WidgetLocationSelectionIntent, in context: Context) async
    -> WeatherWidgetEntry
  {
    let now = Date()
    let resolved = resolveSnapshot(for: configuration, at: now)
    if let snapshot = resolved.snapshot {
      return WeatherWidgetEntry(
        date: now,
        snapshot: snapshot,
        alertSummary: resolved.alertSummary,
        isStale: resolved.isStale,
        emptyReason: resolved.emptyReason
      )
    }
    return WeatherWidgetEntry(
      date: now,
      snapshot: .preview,
      alertSummary: nil,
      isStale: false,
      emptyReason: .none
    )
  }

  func timeline(for configuration: WidgetLocationSelectionIntent, in context: Context) async
    -> Timeline<WeatherWidgetEntry>
  {
    let now = Date()
    let nextDataRefresh =
      Calendar.current.date(byAdding: .minute, value: Self.dataRefreshIntervalMinutes, to: now)
      ?? now
    let entries = buildTimelineEntries(
      for: configuration,
      startingAt: now,
      through: nextDataRefresh
    )
    return Timeline(entries: entries, policy: .after(nextDataRefresh))
  }

  private func buildTimelineEntries(
    for configuration: WidgetLocationSelectionIntent,
    startingAt now: Date,
    through nextDataRefresh: Date
  ) -> [WeatherWidgetEntry] {
    var entryDates: [Date] = Self.relativeLabelOffsetsMinutes.compactMap { offset in
      Calendar.current.date(byAdding: .minute, value: offset, to: now)
    }

    let initialResolved = resolveSnapshot(for: configuration, at: now)

    if let summary = initialResolved.alertSummary {
      if let activeUntil = summary.anyActiveUntil, activeUntil > now {
        entryDates.append(activeUntil)
      }
      if let topExpires = summary.topExpires,
        topExpires > now,
        topExpires != summary.anyActiveUntil
      {
        entryDates.append(topExpires)
      }
    }

    if let snapshot = initialResolved.snapshot {
      let staleAt = snapshot.fetchedAt.addingTimeInterval(Self.staleThreshold + 1)
      if staleAt > now && staleAt <= nextDataRefresh {
        entryDates.append(staleAt)
      }
    }

    entryDates.sort()
    var seen: Set<TimeInterval> = []
    return entryDates.compactMap { date in
      let key = date.timeIntervalSince1970
      guard !seen.contains(key) else { return nil }
      seen.insert(key)
      let resolved = resolveSnapshot(for: configuration, at: date)
      return WeatherWidgetEntry(
        date: date,
        snapshot: resolved.snapshot,
        alertSummary: resolved.alertSummary,
        isStale: resolved.isStale,
        emptyReason: resolved.emptyReason
      )
    }
  }

  private func resolveSnapshot(
    for configuration: WidgetLocationSelectionIntent,
    at date: Date
  ) -> ResolvedWidgetWeather {
    WidgetDataStore.migrateLegacySnapshotIfNeeded()

    if let selected = configuration.location {
      guard let snapshot = WidgetDataStore.loadSnapshot(for: selected.id) else {
        return ResolvedWidgetWeather(
          snapshot: nil,
          alertSummary: WidgetDataStore.loadAlertSummary(for: selected.id, at: date),
          isStale: false,
          emptyReason: .locationMismatch(locationName: selected.name)
        )
      }
      let isStale = date.timeIntervalSince(snapshot.fetchedAt) > Self.staleThreshold
      return ResolvedWidgetWeather(
        snapshot: snapshot,
        alertSummary: WidgetDataStore.loadAlertSummary(for: selected.id, at: date),
        isStale: isStale,
        emptyReason: .none
      )
    }

    guard let snapshot = WidgetDataStore.loadSnapshot(for: nil) else {
      return ResolvedWidgetWeather(
        snapshot: nil,
        alertSummary: WidgetDataStore.loadAlertSummary(for: nil, at: date),
        isStale: false,
        emptyReason: .noData
      )
    }
    let isStale = date.timeIntervalSince(snapshot.fetchedAt) > Self.staleThreshold
    return ResolvedWidgetWeather(
      snapshot: snapshot,
      alertSummary: WidgetDataStore.loadAlertSummary(for: snapshot.location.id, at: date),
      isStale: isStale,
      emptyReason: .none
    )
  }
}
