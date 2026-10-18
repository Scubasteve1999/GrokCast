import CoreLocation
import Foundation
import Observation

/// Independent lightning cache for Live Radar. Never blocks weather / precip.
@MainActor
@Observable
final class LightningStore {
  static let shared = LightningStore()

  private(set) var snapshot = LightningSnapshot()
  private(set) var isLoading = false
  private(set) var lastCoordinate: CLLocationCoordinate2D?

  private var pollTask: Task<Void, Never>?
  /// Held so a second Radar open or city change before the answer cannot send another request.
  private var availabilityCheck: Task<Void, Never>?
  private var lastFetchedAt: Date?

  static let pollInterval: TimeInterval = 45
  /// How long a refused key stays trusted before Radar asks Xweather again.
  nonisolated static let unavailableRecheckInterval: TimeInterval = 15 * 60
  private static let moveThresholdDegrees = 0.35

  private init() {}

  /// Map chrome when there is lightning to attribute, or when the feed failed (an empty
  /// overlay would otherwise read as "no lightning"). A genuine empty result and a missing
  /// or refused key stay off the map: those hide the layer controls instead.
  var showsQuietAttribution: Bool { Self.showsQuietAttribution(for: snapshot) }

  /// Xweather has no key or refused it (expired plan, lost scope, exhausted quota). Every
  /// lightning control hides rather than offering a layer that cannot load, and Radar
  /// re-checks after `unavailableRecheckInterval`, so a reset quota brings it back. The
  /// user's saved toggle is left alone for when keys work again.
  var isLayerUnavailable: Bool { Self.isLayerUnavailable(for: snapshot) }

  var attributionLabel: String { Self.attributionLabel(for: snapshot) }

  nonisolated static func showsQuietAttribution(for snapshot: LightningSnapshot) -> Bool {
    if !snapshot.strikes.isEmpty { return true }
    switch snapshot.quietReason {
    case .network: return true
    case .empty, .missingKey, .insufficientScope, nil: return false
    }
  }

  /// Never checked yet, or hidden for a refused key long enough that it may work again
  /// (daily quota reset, renewed plan).
  nonisolated static func needsAvailabilityCheck(
    for snapshot: LightningSnapshot, now: Date = Date()
  ) -> Bool {
    guard let lastUpdated = snapshot.lastUpdated else { return true }
    return isLayerUnavailable(for: snapshot)
      && now.timeIntervalSince(lastUpdated) >= unavailableRecheckInterval
  }

  nonisolated static func isLayerUnavailable(for snapshot: LightningSnapshot) -> Bool {
    guard snapshot.strikes.isEmpty else { return false }
    switch snapshot.quietReason {
    case .missingKey, .insufficientScope: return true
    case .network, .empty, nil: return false
    }
  }

  nonisolated static func attributionLabel(for snapshot: LightningSnapshot) -> String {
    guard let reason = snapshot.quietReason, snapshot.strikes.isEmpty else {
      return "Lightning · \(LightningSnapshot.attribution)"
    }
    switch reason {
    case .empty:
      return "No lightning · \(LightningSnapshot.attribution)"
    case .missingKey:
      return "Lightning needs Xweather keys"
    case .insufficientScope, .network:
      // A 403 can be a license gap or an exhausted quota; users get one honest line.
      return RadarChromeCopy.lightningTemporarilyUnavailable
    }
  }

  func startPolling(around coordinate: CLLocationCoordinate2D?) {
    guard let coordinate else { return }
    pollTask?.cancel()
    pollTask = Task { [weak self] in
      guard let self else { return }
      await self.refreshNow(around: coordinate, force: true)
      // A refused key will not start working in 45 seconds; stop instead of re-asking.
      while !Task.isCancelled, !self.isLayerUnavailable {
        try? await Task.sleep(for: .seconds(Self.pollInterval))
        guard !Task.isCancelled else { return }
        await self.refreshNow(around: coordinate, force: false)
      }
    }
  }

  /// Runs when Radar opens or returns to the foreground without polling: once per launch
  /// so the controls learn a dead key before the user taps a button that cannot work, then
  /// again every `unavailableRecheckInterval` while hidden. A missing key costs no request.
  func checkAvailabilityIfNeeded(around coordinate: CLLocationCoordinate2D?) {
    guard let coordinate, Self.needsAvailabilityCheck(for: snapshot), !isLoading,
      pollTask == nil, availabilityCheck == nil
    else { return }
    availabilityCheck = Task { [weak self] in
      await self?.refreshNow(around: coordinate, force: true)
      self?.availabilityCheck = nil
    }
  }

  func stopPolling() {
    pollTask?.cancel()
    pollTask = nil
  }

  func refresh(around coordinate: CLLocationCoordinate2D?, force: Bool = false) {
    guard let coordinate else { return }
    Task { await refreshNow(around: coordinate, force: force) }
  }

  func refreshNow(around coordinate: CLLocationCoordinate2D, force: Bool = false) async {
    let moved =
      lastCoordinate.map {
        abs($0.latitude - coordinate.latitude) > Self.moveThresholdDegrees
          || abs($0.longitude - coordinate.longitude) > Self.moveThresholdDegrees
      } ?? true

    let stale =
      force || moved
      || lastFetchedAt.map { Date().timeIntervalSince($0) >= Self.pollInterval } ?? true
    guard stale else {
      snapshot.strikes = LightningStrikeWindow.prune(snapshot.strikes)
      return
    }

    isLoading = true
    defer { isLoading = false }
    lastCoordinate = coordinate

    do {
      let incoming = try await LightningService.fetchStrikes(around: coordinate)
      let now = Date()
      let merged = LightningStrikeWindow.merging(
        existing: moved ? [] : snapshot.strikes,
        incoming: incoming,
        now: now
      )
      snapshot.strikes = merged
      snapshot.lastUpdated = now
      snapshot.quietReason = merged.isEmpty ? .empty : nil
      lastFetchedAt = now
    } catch let error as LightningServiceError {
      snapshot.quietReason = quietReason(from: error)
      if case .missingKey = error { snapshot.strikes = [] }
      if case .insufficientScope = error { snapshot.strikes = [] }
      snapshot.strikes = LightningStrikeWindow.prune(snapshot.strikes)
      snapshot.lastUpdated = Date()
      lastFetchedAt = Date()
    } catch {
      snapshot.quietReason = .network
      snapshot.strikes = LightningStrikeWindow.prune(snapshot.strikes)
      snapshot.lastUpdated = Date()
      lastFetchedAt = Date()
    }
  }

  private func quietReason(from error: LightningServiceError) -> LightningFetchQuietReason {
    switch error {
    case .missingKey: return .missingKey
    case .insufficientScope: return .insufficientScope
    case .badResponse: return .network
    }
  }
}
