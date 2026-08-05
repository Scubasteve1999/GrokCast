import CoreLocation
import XCTest

@testable import DayCast

final class FIRMSDecodingTests: XCTestCase {
  func testParsesVIIRSCSVRows() {
    let csv = """
      latitude,longitude,bright_ti4,scan,track,acq_date,acq_time,satellite,confidence,version,bright_ti5,frp,daynight
      34.5123,-118.7456,330.1,0.39,0.36,2026-07-30,1845,N20,nominal,2.0NRT,285.2,12.4,D
      34.5201,-118.7510,341.8,0.39,0.36,2026-07-30,1845,N20,high,2.0NRT,290.1,48.2,D
      """
    let spots = FIRMSCSVParser.parse(csv: csv, satellite: "VIIRS_NOAA20_NRT")
    XCTAssertEqual(spots.count, 2)
    XCTAssertEqual(spots[0].latitude, 34.5123, accuracy: 0.0001)
    XCTAssertEqual(spots[0].longitude, -118.7456, accuracy: 0.0001)
    XCTAssertEqual(spots[0].frp, 12.4)
    XCTAssertEqual(spots[0].confidence, "nominal")
    XCTAssertEqual(spots[0].satellite, "N20")
    XCTAssertNotNil(spots[0].detectedAt)
    XCTAssertEqual(spots[1].frp, 48.2)
    XCTAssertTrue(spots[0].id.contains("34.5123"))
  }

  func testIgnoresJunkAndMissingHeader() {
    XCTAssertTrue(FIRMSCSVParser.parse(csv: "not,a,firms,file\n1,2,3", satellite: "x").isEmpty)
    XCTAssertTrue(FIRMSCSVParser.parse(csv: "", satellite: "x").isEmpty)
  }

  func testGeographicBoundsSquareClampsAndFormatsFIRMS() {
    let bounds = GeographicBounds.square(
      around: CLLocationCoordinate2D(latitude: 34.5, longitude: -118.5),
      halfSpanDegrees: 1.5
    )
    XCTAssertEqual(bounds.west, -120.0, accuracy: 0.0001)
    XCTAssertEqual(bounds.south, 33.0, accuracy: 0.0001)
    XCTAssertEqual(bounds.east, -117.0, accuracy: 0.0001)
    XCTAssertEqual(bounds.north, 36.0, accuracy: 0.0001)
    let parts = bounds.firmsAreaCoordinates.split(separator: ",").compactMap { Double($0) }
    XCTAssertEqual(parts.count, 4)
    XCTAssertEqual(parts[0], -120.0, accuracy: 0.0001)
    XCTAssertEqual(parts[1], 33.0, accuracy: 0.0001)
    XCTAssertEqual(parts[2], -117.0, accuracy: 0.0001)
    XCTAssertEqual(parts[3], 36.0, accuracy: 0.0001)
  }

  func testHotspotAgeHours() {
    let detected = Date().addingTimeInterval(-7200)
    let spot = FireHotspot(
      id: "t",
      latitude: 1,
      longitude: 2,
      brightness: nil,
      frp: 10,
      confidence: nil,
      acqDate: nil,
      acqTime: nil,
      satellite: nil,
      detectedAt: detected
    )
    XCTAssertEqual(spot.ageHours() ?? -1, 2, accuracy: 0.05)
  }
}
