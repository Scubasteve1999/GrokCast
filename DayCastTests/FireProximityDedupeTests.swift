import CoreLocation
import XCTest

@testable import DayCast

final class FireProximityDedupeTests: XCTestCase {
  private let origin = CLLocationCoordinate2D(latitude: 34.96, longitude: -89.83)
  private let now = Date(timeIntervalSince1970: 1_753_920_000)

  func testGridCellStableWithinCellAndChangesAcrossBoundary() {
    let a = FireProximityDedupe.gridCell(latitude: 34.960, longitude: -89.830, degrees: 0.015)
    let b = FireProximityDedupe.gridCell(latitude: 34.961, longitude: -89.829, degrees: 0.015)
    let c = FireProximityDedupe.gridCell(latitude: 34.980, longitude: -89.830, degrees: 0.015)
    XCTAssertEqual(a, b)
    XCTAssertNotEqual(a, c)
  }

  func testHotspotOutsideRadiusSkipped() {
    let candidate = FireNotifyCandidate.hotspot(latitude: 36.5, longitude: -89.83)  // ~100+ mi N
    let decision = FireProximityDedupe.shouldNotify(
      candidate: candidate,
      origin: origin,
      history: .empty,
      now: now,
      config: FireNotifyConfig(radiusMiles: 25)
    )
    XCTAssertEqual(decision, .skip(.outsideRadius))
  }

  func testHotspotInsideRadiusNotifiesOnceThenCooldown() {
    let candidate = FireNotifyCandidate.hotspot(latitude: 34.97, longitude: -89.84)
    let first = FireProximityDedupe.shouldNotify(
      candidate: candidate,
      origin: origin,
      history: .empty,
      now: now,
      config: .default
    )
    guard case .notify(let key) = first else {
      return XCTFail("expected notify, got \(first)")
    }
    XCTAssertTrue(key.hasPrefix("hotspot:"))

    let history = FireProximityDedupe.applying(first, to: .empty, now: now)
    let second = FireProximityDedupe.shouldNotify(
      candidate: candidate,
      origin: origin,
      history: history,
      now: now.addingTimeInterval(3600),
      config: .default
    )
    XCTAssertEqual(second, .skip(.cooldown))

    let afterWindow = FireProximityDedupe.shouldNotify(
      candidate: candidate,
      origin: origin,
      history: history,
      now: now.addingTimeInterval(13 * 3600),
      config: .default
    )
    XCTAssertEqual(afterWindow, first)
  }

  func testNearbyHotspotsShareCellDedupe() {
    let a = FireNotifyCandidate.hotspot(latitude: 34.9601, longitude: -89.8301)
    let b = FireNotifyCandidate.hotspot(latitude: 34.9608, longitude: -89.8295)
    let first = FireProximityDedupe.shouldNotify(
      candidate: a, origin: origin, history: .empty, now: now)
    let history = FireProximityDedupe.applying(first, to: .empty, now: now)
    let second = FireProximityDedupe.shouldNotify(
      candidate: b, origin: origin, history: history, now: now.addingTimeInterval(60))
    XCTAssertEqual(second, .skip(.cooldown))
  }

  func testIncidentDedupeByIDIgnoresPerimeterGrowth() {
    let candidate = FireNotifyCandidate.incident(
      id: "IRWIN-1",
      name: "Creek",
      latitude: 34.97,
      longitude: -89.84
    )
    let first = FireProximityDedupe.shouldNotify(
      candidate: candidate, origin: origin, history: .empty, now: now)
    XCTAssertEqual(first, .notify(dedupeKey: "incident:IRWIN-1"))

    var history = FireProximityDedupe.applying(first, to: .empty, now: now)
    // Same id, "larger" fire (coords moved slightly) — still suppressed.
    let grown = FireNotifyCandidate.incident(
      id: "IRWIN-1",
      name: "Creek",
      latitude: 34.98,
      longitude: -89.85
    )
    let second = FireProximityDedupe.shouldNotify(
      candidate: grown, origin: origin, history: history, now: now.addingTimeInterval(86400))
    XCTAssertEqual(second, .skip(.alreadyNotified))

    history = FireProximityDedupe.applying(second, to: history, now: now)
    XCTAssertEqual(history.incidentIDs, ["IRWIN-1"])
  }

  func testIncidentWithoutCoordinatesAllowedByID() {
    let candidate = FireNotifyCandidate.incident(
      id: "IRWIN-2", name: "Palisades", latitude: nil, longitude: nil)
    let decision = FireProximityDedupe.shouldNotify(
      candidate: candidate, origin: origin, history: .empty, now: now)
    XCTAssertEqual(decision, .notify(dedupeKey: "incident:IRWIN-2"))
  }

  func testFeedVisibilityFireWeatherAlertWithoutHotspots() {
    let live = Date()
    let alert = NWSAlert(
      id: "a1",
      event: "Red Flag Warning",
      severity: "Severe",
      headline: "Red Flag",
      description: nil,
      instruction: nil,
      sent: live,
      expires: live.addingTimeInterval(3600),
      areaDesc: nil,
      latitude: nil,
      longitude: nil,
      containsSelectedPoint: true,
      geometryVertexCount: nil,
      geometryBBoxSummary: nil,
      firstSeen: live
    )
    XCTAssertTrue(
      FireFeedVisibility.shouldShowCard(
        snapshot: FireSnapshot(),
        origin: origin,
        alerts: [alert]
      )
    )
  }

  func testFeedVisibilityNearHotspot() {
    var snap = FireSnapshot()
    snap.hotspots = [
      FireHotspot(
        id: "h1",
        latitude: 34.97,
        longitude: -89.84,
        brightness: nil,
        frp: 10,
        confidence: "nominal",
        acqDate: nil,
        acqTime: nil,
        satellite: nil,
        detectedAt: now
      )
    ]
    XCTAssertTrue(
      FireFeedVisibility.shouldShowCard(snapshot: snap, origin: origin, alerts: [])
    )
    XCTAssertFalse(
      FireFeedVisibility.shouldShowCard(snapshot: snap, origin: nil, alerts: [])
    )
  }

  func testFeedSummaryNearbyCountIsLocalRadiusNotTheFetchBox() {
    var snap = FireSnapshot()
    snap.hotspots = [
      hotspot(id: "near", latitude: 34.97, longitude: -89.84),  // ~1 mi
      hotspot(id: "also-near", latitude: 34.98, longitude: -89.85),
      hotspot(id: "box", latitude: 36.20, longitude: -89.83),  // ~85 mi, inside a 150 km FIRMS box
    ]
    let summary = FireFeedVisibility.summary(snapshot: snap, origin: origin, radiusMiles: 25)
    XCTAssertEqual(summary?.hotspotCount, 2)
    XCTAssertEqual(summary?.subtitle, FireFeedVisibility.hotspotSubtitle(nearestMiles: 1, localCount: 2))
    XCTAssertFalse(summary?.subtitle.contains("196") ?? false)
    XCTAssertTrue(summary?.subtitle.contains("2 nearby") ?? false)
  }

  func testFeedSummarySingleLocalHotspotDoesNotInventABoxCount() {
    var snap = FireSnapshot()
    snap.hotspots = [
      hotspot(id: "near", latitude: 34.97, longitude: -89.84),
      hotspot(id: "box", latitude: 36.20, longitude: -89.83),
    ]
    let summary = FireFeedVisibility.summary(snapshot: snap, origin: origin, radiusMiles: 25)
    XCTAssertEqual(summary?.hotspotCount, 1)
    XCTAssertEqual(summary?.subtitle.contains("nearby"), false)
    XCTAssertTrue(summary?.subtitle.contains("mi away") ?? false)
  }

  func testHotspotSubtitleMatchesLocalCount() {
    XCTAssertEqual(FireFeedVisibility.hotspotSubtitle(nearestMiles: 2, localCount: 1), "2 mi away")
    XCTAssertEqual(
      FireFeedVisibility.hotspotSubtitle(nearestMiles: 2, localCount: 196),
      "2 mi away · 196 nearby"
    )
  }

  func testDetailListIsTheSameLocalRadiusAsTheCard() {
    var snap = FireSnapshot()
    snap.hotspots = [
      hotspot(id: "3mi", latitude: 34.99, longitude: -89.83),
      hotspot(id: "7mi", latitude: 35.06, longitude: -89.83),
      hotspot(id: "26mi", latitude: 35.34, longitude: -89.83),
      hotspot(id: "42mi", latitude: 35.57, longitude: -89.83),
      hotspot(id: "45mi", latitude: 35.61, longitude: -89.83),
    ]
    let local = FireFeedVisibility.localDetections(in: snap, origin: origin, radiusMiles: 25)
    let summary = FireFeedVisibility.summary(snapshot: snap, origin: origin, radiusMiles: 25)
    XCTAssertEqual(local.hotspots.count, 2)
    XCTAssertEqual(summary?.hotspotCount, local.hotspots.count)
    XCTAssertEqual(
      FireFeedVisibility.nearbyDetectionsHeader(count: local.hotspots.count),
      "2 detections nearby"
    )
    XCTAssertTrue(local.hotspots.allSatisfy { $0.1 <= 25 })
    XCTAssertEqual(Set(local.hotspots.map(\.0.id)), ["3mi", "7mi"])
  }

  func testNearbyDetectionsHeaderMatchesListCount() {
    XCTAssertEqual(FireFeedVisibility.nearbyDetectionsHeader(count: 1), "1 detection nearby")
    XCTAssertEqual(FireFeedVisibility.nearbyDetectionsHeader(count: 5), "5 detections nearby")
    XCTAssertEqual(FireFeedVisibility.nearbyIncidentsHeader(count: 1), "1 incident nearby")
    XCTAssertEqual(FireFeedVisibility.nearbyIncidentsHeader(count: 3), "3 incidents nearby")
  }

  private func hotspot(id: String, latitude: Double, longitude: Double) -> FireHotspot {
    FireHotspot(
      id: id,
      latitude: latitude,
      longitude: longitude,
      brightness: nil,
      frp: 10,
      confidence: "nominal",
      acqDate: nil,
      acqTime: nil,
      satellite: nil,
      detectedAt: now
    )
  }

  func testDistanceRoughlyCorrectForKnownSpan() {
    // ~69 miles per degree latitude
    let north = CLLocationCoordinate2D(latitude: 35.96, longitude: -89.83)
    let miles = FireProximityDedupe.distanceMiles(from: origin, to: north)
    XCTAssertEqual(miles, 69, accuracy: 2)
  }
}
