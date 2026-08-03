import UIKit
import XCTest

@testable import GrokCast

/// Guards the contract between the app and `server/push-agent`. The worker rejects
/// a malformed registration, and a rejected registration fails silently by design —
/// so these are the checks that would otherwise only surface as "pushes stopped".
@MainActor
final class PushRegistrationTests: XCTestCase {
  func testDeviceIDMatchesTheWorkerPattern() {
    let id = PushRegistrationService.deviceID()

    // Worker-side: /^[A-Za-z0-9_-]{16,128}$/
    XCTAssertGreaterThanOrEqual(id.count, 16)
    XCTAssertLessThanOrEqual(id.count, 128)

    let allowed = CharacterSet(charactersIn: "-_")
      .union(.alphanumerics)
    XCTAssertTrue(
      id.unicodeScalars.allSatisfy(allowed.contains),
      "device id must be URL-safe; got \(id)"
    )
  }

  func testDeviceIDIsStableAcrossCalls() {
    // A new id per call would orphan the previous registration on the worker,
    // leaving a Durable Object polling NWS for a device that stopped listening.
    XCTAssertEqual(PushRegistrationService.deviceID(), PushRegistrationService.deviceID())
  }

  func testDeviceIDIsNotDerivedFromIdentifierForVendor() {
    // The shared secret ships in the binary, so the id is the only thing stopping
    // one device from unregistering another. It must be unguessable.
    let vendorID = UIDevice.current.identifierForVendor?.uuidString ?? ""
    XCTAssertFalse(vendorID.isEmpty && PushRegistrationService.deviceID().isEmpty)
    XCTAssertNotEqual(PushRegistrationService.deviceID(), vendorID)
  }

  func testTemperatureUnitRawValuesMatchWhatTheWorkerAccepts() {
    // The worker validates against exactly these two strings; renaming a case here
    // would make every registration 400 with no visible symptom in the app.
    XCTAssertEqual(TemperatureUnit.fahrenheit.rawValue, "fahrenheit")
    XCTAssertEqual(TemperatureUnit.celsius.rawValue, "celsius")
  }

  func testServiceStaysInertWhileUnconfigured() async throws {
    // With no base URL compiled in, sync must be a no-op rather than a failed
    // request — notifications stay local-only and nothing is surfaced.
    guard !PushRegistrationService.isConfigured else {
      throw XCTSkip("push agent is configured in this build; inert path not exercised")
    }
    await PushRegistrationService.shared.sync()
    await PushRegistrationService.shared.unregister()
  }

  func testMorningBriefHourStaysInTheRangeTheWorkerExpects() {
    let store = WeatherStore.shared
    let original = store.morningBriefHour
    defer { store.morningBriefHour = original }

    store.morningBriefHour = 3
    XCTAssertGreaterThanOrEqual(store.morningBriefHour, 0)
    XCTAssertLessThanOrEqual(store.morningBriefHour, 23)

    store.morningBriefHour = 30
    XCTAssertLessThanOrEqual(store.morningBriefHour, 23)
  }
}
