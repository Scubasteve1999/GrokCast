import CoreLocation
import Foundation
import Observation

/// Independent fire data cache. Never blocks weather / radar refresh paths.
@MainActor
@Observable
final class FireStore {
  static let shared = FireStore()

  private(set) var snapshot = FireSnapshot()
  private(set) var isLoading = false
  private(set) var lastCoordinate: CLLocationCoordinate2D?

  private var firmsFetchedAt: Date?
  private var nifcFetchedAt: Date?
  private var refreshTask: Task<Void, Never>?

  private static let firmsTTL: TimeInterval = 3 * 60 * 60
  private static let nifcTTL: TimeInterval = 15 * 60
  private static let moveThresholdDegrees = 0.35

  private init() {}

  var lastUpdatedLabel: String? {
    guard let date = snapshot.lastUpdated else { return nil }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return "Updated \(formatter.localizedString(for: date, relativeTo: Date()))"
  }

  func refresh(around coordinate: CLLocationCoordinate2D?, force: Bool = false) {
    guard let coordinate else { return }
    refreshTask?.cancel()
    refreshTask = Task { await refreshNow(around: coordinate, force: force) }
  }

  func refreshNow(around coordinate: CLLocationCoordinate2D, force: Bool = false) async {
    let moved =
      lastCoordinate.map {
        abs($0.latitude - coordinate.latitude) > Self.moveThresholdDegrees
          || abs($0.longitude - coordinate.longitude) > Self.moveThresholdDegrees
      } ?? true

    let firmsStale =
      force || moved || firmsFetchedAt.map { Date().timeIntervalSince($0) > Self.firmsTTL } ?? true
    let nifcStale =
      force || moved || nifcFetchedAt.map { Date().timeIntervalSince($0) > Self.nifcTTL } ?? true

    guard firmsStale || nifcStale else { return }

    isLoading = true
    defer { isLoading = false }
    lastCoordinate = coordinate

    async let firmsResult: Result<[FireHotspot], Error> = {
      do {
        return .success(
          try await FIRMSService.fetchHotspots(
            around: coordinate,
            mapKey: DeveloperAPIKey.firmsMapKey
          )
        )
      } catch {
        return .failure(error)
      }
    }()

    async let incidentsResult: Result<[FireIncident], Error> = {
      do {
        return .success(try await NIFCFireService.fetchIncidents(around: coordinate))
      } catch {
        return .failure(error)
      }
    }()

    async let perimetersResult: Result<[FirePerimeter], Error> = {
      do {
        return .success(try await NIFCFireService.fetchPerimeters(around: coordinate))
      } catch {
        return .failure(error)
      }
    }()

    if firmsStale {
      switch await firmsResult {
      case .success(let hotspots):
        snapshot.hotspots = hotspots
        snapshot.firmsQuietReason = hotspots.isEmpty ? .empty : nil
        firmsFetchedAt = Date()
      case .failure(let error):
        snapshot.firmsQuietReason = quietReason(from: error)
        // Keep prior hotspots on transient network errors.
        if case .missingKey = snapshot.firmsQuietReason {
          snapshot.hotspots = []
        }
        if case .quotaExceeded = snapshot.firmsQuietReason {
          // Layer quiet — do not thrash the key.
          firmsFetchedAt = Date()
        }
      }
    }

    if nifcStale {
      let incidents = await incidentsResult
      let perimeters = await perimetersResult
      var nifcHadSuccess = false

      switch incidents {
      case .success(let list):
        snapshot.incidents = list
        nifcHadSuccess = true
      case .failure:
        snapshot.nifcQuietReason = .network
      }

      switch perimeters {
      case .success(let list):
        snapshot.perimeters = list
        nifcHadSuccess = true
      case .failure:
        if snapshot.nifcQuietReason == nil { snapshot.nifcQuietReason = .network }
      }

      if nifcHadSuccess {
        if snapshot.incidents.isEmpty && snapshot.perimeters.isEmpty {
          snapshot.nifcQuietReason = .empty
        } else {
          snapshot.nifcQuietReason = nil
        }
        nifcFetchedAt = Date()
      }
    }

    snapshot.lastUpdated = Date()
  }

  private func quietReason(from error: Error) -> FireFetchQuietReason {
    if let firms = error as? FIRMSServiceError {
      switch firms {
      case .missingKey: return .missingKey
      case .quotaExceeded: return .quotaExceeded
      case .badResponse: return .network
      }
    }
    return .network
  }
}
