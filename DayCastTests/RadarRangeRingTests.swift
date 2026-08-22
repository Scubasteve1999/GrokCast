import CoreLocation
import XCTest

@testable import DayCast

final class RadarRangeRingTests: XCTestCase {
  private let olive = CLLocationCoordinate2D(latitude: 34.9618, longitude: -89.8295)

  func testRadiusIsThirtyMiles() {
    XCTAssertEqual(RadarRangeRing.radiusMiles, 30, accuracy: 0.001)
    XCTAssertEqual(RadarRangeRing.radiusMeters, 30 * 1609.344, accuracy: 0.01)
    XCTAssertEqual(RadarRangeRing.label, "30 mi")
    XCTAssertEqual(RadarChromeCopy.rangeRingLabel, "30 mi")
  }

  func testRingIsClosedAndThirtyMilesFromCenter() {
    let ring = RadarRangeRing.ringCoordinates(center: olive)
    XCTAssertEqual(ring.count, RadarRangeRing.steps + 1)
    XCTAssertEqual(ring.first?.latitude ?? 0, ring.last?.latitude ?? 1, accuracy: 0.0000001)
    XCTAssertEqual(ring.first?.longitude ?? 0, ring.last?.longitude ?? 1, accuracy: 0.0000001)

    let origin = CLLocation(latitude: olive.latitude, longitude: olive.longitude)
    let samples = [0, 18, 36, 54]
    for index in samples {
      let point = ring[index]
      let meters = origin.distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude))
      XCTAssertEqual(
        meters,
        RadarRangeRing.radiusMeters,
        accuracy: 400,
        "vertex \(index) should sit ~30 mi from Home"
      )
    }
  }

  func testLabelSitsOnTheRingSoutheast() {
    let label = RadarRangeRing.labelCoordinate(center: olive)
    let origin = CLLocation(latitude: olive.latitude, longitude: olive.longitude)
    let meters = origin.distance(from: CLLocation(latitude: label.latitude, longitude: label.longitude))
    XCTAssertEqual(meters, RadarRangeRing.radiusMeters, accuracy: 400)
    XCTAssertEqual(RadarRangeRing.labelBearingDegrees, 135, accuracy: 0.01)
    XCTAssertGreaterThan(olive.latitude, label.latitude)
    XCTAssertGreaterThan(label.longitude, olive.longitude)
  }

  func testLabelCapsuleImageIsReadable() {
    let image = RadarRangeRingOverlay.makeLabelImage()
    XCTAssertGreaterThan(image.size.width, 28)
    XCTAssertGreaterThan(image.size.height, 12)
  }

  func testOverlaySignatureChangesWithCity() {
    let memphis = CLLocationCoordinate2D(latitude: 35.1495, longitude: -90.0490)
    XCTAssertNotEqual(
      RadarRangeRingOverlay.overlaySignature(center: olive),
      RadarRangeRingOverlay.overlaySignature(center: memphis)
    )
    XCTAssertTrue(RadarRangeRingOverlay.overlaySignature(center: olive).contains("30.0"))
  }
}
