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
  private var lastFetchedAt: Date?

  static let pollInterval: TimeInterval = 45
  private static let moveThresholdDegrees = 0.35

  private init() {}

  /// Map chrome only when there is lightning to attribute. Empty/error stays off the map.
  var showsQuietAttribution: Bool {
    !snapshot.strikes.isEmpty
  }

  var attributionLabel: String {
    guard let reason = snapshot.quietReason, snapshot.strikes.isEmpty else {
      return "Lightning · \(LightningSnapshot.attribution)"
    }
    switch reason {
    case .empty:
      return "No lightning · \(LightningSnapshot.attribution)"
    case .missingKey:
      return "Lightning needs Xweather keys"
    case .insufficientScope:
      return "Lightning not licensed · \(LightningSnapshot.attribution)"
    case .network:
      return "Lightning unavailable · \(LightningSnapshot.attribution)"
    }
  }

  func startPolling(around coordinate: CLLocationCoordinate2D?) {
    guard let coordinate else { return }
    pollTask?.cancel()
    pollTask = Task { [weak self] in
      guard let self else { return }
      await self.refreshNow(around: coordinate, force: true)
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(Self.pollInterval))
        guard !Task.isCancelled else { return }
        await self.refreshNow(around: coordinate, force: false)
      }
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
