import XCTest

@testable import GrokCast

final class NIFCDecodingTests: XCTestCase {
  func testParsesIncidentFeature() throws {
    let feature: [String: Any] = [
      "type": "Feature",
      "properties": [
        "IncidentName": "Palisades",
        "UniqueFireIdentifier": "2026-CA-LAC-001234",
        "IrwinID": "IRWIN-ABC",
        "POOLatitude": 34.05,
        "POOLongitude": -118.55,
        "IncidentSize": 1200.5,
        "PercentContained": 35,
        "FireCause": "Undetermined",
        "FireDiscoveryDateTime": 1_753_920_000_000,
        "ModifiedOnDateTime_dt": 1_753_930_000_000,
      ],
      "geometry": [
        "type": "Point",
        "coordinates": [-118.55, 34.05],
      ],
    ]

    let incident = try XCTUnwrap(NIFCGeoJSONParser.incident(from: feature))
    XCTAssertEqual(incident.id, "IRWIN-ABC")
    XCTAssertEqual(incident.name, "Palisades")
    XCTAssertEqual(incident.latitude, 34.05)
    XCTAssertEqual(incident.longitude, -118.55)
    XCTAssertEqual(incident.acres, 1200.5)
    XCTAssertEqual(incident.percentContained, 35)
    XCTAssertEqual(incident.cause, "Undetermined")
    XCTAssertNotNil(incident.discoveryDate)
    XCTAssertEqual(incident.displayName, "Palisades")
  }

  func testParsesPerimeterPolygon() throws {
    let feature: [String: Any] = [
      "type": "Feature",
      "properties": [
        "poly_IncidentName": "Palisades",
        "poly_GISAcres": 980.0,
        "attr_PercentContained": 40,
        "GlobalID": "{AAAA-BBBB}",
        "OBJECTID": 42,
        "poly_DateCurrent": "2026-07-30T18:00:00Z",
      ],
      "geometry": [
        "type": "Polygon",
        "coordinates": [
          [
            [-118.56, 34.04],
            [-118.54, 34.04],
            [-118.54, 34.06],
            [-118.56, 34.06],
            [-118.56, 34.04],
          ]
        ],
      ],
    ]

    let perimeter = try XCTUnwrap(NIFCGeoJSONParser.perimeter(from: feature))
    XCTAssertEqual(perimeter.id, "{AAAA-BBBB}")
    XCTAssertEqual(perimeter.incidentName, "Palisades")
    XCTAssertEqual(perimeter.acres, 980)
    XCTAssertEqual(perimeter.percentContained, 40)
    XCTAssertFalse(perimeter.geometryJSONData.isEmpty)

    let geometry =
      try XCTUnwrap(
        JSONSerialization.jsonObject(with: perimeter.geometryJSONData) as? [String: Any]
      )
    XCTAssertEqual(geometry["type"] as? String, "Polygon")
  }

  func testPerimeterWithoutGeometryReturnsNil() {
    let feature: [String: Any] = [
      "type": "Feature",
      "properties": ["GlobalID": "x"],
    ]
    XCTAssertNil(NIFCGeoJSONParser.perimeter(from: feature))
  }

  func testIncidentFallsBackToCoordinatesAndNameId() throws {
    let feature: [String: Any] = [
      "type": "Feature",
      "properties": [
        "IncidentName": "Creek Fire"
      ],
      "geometry": [
        "type": "Point",
        "coordinates": [-119.2, 37.1],
      ],
    ]
    let incident = try XCTUnwrap(NIFCGeoJSONParser.incident(from: feature))
    XCTAssertEqual(incident.id, "name:Creek Fire")
    XCTAssertEqual(incident.latitude, 37.1)
    XCTAssertEqual(incident.longitude, -119.2)
  }
}
