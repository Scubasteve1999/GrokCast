import XCTest

@testable import DayCast

final class SkyCheckGlanceTests: XCTestCase {

  func testStructuredReplySplitsAnswerChangesAndDetails() {
    let raw = """
      **Short answer**
      "Dry and hot through this afternoon."

      **What changes**
      - Rain chance rises after 3 PM
      - Heat index reaches ~94°
      - No immediate severe threat

      **Details**
      NWS MEG AFD: isolated storms wait until Tuesday.
      HRRR stays dry through 21Z.
      """
    let result = SkyCheckGlance.parse(raw)
    XCTAssertEqual(result.shortAnswer, "Dry and hot through this afternoon.")
    XCTAssertEqual(
      result.changes,
      [
        "Rain chance rises after 3 PM",
        "Heat index reaches ~94°",
        "No immediate severe threat",
      ])
    XCTAssertTrue(result.showsDetails)
    XCTAssertTrue(result.details?.contains("NWS MEG AFD") == true)
    XCTAssertTrue(result.details?.contains("HRRR") == true)
  }

  func testCapsWhatChangesAtThree() {
    let raw = """
      **Short answer**
      Storms hold off until evening.

      **What changes**
      - Dry through 4 PM
      - Storms 5–7 PM
      - Wind 30 mph
      - Hail possible
      """
    let result = SkyCheckGlance.parse(raw)
    XCTAssertEqual(result.changes.count, 3)
    XCTAssertEqual(result.changes.last, "Wind 30 mph")
  }

  func testOmitsEmptyDetails() {
    let raw = """
      **Short answer**
      Good time to walk.

      **What changes**
      - Dry for the next 2 hours
      """
    let result = SkyCheckGlance.parse(raw)
    XCTAssertEqual(result.shortAnswer, "Good time to walk.")
    XCTAssertEqual(result.changes, ["Dry for the next 2 hours"])
    XCTAssertFalse(result.showsDetails)
    XCTAssertNil(result.details)
  }

  func testPreambleBeforeHeadingsBecomesShortAnswer() {
    let raw = """
      Dry and hot through this afternoon.

      **What changes**
      - Rain chance rises after 3 PM
      """
    let result = SkyCheckGlance.parse(raw)
    XCTAssertEqual(result.shortAnswer, "Dry and hot through this afternoon.")
    XCTAssertEqual(result.changes, ["Rain chance rises after 3 PM"])
  }

  func testUnheadedParagraphPlusBulletsPlusSources() {
    let raw = """
      Dry and hot through this afternoon.

      - Rain chance rises after 3 PM
      - Heat index reaches ~94°

      NWS MEG AFD: storms wait until Tuesday.
      """
    let result = SkyCheckGlance.parse(raw)
    XCTAssertEqual(result.shortAnswer, "Dry and hot through this afternoon.")
    XCTAssertEqual(
      result.changes,
      ["Rain chance rises after 3 PM", "Heat index reaches ~94°"])
    XCTAssertTrue(result.details?.contains("NWS MEG AFD") == true)
  }

  func testPlainParagraphStaysTheAnswer() {
    let raw = "It's a good time to walk. Rain holds off until after dinner."
    let result = SkyCheckGlance.parse(raw)
    XCTAssertEqual(result.shortAnswer, raw)
    XCTAssertTrue(result.changes.isEmpty)
    XCTAssertNil(result.details)
  }

  func testMarkdownWatchNextStillGetsASpace() {
    let raw = """
      **Short answer**
      Olive Branch, MS.**Watch next:** stay flexible.

      **What changes**
      - Storms later
      """
    let result = SkyCheckGlance.parse(raw)
    XCTAssertTrue(result.shortAnswer.contains("MS. **Watch next:**"))
    XCTAssertFalse(result.shortAnswer.contains("MS.**W"))
  }
}
