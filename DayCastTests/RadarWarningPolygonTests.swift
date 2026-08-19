import XCTest

@testable import DayCast

final class RadarWarningPolygonTests: XCTestCase {

  // MARK: - Decode keeps rings

  func testPolygonGeometryKeepsRings() throws {
    let json = """
      {
        "features": [
          {
            "id": "urn:oid:tor",
            "geometry": {
              "type": "Polygon",
              "coordinates": [[
                [-89.9, 34.9],
                [-89.8, 34.9],
                [-89.8, 35.0],
                [-89.9, 35.0],
                [-89.9, 34.9]
              ]]
            },
            "properties": {
              "event": "Tornado Warning",
              "severity": "Extreme",
              "headline": "Tornado Warning",
              "expires": "2099-01-01T00:00:00Z",
              "areaDesc": "DeSoto, MS"
            }
          }
        ]
      }
      """.data(using: .utf8)!

    let response = try JSONDecoder().decode(NWSAlertsResponse.self, from: json)
    let geom = try XCTUnwrap(response.features.first?.geometry)
    let rings = try XCTUnwrap(geom.polygonCoordinates)
    XCTAssertEqual(rings.count, 1)
    XCTAssertEqual(rings[0].count, 1)
    XCTAssertEqual(rings[0][0].count, 5)
    XCTAssertEqual(rings[0][0][0], [-89.9, 34.9])
    XCTAssertEqual(geom.representativePoint?.latitude, 34.9)
    XCTAssertEqual(geom.representativePoint?.longitude, -89.9)
    XCTAssertEqual(geom.vertexCount, 5)
  }

  func testMultiPolygonGeometryKeepsAllPolygons() throws {
    let json = """
      {
        "features": [
          {
            "id": "urn:oid:svr",
            "geometry": {
              "type": "MultiPolygon",
              "coordinates": [
                [[[-89.9, 34.9], [-89.8, 34.9], [-89.8, 35.0], [-89.9, 35.0], [-89.9, 34.9]]],
                [[[-90.1, 35.1], [-90.0, 35.1], [-90.0, 35.2], [-90.1, 35.2], [-90.1, 35.1]]]
              ]
            },
            "properties": {
              "event": "Severe Thunderstorm Warning",
              "severity": "Severe",
              "headline": "Severe Thunderstorm Warning"
            }
          }
        ]
      }
      """.data(using: .utf8)!

    let response = try JSONDecoder().decode(NWSAlertsResponse.self, from: json)
    let geom = try XCTUnwrap(response.features.first?.geometry)
    let rings = try XCTUnwrap(geom.polygonCoordinates)
    XCTAssertEqual(rings.count, 2)
    XCTAssertEqual(rings[0][0].count, 5)
    XCTAssertEqual(rings[1][0][0], [-90.1, 35.1])
  }

  func testPointGeometryHasNoRings() throws {
    let json = """
      {
        "features": [
          {
            "id": "urn:oid:point",
            "geometry": { "type": "Point", "coordinates": [-89.83, 34.96] },
            "properties": { "event": "Tornado Warning" }
          }
        ]
      }
      """.data(using: .utf8)!

    let response = try JSONDecoder().decode(NWSAlertsResponse.self, from: json)
    let geom = try XCTUnwrap(response.features.first?.geometry)
    XCTAssertNil(geom.polygonCoordinates)
    let point = try XCTUnwrap(geom.representativePoint)
    XCTAssertEqual(point.latitude, 34.96, accuracy: 0.0001)
    XCTAssertEqual(point.longitude, -89.83, accuracy: 0.0001)
  }

  func testNWSAlertRoundTripKeepsRings() throws {
    let rings: [[[[Double]]]] = [[
      [[-89.9, 34.9], [-89.8, 34.9], [-89.8, 35.0], [-89.9, 35.0], [-89.9, 34.9]]
    ]]
    let alert = makeAlert(event: "Tornado Warning", rings: rings)
    let data = try JSONEncoder().encode(alert)
    let decoded = try JSONDecoder().decode(NWSAlert.self, from: data)
    XCTAssertEqual(decoded.polygonCoordinates, rings)
  }

  func testLegacyHistoryWithoutRingsStillDecodes() throws {
    let json = """
      {
        "id": "legacy",
        "event": "Tornado Warning",
        "latitude": 34.96,
        "longitude": -89.83,
        "containsSelectedPoint": true,
        "firstSeen": 0
      }
      """.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(NWSAlert.self, from: json)
    XCTAssertNil(decoded.polygonCoordinates)
    XCTAssertEqual(decoded.event, "Tornado Warning")
  }

  func testHistoryMergeKeepsFetchedRings() {
    let rings: [[[[Double]]]] = [[[[-89.9, 34.9], [-89.8, 34.9], [-89.8, 35.0], [-89.9, 34.9]]]]
    let prior = makeAlert(id: "tor-1", event: "Tornado Warning", rings: nil)
    let fetched = makeAlert(id: "tor-1", event: "Tornado Warning", rings: rings)
    let merged = AlertHistoryStore.merge(fetched: [fetched], into: [prior])
    XCTAssertEqual(merged.first?.polygonCoordinates, rings)
  }

  // MARK: - Filter

  func testPaintsTornadoSevereFlashFloodMarineSnowSquallExtremeWind() {
    let events = [
      "Tornado Warning",
      "Severe Thunderstorm Warning",
      "Flash Flood Warning",
      "Special Marine Warning",
      "Snow Squall Warning",
      "Extreme Wind Warning",
    ]
    for event in events {
      XCTAssertNotNil(RadarWarningPolygon.kind(forEvent: event), event)
      let drawn = RadarWarningPolygon.drawn(from: [makeAlert(event: event, rings: sampleRings)])
      XCTAssertEqual(drawn.count, 1, event)
    }
  }

  func testExcludesAdvisoriesWatchesStatementsAndOtherWarnings() {
    let excluded = [
      "Heat Advisory",
      "Extreme Heat Warning",
      "Winter Storm Warning",
      "Tornado Watch",
      "Severe Thunderstorm Watch",
      "Flash Flood Watch",
      "Special Weather Statement",
      "Flood Advisory",
      "Red Flag Warning",
    ]
    for event in excluded {
      XCTAssertNil(RadarWarningPolygon.kind(forEvent: event), event)
      XCTAssertTrue(
        RadarWarningPolygon.drawn(from: [makeAlert(event: event, rings: sampleRings)]).isEmpty,
        event
      )
    }
  }

  func testDoesNotPaintWarningWithoutRings() {
    let alert = makeAlert(event: "Tornado Warning", rings: nil)
    XCTAssertTrue(RadarWarningPolygon.drawn(from: [alert]).isEmpty)
  }

  func testHeatAdvisoryInHUDWithNoBoxIsCorrect() {
    let heat = makeAlert(event: "Heat Advisory", rings: sampleRings)
    let tor = makeAlert(id: "tor", event: "Tornado Warning", rings: sampleRings)
    let drawn = RadarWarningPolygon.drawn(from: [heat, tor])
    XCTAssertEqual(drawn.map(\.event), ["Tornado Warning"])
  }

  // MARK: - Colors + VoiceOver

  func testRadarScopeColors() {
    XCTAssertEqual(RadarWarningPolygon.Kind.tornado.fillHex, "#FF0000")
    XCTAssertEqual(RadarWarningPolygon.Kind.severeThunderstorm.fillHex, "#FFD400")
    XCTAssertEqual(RadarWarningPolygon.Kind.flashFlood.fillHex, "#00C800")
    XCTAssertEqual(RadarWarningPolygon.Kind.specialMarine.fillHex, "#FF8C00")
    XCTAssertEqual(RadarWarningPolygon.Kind.snowSquall.fillHex, "#FF8C00")
    XCTAssertEqual(RadarWarningPolygon.Kind.extremeWind.fillHex, "#FF8C00")
  }

  func testAccessibilityLabels() {
    XCTAssertEqual(
      RadarWarningPolygon.Kind.tornado.accessibilityLabel, "Tornado warning area")
    XCTAssertEqual(
      RadarWarningPolygon.Kind.severeThunderstorm.accessibilityLabel,
      "Severe thunderstorm warning area")
    XCTAssertEqual(
      RadarWarningPolygon.Kind.flashFlood.accessibilityLabel, "Flash flood warning area")
    XCTAssertEqual(
      RadarWarningPolygon.Kind.specialMarine.accessibilityLabel, "Special marine warning area")
    XCTAssertEqual(
      RadarWarningPolygon.Kind.snowSquall.accessibilityLabel, "Snow squall warning area")
    XCTAssertEqual(
      RadarWarningPolygon.Kind.extremeWind.accessibilityLabel, "Extreme wind warning area")
  }

  // MARK: - Overlay updates

  func testOverlaySignatureEmptyWhenNoMatchingWarnings() {
    let heat = makeAlert(event: "Heat Advisory", rings: sampleRings)
    XCTAssertEqual(RadarWarningPolygon.overlaySignature(from: [heat]), "")
    XCTAssertEqual(RadarWarningPolygon.overlaySignature(from: []), "")
  }

  func testOverlaySignatureChangesWhenAlertsChange() {
    let tor = makeAlert(id: "tor", event: "Tornado Warning", rings: sampleRings)
    let svr = makeAlert(id: "svr", event: "Severe Thunderstorm Warning", rings: sampleRings)
    let empty = RadarWarningPolygon.overlaySignature(from: [])
    let one = RadarWarningPolygon.overlaySignature(from: [tor])
    let two = RadarWarningPolygon.overlaySignature(from: [tor, svr])
    XCTAssertNotEqual(empty, one)
    XCTAssertNotEqual(one, two)
    XCTAssertTrue(one.contains("tornado"))
    XCTAssertTrue(two.contains("severeThunderstorm"))
  }

  func testDrawnSkipsBrokenRings() {
    let broken: [[[[Double]]]] = [[[[-89.9], [-89.8, 34.9]]]]
    let alert = makeAlert(event: "Tornado Warning", rings: broken)
    XCTAssertTrue(RadarWarningPolygon.drawn(from: [alert]).isEmpty)
  }

  // MARK: - Helpers

  private var sampleRings: [[[[Double]]]] {
    [[
      [[-89.9, 34.9], [-89.8, 34.9], [-89.8, 35.0], [-89.9, 35.0], [-89.9, 34.9]]
    ]]
  }

  private func makeAlert(
    id: String = "test",
    event: String,
    rings: [[[[Double]]]]?
  ) -> NWSAlert {
    NWSAlert(
      id: id,
      event: event,
      severity: "Severe",
      headline: nil,
      description: nil,
      instruction: nil,
      expires: Date().addingTimeInterval(3600),
      areaDesc: nil,
      latitude: 34.96,
      longitude: -89.83,
      polygonCoordinates: rings
    )
  }

  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: AlertHistoryStore.historyKey)
    UserDefaults.standard.removeObject(forKey: AlertHistoryStore.historyByLocationKey)
    super.tearDown()
  }
}
