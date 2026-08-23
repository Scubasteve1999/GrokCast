import CoreLocation
import XCTest

@testable import DayCast

final class RadarRangeRingTests: XCTestCase {
  private let olive = CLLocationCoordinate2D(latitude: 34.9618, longitude: -89.8295)
  private let memphis = CLLocationCoordinate2D(latitude: 35.1495, longitude: -90.0490)
  private let seattle = CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321)

  func testRadiusIsFiftyMiles() {
    XCTAssertEqual(RadarRangeRing.radiusMiles, 50, accuracy: 0.001)
    XCTAssertEqual(RadarRangeRing.radiusMeters, 50 * 1609.344, accuracy: 0.01)
    XCTAssertEqual(RadarRangeRing.label, "50 mi")
    XCTAssertEqual(RadarChromeCopy.rangeRingLabel, "50 mi")
  }

  func testRingIsClosedAndFiftyMilesFromCenter() {
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
        "vertex \(index) should sit ~50 mi from the confirmed center"
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
    XCTAssertNotEqual(
      RadarRangeRingOverlay.overlaySignature(center: olive),
      RadarRangeRingOverlay.overlaySignature(center: memphis)
    )
    XCTAssertTrue(RadarRangeRingOverlay.overlaySignature(center: olive).contains("50.0"))
  }

  func testCityChipCenterIsTheChipCoordinate() {
    let chip = SavedLocation(
      name: "Memphis, TN", latitude: memphis.latitude, longitude: memphis.longitude)
    let center = RadarRangeRing.confirmedCenter(
      selectedLocation: chip, deviceCoordinate: seattle)
    XCTAssertEqual(center?.latitude ?? 0, memphis.latitude, accuracy: 0.0000001)
    XCTAssertEqual(center?.longitude ?? 0, memphis.longitude, accuracy: 0.0000001)
  }

  func testOliveBranchChipUsesOliveBranchBecauseItIsSelected() {
    let center = RadarRangeRing.confirmedCenter(
      selectedLocation: .oliveBranch, deviceCoordinate: seattle)
    XCTAssertEqual(center?.latitude ?? 0, SavedLocation.oliveBranch.latitude, accuracy: 0.0000001)
    XCTAssertEqual(center?.longitude ?? 0, SavedLocation.oliveBranch.longitude, accuracy: 0.0000001)
  }

  func testNearMeUsesDeviceCoordinateNotOliveBranchDefault() {
    let nearMe = SavedLocation(
      name: "Current Location",
      latitude: SavedLocation.oliveBranch.latitude,
      longitude: SavedLocation.oliveBranch.longitude,
      isCurrent: true
    )
    let center = RadarRangeRing.confirmedCenter(
      selectedLocation: nearMe, deviceCoordinate: seattle)
    XCTAssertEqual(center?.latitude ?? 0, seattle.latitude, accuracy: 0.0000001)
    XCTAssertEqual(center?.longitude ?? 0, seattle.longitude, accuracy: 0.0000001)
    XCTAssertNotEqual(
      center?.latitude ?? 0, SavedLocation.oliveBranch.latitude, accuracy: 0.01)
  }

  func testNearMeWithoutGPSDoesNotFallBackToOliveBranch() {
    let nearMe = SavedLocation(
      name: "Current Location",
      latitude: SavedLocation.oliveBranch.latitude,
      longitude: SavedLocation.oliveBranch.longitude,
      isCurrent: true
    )
    XCTAssertNil(
      RadarRangeRing.confirmedCenter(selectedLocation: nearMe, deviceCoordinate: nil))
    XCTAssertTrue(
      RadarRangeRing.showsLocationUnavailable(
        selectedLocation: nearMe, deviceCoordinate: nil))
  }

  func testNilSelectionDoesNotFallBackToOliveBranch() {
    XCTAssertNil(
      RadarRangeRing.confirmedCenter(selectedLocation: nil, deviceCoordinate: seattle))
    XCTAssertNil(
      RadarRangeRing.confirmedCenter(selectedLocation: nil, deviceCoordinate: nil))
    XCTAssertFalse(
      RadarRangeRing.showsLocationUnavailable(
        selectedLocation: nil, deviceCoordinate: nil))
  }

  func testChipSwitchRecentersOnTheSelectedCoordinate() {
    let oliveChip = SavedLocation.oliveBranch
    let memphisChip = SavedLocation(
      name: "Memphis, TN", latitude: memphis.latitude, longitude: memphis.longitude)
    let nearMe = SavedLocation(
      name: "Current Location",
      latitude: olive.latitude,
      longitude: olive.longitude,
      isCurrent: true
    )

    let oliveCenter = RadarRangeRing.confirmedCenter(
      selectedLocation: oliveChip, deviceCoordinate: seattle)
    let memphisCenter = RadarRangeRing.confirmedCenter(
      selectedLocation: memphisChip, deviceCoordinate: seattle)
    let nearMeCenter = RadarRangeRing.confirmedCenter(
      selectedLocation: nearMe, deviceCoordinate: seattle)

    XCTAssertEqual(oliveCenter?.latitude ?? 0, olive.latitude, accuracy: 0.0000001)
    XCTAssertEqual(memphisCenter?.latitude ?? 0, memphis.latitude, accuracy: 0.0000001)
    XCTAssertEqual(nearMeCenter?.latitude ?? 0, seattle.latitude, accuracy: 0.0000001)
    XCTAssertNotEqual(
      oliveCenter?.latitude ?? 0, memphisCenter?.latitude ?? 1, accuracy: 0.001)
    XCTAssertNotEqual(
      memphisCenter?.latitude ?? 0, nearMeCenter?.latitude ?? 1, accuracy: 0.001)
  }

  func testRingMathAndOverlaySignatureShareTheSameCenter() {
    let chip = SavedLocation(
      name: "Memphis, TN", latitude: memphis.latitude, longitude: memphis.longitude)
    let center = RadarRangeRing.confirmedCenter(
      selectedLocation: chip, deviceCoordinate: seattle)
    XCTAssertNotNil(center)
    guard let center else { return }

    let ring = RadarRangeRing.ringCoordinates(center: center)
    let origin = CLLocation(latitude: center.latitude, longitude: center.longitude)
    let vertex = ring[0]
    let meters = origin.distance(from: CLLocation(latitude: vertex.latitude, longitude: vertex.longitude))
    XCTAssertEqual(meters, RadarRangeRing.radiusMeters, accuracy: 400)

    XCTAssertEqual(
      RadarRangeRingOverlay.overlaySignature(center: center),
      RadarRangeRingOverlay.overlaySignature(center: memphis)
    )
    XCTAssertTrue(RadarRangeRingOverlay.overlaySignature(center: center).contains("50.0"))
  }

  func testLocationUnavailableCopyIsHonest() {
    XCTAssertEqual(RadarChromeCopy.rangeRingLocationUnavailable, "Location unavailable")
  }
}
