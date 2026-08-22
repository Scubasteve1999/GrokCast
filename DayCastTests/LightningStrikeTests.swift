import CoreLocation
import XCTest

@testable import DayCast

final class LightningStrikeTests: XCTestCase {
  func testParsesCloudToGroundStrikes() throws {
    let now = Date(timeIntervalSince1970: 1_787_437_200)
    let strikes = try LightningService.parse(data: Self.sampleJSON, now: now)
    XCTAssertEqual(strikes.count, 2)
    XCTAssertEqual(strikes[0].id, "abc123")
    XCTAssertEqual(strikes[0].latitude, 34.9618, accuracy: 0.0001)
    XCTAssertEqual(strikes[0].longitude, -89.8295, accuracy: 0.0001)
    XCTAssertEqual(strikes[0].pulseType, "cg")
    XCTAssertEqual(strikes[0].peakAmps, -7000)
    XCTAssertEqual(strikes[0].time.timeIntervalSince1970, 1_787_437_159, accuracy: 0.001)
    XCTAssertEqual(strikes[1].id, "def456")
    XCTAssertEqual(strikes[1].time.timeIntervalSince1970, 1_787_437_100.5, accuracy: 0.001)
  }

  func testDropsIntracloudPulses() throws {
    let json = """
      {"success":true,"response":[
        {"id":"cg1","loc":{"lat":35.0,"long":-90.0},"ob":{"timestamp":1787437159,"pulse":{"type":"cg"}}},
        {"id":"ic1","loc":{"lat":35.1,"long":-90.1},"ob":{"timestamp":1787437160,"pulse":{"type":"ic"}}}
      ]}
      """.data(using: .utf8)!
    let strikes = try LightningService.parse(data: json)
    XCTAssertEqual(strikes.map(\.id), ["cg1"])
  }

  func testFallbackIDWhenMissing() throws {
    let json = """
      {"success":true,"response":[
        {"loc":{"lat":34.9618,"long":-89.8295},"ob":{"timestamp":1787437159,"pulse":{"type":"cg"}}}
      ]}
      """.data(using: .utf8)!
    let strikes = try LightningService.parse(data: json)
    XCTAssertEqual(strikes.count, 1)
    XCTAssertTrue(strikes[0].id.contains("34.9618"))
    XCTAssertTrue(strikes[0].id.contains("-89.8295"))
  }

  func testPrunesOlderThanMaxAge() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let keep = LightningStrike(
      id: "new", latitude: 1, longitude: 2, time: now.addingTimeInterval(-5 * 60),
      pulseType: "cg", peakAmps: nil)
    let drop = LightningStrike(
      id: "old", latitude: 1, longitude: 2, time: now.addingTimeInterval(-25 * 60),
      pulseType: "cg", peakAmps: nil)
    let pruned = LightningStrikeWindow.prune([keep, drop], now: now)
    XCTAssertEqual(pruned.map(\.id), ["new"])
  }

  func testMergeDedupesByIDAndKeepsNewestFirst() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let older = LightningStrike(
      id: "a", latitude: 1, longitude: 2, time: now.addingTimeInterval(-8 * 60),
      pulseType: "cg", peakAmps: nil)
    let incomingNewer = LightningStrike(
      id: "a", latitude: 1.01, longitude: 2.01, time: now.addingTimeInterval(-1 * 60),
      pulseType: "cg", peakAmps: -100)
    let other = LightningStrike(
      id: "b", latitude: 3, longitude: 4, time: now.addingTimeInterval(-3 * 60),
      pulseType: "cg", peakAmps: nil)
    let merged = LightningStrikeWindow.merging(
      existing: [older], incoming: [incomingNewer, other], now: now)
    XCTAssertEqual(merged.map(\.id), ["a", "b"])
    XCTAssertEqual(merged[0].latitude, 1.01, accuracy: 0.0001)
    XCTAssertEqual(merged[0].peakAmps, -100)
  }

  func testMergeDropsStaleExistingWhenIncomingIsFresh() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let stale = LightningStrike(
      id: "old", latitude: 1, longitude: 2, time: now.addingTimeInterval(-30 * 60),
      pulseType: "cg", peakAmps: nil)
    let fresh = LightningStrike(
      id: "new", latitude: 3, longitude: 4, time: now.addingTimeInterval(-30),
      pulseType: "cg", peakAmps: nil)
    let merged = LightningStrikeWindow.merging(
      existing: [stale], incoming: [fresh], now: now)
    XCTAssertEqual(merged.map(\.id), ["new"])
  }

  func testInsufficientScopeIsAnError() {
    let json = """
      {"success":false,"error":{"code":"insufficient_scope","description":"upgrade"},"response":[]}
      """.data(using: .utf8)!
    XCTAssertThrowsError(try LightningService.parse(data: json)) { error in
      XCTAssertEqual(error as? LightningServiceError, .insufficientScope)
    }
  }

  func testQueryURLUsesClosestCGAndHundredKM() {
    let url = LightningService.makeURL(
      center: CLLocationCoordinate2D(latitude: 34.9618, longitude: -89.8295),
      clientID: "id",
      clientSecret: "secret"
    )
    XCTAssertNotNil(url)
    let text = url!.absoluteString
    XCTAssertTrue(text.contains("/lightning/closest"))
    XCTAssertTrue(text.contains("radius=100km"))
    XCTAssertTrue(text.contains("filter=cg"))
    XCTAssertTrue(text.contains("limit=1000"))
    XCTAssertTrue(text.contains("34.9618,-89.8295"))
  }

  func testAgeMinutes() {
    let now = Date()
    let strike = LightningStrike(
      id: "t", latitude: 0, longitude: 0, time: now.addingTimeInterval(-150),
      pulseType: "cg", peakAmps: nil)
    XCTAssertEqual(strike.ageMinutes(now: now), 2.5, accuracy: 0.05)
  }

  func testBoltLayerReplacesCircleDots() {
    XCTAssertEqual(LightningRadarOverlay.layerID, "lightning-strikes-bolts")
    XCTAssertEqual(LightningRadarOverlay.legacyCircleLayerID, "lightning-strikes-layer")
    XCTAssertNotEqual(LightningRadarOverlay.layerID, LightningRadarOverlay.legacyCircleLayerID)
    XCTAssertEqual(LightningRadarOverlay.iconImageID, "daycast-lightning-bolt")
    let bolt = LightningRadarOverlay.makeBoltImage()
    XCTAssertGreaterThanOrEqual(bolt.size.width, 24)
    XCTAssertGreaterThanOrEqual(bolt.size.height, 24)
  }

  func testBoltAgeColorsAreIceWhiteNotAmber() {
    for color in [
      LightningRadarOverlay.boltColorNewest,
      LightningRadarOverlay.boltColorMid,
      LightningRadarOverlay.boltColorOldest,
    ] {
      var r: CGFloat = 0
      var g: CGFloat = 0
      var b: CGFloat = 0
      var a: CGFloat = 0
      XCTAssertTrue(color.getRed(&r, green: &g, blue: &b, alpha: &a))
      XCTAssertGreaterThanOrEqual(b, g, "ice/cool: blue must not sit under green")
      XCTAssertGreaterThanOrEqual(g, r, "ice/cool: green must not sit under red")
      XCTAssertLessThan(r - b, 0.02, "no yellow/amber (red must not lead blue)")
      XCTAssertGreaterThan(a, 0.99)
    }

    var nr: CGFloat = 0, ng: CGFloat = 0, nb: CGFloat = 0, na: CGFloat = 0
    XCTAssertTrue(
      LightningRadarOverlay.boltColorNewest.getRed(&nr, green: &ng, blue: &nb, alpha: &na))
    XCTAssertGreaterThanOrEqual(nr, 0.96)
    XCTAssertGreaterThanOrEqual(ng, 0.97)
    XCTAssertGreaterThanOrEqual(nb, 0.98)
  }

  func testBoltYawIsStableAndBounded() {
    XCTAssertEqual(LightningRadarOverlay.yawDegrees(for: "abc123"), LightningRadarOverlay.yawDegrees(for: "abc123"))
    XCTAssertNotEqual(LightningRadarOverlay.yawDegrees(for: "abc123"), LightningRadarOverlay.yawDegrees(for: "def456"))
    let yaw = LightningRadarOverlay.yawDegrees(for: "abc123")
    XCTAssertGreaterThanOrEqual(yaw, -20)
    XCTAssertLessThanOrEqual(yaw, 20)
  }

  private static let sampleJSON = """
    {
      "success": true,
      "error": null,
      "response": [
        {
          "id": "abc123",
          "loc": { "long": -89.8295, "lat": 34.9618 },
          "ob": {
            "timestamp": 1787437159,
            "dateTimeISO": "2026-08-22T22:19:19+00:00",
            "pulse": { "type": "cg", "peakamp": -7000 }
          },
          "age": 41
        },
        {
          "id": "def456",
          "loc": { "long": -90.0123, "lat": 35.1001 },
          "ob": {
            "timestampMS": 1787437100500,
            "dateTimeISO": "2026-08-22T22:18:20.500+00:00",
            "pulse": { "type": "CG", "peakamp": 12000 }
          }
        }
      ]
    }
    """.data(using: .utf8)!
}
