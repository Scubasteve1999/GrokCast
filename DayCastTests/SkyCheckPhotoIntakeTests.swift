import AVFoundation
import XCTest

@testable import DayCast

final class SkyCheckPhotoIntakeTests: XCTestCase {
  func testCameraAndLibrarySetTheSamePendingImagePath() {
    let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
    let fromCamera = SkyCheckPhotoIntake.pendingImage(from: jpeg)
    let fromLibrary = SkyCheckPhotoIntake.pendingImage(from: jpeg)
    XCTAssertEqual(fromCamera, fromLibrary)
    XCTAssertEqual(try fromCamera.get(), jpeg)
    XCTAssertEqual(SkyCheckPhotoSource.allCases, [.camera, .photoLibrary])
  }

  func testEmptyBytesFailHonestlyWithoutCrashing() {
    XCTAssertEqual(SkyCheckPhotoIntake.pendingImage(from: nil), .failure(.couldNotLoad))
    XCTAssertEqual(SkyCheckPhotoIntake.pendingImage(from: Data()), .failure(.couldNotLoad))
    XCTAssertEqual(
      SkyCheckPhotoIntake.Failure.couldNotLoad.userMessage,
      SkyCheckDeskCopy.photoLoadFailed)
  }

  func testSimulatorCameraUnavailableFailsHonestly() {
    let gate = SkyCheckCameraGate.evaluate(
      isSourceAvailable: false, authorization: .authorized)
    XCTAssertEqual(gate, .unavailable)
    XCTAssertEqual(gate.failure, .cameraUnavailable)
    XCTAssertEqual(
      gate.failure?.userMessage,
      "This device has no camera. Pick a photo from the library.")
  }

  func testDeniedCameraFailsHonestlyAndLibraryStillWorks() {
    let denied = SkyCheckCameraGate.evaluate(
      isSourceAvailable: true, authorization: .denied)
    XCTAssertEqual(denied, .denied)
    XCTAssertEqual(
      denied.failure?.userMessage,
      "Camera access is off. Pick a photo from the library.")

    let restricted = SkyCheckCameraGate.evaluate(
      isSourceAvailable: true, authorization: .restricted)
    XCTAssertEqual(restricted, .denied)

    let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
    XCTAssertEqual(try SkyCheckPhotoIntake.pendingImage(from: jpeg).get(), jpeg)
  }

  func testAuthorizedCameraIsReady() {
    XCTAssertEqual(
      SkyCheckCameraGate.evaluate(isSourceAvailable: true, authorization: .authorized),
      .ready)
    XCTAssertEqual(
      SkyCheckCameraGate.evaluate(
        isSourceAvailable: true, authorization: .notDetermined),
      .needsAuthorization)
  }

  func testChooserCopyIsCameraAndPhotoLibrary() {
    XCTAssertEqual(SkyCheckPhotoSource.camera.buttonTitle, "Camera")
    XCTAssertEqual(SkyCheckPhotoSource.photoLibrary.buttonTitle, "Photo Library")
    XCTAssertEqual(SkyCheckDeskCopy.photoGlyph, "camera")
    XCTAssertEqual(SkyCheckDeskCopy.photoCTA, "Check this sky")
    XCTAssertEqual(SkyCheckDeskCopy.checkAnotherCTA, "Check another")
  }
}
