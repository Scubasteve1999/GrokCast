import XCTest

@testable import DayCast

final class YourNewsHeadlineTests: XCTestCase {

  private let lateNightStorms =
    "Shower and thunderstorm chances increase late tonight into Monday, with organized severe weather not expected."
  private let midweekStorms =
    "Additional chances for showers and thunderstorms are expected through midweek."
  private let midSouthTemps =
    "Near to slightly above normal temperatures are expected across the Mid-South for most of the week, but extreme heat is not expected."
  private let tornadoSurvey = "NWS Damage Survey for 08/16/26 Tornado Event"
  private let flashFloodWatch = "Flash Flood Watch for the Mid-South"
  private let overnightHeat =
    "Heat continues through the weekend with little relief overnight."
  private let mondayFlood =
    "Flash flood risk rises Monday along slow-moving storms."

  func testLateNightStormsStayCuriousWithoutInventingSevere() {
    let item = megItem(title: lateNightStorms)
    XCTAssertEqual(
      item.displayTitle,
      "Why tonight\u{2019}s storms still have a window after dark."
    )
    XCTAssertTrue(item.title.contains("organized severe weather not expected"))
    let lower = item.displayTitle.lowercased()
    XCTAssertFalse(lower.contains("tornado"))
    XCTAssertFalse(lower.contains("severe"))
    XCTAssertFalse(lower.contains("warning"))
    XCTAssertTrue(YourNewsHeadline.isGrounded(item.displayTitle, in: item.title))
  }

  func testMidweekStormRoundNamesMEG() {
    let item = megItem(title: midweekStorms)
    XCTAssertEqual(
      item.displayTitle,
      "The midweek storm round MEG says isn\u{2019}t done yet."
    )
    XCTAssertTrue(item.title.lowercased().contains("midweek"))
    XCTAssertTrue(YourNewsHeadline.isGrounded(item.displayTitle, in: item.title))
  }

  func testLiveMEGTuesdayIsolatedStorms() {
    let item = megItem(
      title:
        "Isolated shower and thunderstorm chances will increase Tuesday morning for areas along and west of the Mississippi River."
    )
    XCTAssertEqual(
      item.displayTitle,
      "Why Tuesday morning still has an isolated storm window."
    )
    XCTAssertFalse(item.displayTitle.lowercased().contains("tornado"))
    XCTAssertFalse(item.displayTitle.lowercased().contains("severe"))
    XCTAssertTrue(YourNewsHeadline.isGrounded(item.displayTitle, in: item.title))
  }

  func testLiveMEGThursdayStormRound() {
    let item = megItem(
      title:
        "Additional chances for showers and thunderstorms are expected each day through Thursday."
    )
    XCTAssertEqual(
      item.displayTitle,
      "The Thursday storm round MEG says isn\u{2019}t done yet."
    )
    XCTAssertTrue(YourNewsHeadline.isGrounded(item.displayTitle, in: item.title))
  }

  func testMidSouthHeatDenialStaysADenial() {
    let item = megItem(title: midSouthTemps)
    XCTAssertEqual(
      item.displayTitle,
      "The Mid-South stays warm. Extreme heat? MEG says no."
    )
    XCTAssertTrue(item.title.lowercased().contains("extreme heat is not expected"))
    XCTAssertTrue(YourNewsHeadline.isGrounded(item.displayTitle, in: item.title))
  }

  func testTornadoSurveyMaySayTornadoBecauseSourceDoes() {
    let item = megItem(title: tornadoSurvey, product: "PNS")
    XCTAssertEqual(item.displayTitle, "The tornado damage survey NWS just posted.")
    XCTAssertTrue(item.title.lowercased().contains("tornado"))
    XCTAssertEqual(item.productCode, "PNS")
    XCTAssertTrue(item.url.absoluteString.contains("product=PNS"))
    XCTAssertTrue(item.url.absoluteString.contains("issuedby=MEG"))
    XCTAssertTrue(YourNewsHeadline.isGrounded(item.displayTitle, in: item.title))
  }

  func testFlashFloodWatchAndMondayFloodStayGrounded() {
    XCTAssertEqual(
      megItem(title: flashFloodWatch, product: "PNS").displayTitle,
      "The Flash Flood Watch MEG just posted."
    )
    XCTAssertEqual(
      megItem(title: mondayFlood).displayTitle,
      "The Monday flood risk MEG is flagging."
    )
    XCTAssertEqual(
      megItem(title: overnightHeat).displayTitle,
      "The overnight heat MEG says won\u{2019}t let up."
    )
  }

  func testUngroundedPunchUpIsRejected() {
    XCTAssertFalse(
      YourNewsHeadline.isGrounded(
        "Tornado warning tonight.",
        in: lateNightStorms
      )
    )
    XCTAssertTrue(
      YourNewsHeadline.isGrounded(
        "Why tonight\u{2019}s storms still have a window after dark.",
        in: lateNightStorms
      )
    )
  }

  func testDisplayRewriteDoesNotChangeURLOrImage() {
    let photo = URL(string: "https://media.weather.gov/meg/survey.jpg")!
    let item = megItem(title: tornadoSurvey, product: "PNS", imageURL: photo)
    XCTAssertEqual(
      item.url,
      LocalBriefingParser.productPageURL(cwa: "MEG", productCode: "PNS")
    )
    XCTAssertEqual(item.imageURL, photo)
    XCTAssertNotEqual(item.displayTitle, item.title)
    XCTAssertEqual(item.imageURL, photo)
    XCTAssertTrue(item.url.absoluteString.contains("product=PNS"))
  }

  func testOfficeTitleWithoutPatternStaysOfficeTitle() {
    let item = megItem(title: "Storm chances return Monday.")
    XCTAssertEqual(item.displayTitle, "Storm chances return Monday.")
  }

  private func megItem(title: String, product: String = "AFD", imageURL: URL? = nil)
    -> LocalBriefingItem
  {
    LocalBriefingItem(
      id: "test-\(product)",
      title: title,
      sourceName: "NWS Memphis",
      issuedAt: Date(timeIntervalSince1970: 1_787_515_000),
      url: LocalBriefingParser.productPageURL(cwa: "MEG", productCode: product),
      productCode: product,
      officeID: "MEG",
      imageURL: imageURL
    )
  }
}
