import XCTest

@testable import DayCast

final class LocalBriefingParserTests: XCTestCase {

  private let now = Date(timeIntervalSince1970: 1_787_515_000)  // ~2026-08-24 00:16 UTC

  // MARK: - Points / CWA

  func testOliveBranchPointsDecodeToMEG() throws {
    let json = """
      {
        "properties": {
          "cwa": "MEG",
          "forecastOffice": "https://api.weather.gov/offices/MEG",
          "observationStations": "https://api.weather.gov/gridpoints/MEG/38,67/stations",
          "gridId": "MEG",
          "gridX": 38,
          "gridY": 67
        }
      }
      """.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(NWSPointsResponse.self, from: json)
    XCTAssertEqual(decoded.properties.cwa, "MEG")
    XCTAssertEqual(decoded.properties.gridId, "MEG")
  }

  func testMissingCWADecodesAsNil() throws {
    let json = """
      {
        "properties": {
          "observationStations": "https://api.weather.gov/gridpoints/MEG/38,67/stations",
          "gridId": "MEG"
        }
      }
      """.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(NWSPointsResponse.self, from: json)
    XCTAssertNil(decoded.properties.cwa)
  }

  func testNonUSMissingCWAAssemblesEmptyWithoutThrowing() {
    let items = LocalBriefingParser.assemble(
      cwa: "",
      officeName: nil,
      afd: (
        id: "x", issuedAt: now, text: Self.afdWithKeyMessages
      ),
      pns: [],
      now: now
    )
    XCTAssertTrue(items.isEmpty)
  }

  // MARK: - AFD KEY MESSAGES

  func testAFDMEGKeyMessagesYieldsBothBulletsAndSharedProductURL() {
    let issued = now.addingTimeInterval(-2 * 3600)
    let items = LocalBriefingParser.assemble(
      cwa: "MEG",
      officeName: "Memphis, TN",
      afd: (
        id: "d7681823-d4be-4d15-93b2-e5d65d79dd0a", issuedAt: issued, text: Self.afdWithKeyMessages
      ),
      pns: [],
      now: now
    )
    XCTAssertEqual(items.count, 2)
    let first = items[0]
    let second = items[1]
    XCTAssertEqual(first.id, "afd-d7681823-d4be-4d15-93b2-e5d65d79dd0a-km0")
    XCTAssertEqual(
      first.title,
      "Shower and thunderstorm chances increase late tonight into Monday, with organized severe weather not expected."
    )
    XCTAssertEqual(
      first.displayTitle,
      "Why tonight\u{2019}s storms still have a window after dark."
    )
    XCTAssertEqual(second.id, "afd-d7681823-d4be-4d15-93b2-e5d65d79dd0a-km1")
    XCTAssertEqual(
      second.title,
      "Additional chances for showers and thunderstorms are expected through midweek."
    )
    for card in items {
      XCTAssertEqual(card.sourceName, "NWS Memphis")
      XCTAssertEqual(card.productCode, "AFD")
      XCTAssertEqual(card.officeID, "MEG")
      XCTAssertNil(card.imageURL)
      XCTAssertTrue(card.url.absoluteString.contains("issuedby=MEG"), card.url.absoluteString)
      XCTAssertTrue(card.url.absoluteString.contains("product=AFD"), card.url.absoluteString)
      XCTAssertFalse(card.title.contains("Desert Southwest"))
      XCTAssertFalse(card.title.localizedCaseInsensitiveContains("DISCUSSION"))
    }
    XCTAssertEqual(first.url, second.url)
    XCTAssertEqual(first.relativeIssuedLabel(relativeTo: now), "2h ago")
  }

  func testAFDWithoutKeyMessagesYieldsNoItem() {
    let items = LocalBriefingParser.assemble(
      cwa: "MEG",
      officeName: "Memphis, TN",
      afd: (id: "no-keys", issuedAt: now, text: Self.afdWithoutKeyMessages),
      pns: [],
      now: now
    )
    XCTAssertTrue(items.isEmpty)
  }

  func testAFDOlderThan18HoursIsDropped() {
    let issued = now.addingTimeInterval(-19 * 3600)
    let items = LocalBriefingParser.assemble(
      cwa: "MEG",
      officeName: "Memphis, TN",
      afd: (id: "stale", issuedAt: issued, text: Self.afdWithKeyMessages),
      pns: [],
      now: now
    )
    XCTAssertTrue(items.isEmpty)
  }

  func testAFDAt18HoursIsKept() {
    let issued = now.addingTimeInterval(-18 * 3600)
    let items = LocalBriefingParser.assemble(
      cwa: "MEG",
      officeName: "Memphis, TN",
      afd: (id: "edge", issuedAt: issued, text: Self.afdWithKeyMessages),
      pns: [],
      now: now
    )
    XCTAssertEqual(items.count, 2)
  }

  // MARK: - PNS filter

  func testNWROutagePNSIsDropped() {
    let items = LocalBriefingParser.assemble(
      cwa: "MEG",
      officeName: "Memphis, TN",
      afd: nil,
      pns: [
        (id: "nwr", issuedAt: now.addingTimeInterval(-3600), text: Self.pnsNWROutage)
      ],
      now: now
    )
    XCTAssertTrue(items.isEmpty)
  }

  func testStormSurveyPNSIsKept() {
    let items = LocalBriefingParser.assemble(
      cwa: "MEG",
      officeName: "Memphis, TN",
      afd: nil,
      pns: [
        (id: "survey", issuedAt: now.addingTimeInterval(-3 * 3600), text: Self.pnsStormSurvey)
      ],
      now: now
    )
    XCTAssertEqual(items.count, 1)
    XCTAssertEqual(items[0].id, "pns-survey")
    XCTAssertEqual(items[0].title, "NWS Damage Survey for 08/16/26 Tornado Event")
    XCTAssertEqual(items[0].productCode, "PNS")
    XCTAssertNil(items[0].imageURL)
    XCTAssertTrue(items[0].url.absoluteString.contains("issuedby=MEG"))
    XCTAssertTrue(items[0].url.absoluteString.contains("product=PNS"))
  }

  func testPNSOlderThan48HoursIsDropped() {
    let items = LocalBriefingParser.assemble(
      cwa: "MEG",
      officeName: "Memphis, TN",
      afd: nil,
      pns: [
        (
          id: "old-survey", issuedAt: now.addingTimeInterval(-49 * 3600),
          text: Self.pnsStormSurvey
        )
      ],
      now: now
    )
    XCTAssertTrue(items.isEmpty)
  }

  func testAssembleCapsAtThreeCardsAFDFirst() {
    let pns: [(id: String, issuedAt: Date, text: String)] = (0..<4).map { index in
      (
        id: "pns-\(index)",
        issuedAt: now.addingTimeInterval(-TimeInterval(index + 1) * 3600),
        text: Self.pnsStormSurvey
      )
    }
    let items = LocalBriefingParser.assemble(
      cwa: "MEG",
      officeName: "Memphis, TN",
      afd: (id: "afd-1", issuedAt: now.addingTimeInterval(-1800), text: Self.afdWithKeyMessages),
      pns: pns,
      now: now
    )
    XCTAssertEqual(items.count, 3)
    XCTAssertEqual(items.map(\.productCode), ["AFD", "AFD", "PNS"])
    XCTAssertEqual(items[2].title, "NWS Damage Survey for 08/16/26 Tornado Event")
    XCTAssertTrue(items.allSatisfy { $0.imageURL == nil })
  }

  func testThreeKeyMessagesFillRailWithoutPNS() {
    let items = LocalBriefingParser.assemble(
      cwa: "MEG",
      officeName: "Memphis, TN",
      afd: (
        id: "afd-3", issuedAt: now.addingTimeInterval(-1800), text: Self.afdWithThreeKeyMessages
      ),
      pns: [
        (id: "survey", issuedAt: now.addingTimeInterval(-3600), text: Self.pnsStormSurvey)
      ],
      now: now
    )
    XCTAssertEqual(items.count, 3)
    XCTAssertEqual(items.map(\.productCode), ["AFD", "AFD", "AFD"])
    XCTAssertEqual(items.map(\.id), ["afd-afd-3-km0", "afd-afd-3-km1", "afd-afd-3-km2"])
    XCTAssertFalse(items.contains { $0.productCode == "PNS" })
  }

  func testDuplicateKeyMessageTitleIsSkipped() {
    let items = LocalBriefingParser.assemble(
      cwa: "MEG",
      officeName: "Memphis, TN",
      afd: (
        id: "dup", issuedAt: now.addingTimeInterval(-1800), text: Self.afdWithDuplicateKeyMessages
      ),
      pns: [],
      now: now
    )
    XCTAssertEqual(items.count, 2)
    XCTAssertEqual(items.map(\.id), ["afd-dup-km0", "afd-dup-km2"])
    XCTAssertEqual(items[0].title, "Heat continues through the weekend.")
    XCTAssertEqual(items[1].title, "Storm chances return Monday.")
  }

  func testPNSTitleMatchingKeyMessageIsDeduped() {
    let matchingHeadline = "Flash flood risk rises Monday along slow-moving storms"
    let items = LocalBriefingParser.assemble(
      cwa: "MEG",
      officeName: "Memphis, TN",
      afd: (id: "match", issuedAt: now.addingTimeInterval(-1800), text: Self.afdWithOneKeyMessage),
      pns: [
        (
          id: "dup-pns", issuedAt: now.addingTimeInterval(-3600),
          text: Self.pnsWithHeadline(matchingHeadline)
        )
      ],
      now: now
    )
    XCTAssertEqual(items.count, 1)
    XCTAssertEqual(items[0].productCode, "AFD")
    XCTAssertEqual(items[0].id, "afd-match-km0")
    XCTAssertFalse(items.contains { $0.productCode == "PNS" })
  }

  func testPNSFillsRemainingSlotsWhenFewerThanThreeKeyMessages() {
    let items = LocalBriefingParser.assemble(
      cwa: "MEG",
      officeName: "Memphis, TN",
      afd: (id: "afd-1", issuedAt: now.addingTimeInterval(-1800), text: Self.afdWithKeyMessages),
      pns: [
        (id: "flood-watch", issuedAt: now.addingTimeInterval(-3600), text: Self.pnsFloodWatch)
      ],
      now: now
    )
    XCTAssertEqual(items.map(\.productCode), ["AFD", "AFD", "PNS"])
    XCTAssertEqual(items[2].id, "pns-flood-watch")
    XCTAssertEqual(items[2].title, "Flash Flood Watch for the Mid-South")
  }

  func testOfficeNameFallbackIsNWSCWA() {
    XCTAssertEqual(LocalBriefingParser.sourceName(officeName: nil, cwa: "MEG"), "NWS MEG")
    XCTAssertEqual(
      LocalBriefingParser.sourceName(officeName: "Tampa Bay Area, FL", cwa: "TBW"),
      "NWS Tampa Bay Area"
    )
  }

  // MARK: - Honesty / storm reports toggle

  func testBriefingDoesNotCountAsAnActiveAlert() {
    let chrome = AlertsHonesty.chrome(nwsAlertCount: 0, hasSevereProducts: true)
    XCTAssertNotEqual(chrome.tabAccessibilityValue, AlertsHonesty.nwsCountPhrase(1))
    XCTAssertFalse(chrome.screenAccessibilityLabel.localizedCaseInsensitiveContains("1 active"))
    XCTAssertEqual(chrome.tabSymbolName, "bell.fill")

    let briefingOnly = AlertsHonesty.chrome(nwsAlertCount: 0, hasSevereProducts: false)
    XCTAssertEqual(briefingOnly.screenTitle, "Alerts")
    XCTAssertFalse(briefingOnly.showsActiveNow)
    XCTAssertNil(briefingOnly.tabAccessibilityValue)
    XCTAssertNotEqual(briefingOnly.tabAccessibilityValue, AlertsHonesty.nwsCountPhrase(1))
  }

  func testStormReportsToggleDefaultsOffAndHidesSection() {
    let suiteName = "LocalBriefingParserTests.stormReports"
    UserDefaults.standard.removePersistentDomain(forName: suiteName)
    let suite = UserDefaults(suiteName: suiteName)!
    let previous = StormReportsPreference.store
    StormReportsPreference.store = suite
    defer {
      StormReportsPreference.store = previous
      suite.removePersistentDomain(forName: suiteName)
    }

    XCTAssertFalse(StormReportsPreference.isEnabled)
    XCTAssertFalse(
      StormReportsVisibility.isSectionVisible(reportCount: 8, preferenceEnabled: false)
    )
    XCTAssertTrue(
      StormReportsVisibility.isSectionVisible(reportCount: 8, preferenceEnabled: true)
    )
    XCTAssertFalse(
      StormReportsVisibility.isSectionVisible(reportCount: 0, preferenceEnabled: true)
    )
  }

  // MARK: - Source image URLs

  func testAFDKeyMessageWithoutURLHasNilImageURL() {
    let items = LocalBriefingParser.assemble(
      cwa: "MEG",
      officeName: "Memphis, TN",
      afd: (id: "no-img", issuedAt: now.addingTimeInterval(-1800), text: Self.afdWithKeyMessages),
      pns: [],
      now: now
    )
    XCTAssertEqual(items.count, 2)
    XCTAssertTrue(items.allSatisfy { $0.imageURL == nil })
  }

  func testProductTextWithImageURLSetsImageURL() {
    let items = LocalBriefingParser.assemble(
      cwa: "MEG",
      officeName: "Memphis, TN",
      afd: nil,
      pns: [
        (
          id: "survey-photo", issuedAt: now.addingTimeInterval(-3600),
          text: Self.pnsStormSurveyWithImage
        )
      ],
      now: now
    )
    XCTAssertEqual(items.count, 1)
    XCTAssertEqual(
      items[0].imageURL,
      URL(string: "https://media.weather.gov/meg/survey.jpg")
    )
    XCTAssertEqual(items[0].sourceName, "NWS Memphis")
    XCTAssertEqual(items[0].id, "pns-survey-photo")
  }

  func testAFDProductWithImageURLSetsImageURLOnCards() {
    let items = LocalBriefingParser.assemble(
      cwa: "MEG",
      officeName: "Memphis, TN",
      afd: (
        id: "afd-img", issuedAt: now.addingTimeInterval(-1800),
        text: Self.afdWithKeyMessagesAndImage
      ),
      pns: [],
      now: now
    )
    XCTAssertEqual(items.count, 2)
    let expected = URL(string: "https://www.weather.gov/images/meg/outlook.png")
    XCTAssertEqual(items[0].imageURL, expected)
    XCTAssertEqual(items[1].imageURL, expected)
    XCTAssertEqual(items.map(\.id), ["afd-afd-img-km0", "afd-afd-img-km1"])
  }

  func testNonImageHTTPSLinksAreRejected() {
    let items = LocalBriefingParser.assemble(
      cwa: "MEG",
      officeName: "Memphis, TN",
      afd: nil,
      pns: [
        (
          id: "links", issuedAt: now.addingTimeInterval(-3600),
          text: Self.pnsWithNonImageLinks
        )
      ],
      now: now
    )
    XCTAssertEqual(items.count, 1)
    XCTAssertNil(items[0].imageURL)
  }

  func testFirstValidImageURLWins() {
    XCTAssertEqual(
      LocalBriefingParser.firstImageURL(
        in: """
          See https://forecast.weather.gov/product.php?site=NWS&issuedby=MEG&product=AFD
          then https://www.weather.gov/images/meg/survey.png
          and https://media.weather.gov/later.jpg
          """),
      URL(string: "https://www.weather.gov/images/meg/survey.png")
    )
  }

  func testJPEGExtensionOnArbitraryHTTPSHostIsKept() {
    XCTAssertEqual(
      LocalBriefingParser.firstImageURL(in: "Photo https://cdn.example.com/damage.jpeg"),
      URL(string: "https://cdn.example.com/damage.jpeg")
    )
  }

  func testMediaWeatherGovHostWithoutExtensionIsKept() {
    XCTAssertEqual(
      LocalBriefingParser.firstImageURL(
        in: "Graphic: https://media.weather.gov/meg/KMEG_storm_survey"),
      URL(string: "https://media.weather.gov/meg/KMEG_storm_survey")
    )
  }

  func testHTTPImageURLIsRejected() {
    XCTAssertNil(
      LocalBriefingParser.firstImageURL(in: "http://media.weather.gov/foo.jpg")
    )
  }

  func testTrailingPunctuationIsStrippedFromImageURL() {
    XCTAssertEqual(
      LocalBriefingParser.firstImageURL(in: "see https://media.weather.gov/foo.jpg."),
      URL(string: "https://media.weather.gov/foo.jpg")
    )
  }

  func testProductListDecodesGraph() throws {
    let json = """
      {
        "@graph": [
          {
            "id": "d7681823-d4be-4d15-93b2-e5d65d79dd0a",
            "issuanceTime": "2026-08-23T23:34:00+00:00",
            "productCode": "AFD",
            "issuingOffice": "KMEG"
          }
        ]
      }
      """.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(NWSTextProductCollection.self, from: json)
    XCTAssertEqual(decoded.graph.count, 1)
    XCTAssertEqual(decoded.graph[0].id, "d7681823-d4be-4d15-93b2-e5d65d79dd0a")
    XCTAssertNotNil(LocalBriefingParser.parseIssuance(decoded.graph[0].issuanceTime))
  }

  // MARK: - Fixtures

  private static let afdWithKeyMessages = """
    000
    FXUS64 KMEG 232334 AAA
    AFDMEG

    Area Forecast Discussion...UPDATED
    National Weather Service Memphis TN
    634 PM CDT Sun Aug 23 2026

    .KEY MESSAGES...
    Issued at 634 PM CDT Sun Aug 23 2026

    - Shower and thunderstorm chances increase late tonight into
      Monday, with organized severe weather not expected.

    - Additional chances for showers and thunderstorms are expected
      through midweek.

    &&

    .DISCUSSION...
    (This evening through next Saturday)
    Issued at 1206 PM CDT Sun Aug 23 2026

    A large area of high pressure remains parked over the Desert
    Southwest. Do not dump this as a briefing card.
    """

  private static let afdWithThreeKeyMessages = """
    000
    FXUS64 KMEG 232334
    AFDMEG

    Area Forecast Discussion
    National Weather Service Memphis TN
    634 PM CDT Sun Aug 23 2026

    .KEY MESSAGES...

    - Heat continues through the weekend with little relief overnight.

    - Flash flood risk rises Monday along slow-moving storms.

    - Overnight fog is possible in low-lying areas midweek.

    &&

    .DISCUSSION...
    Do not dump this as a briefing card.
    """

  private static let afdWithDuplicateKeyMessages = """
    000
    FXUS64 KMEG 232334
    AFDMEG

    Area Forecast Discussion
    National Weather Service Memphis TN
    634 PM CDT Sun Aug 23 2026

    .KEY MESSAGES...

    - Heat continues through the weekend.

    - Heat continues through the weekend.

    - Storm chances return Monday.

    &&
    """

  private static let afdWithOneKeyMessage = """
    000
    FXUS64 KMEG 232334
    AFDMEG

    Area Forecast Discussion
    National Weather Service Memphis TN
    634 PM CDT Sun Aug 23 2026

    .KEY MESSAGES...

    - Flash flood risk rises Monday along slow-moving storms

    &&
    """

  private static let afdWithoutKeyMessages = """
    000
    FXUS64 KMEG 232334
    AFDMEG

    Area Forecast Discussion
    National Weather Service Memphis TN
    634 PM CDT Sun Aug 23 2026

    .DISCUSSION...
    Showers and thunderstorms increase Monday. This is not a KEY MESSAGES block.
    """

  private static let pnsNWROutage = """
    000
    NOUS44 KMEG 211354
    PNSMEG

    Public Information Statement
    National Weather Service Memphis TN
    854 AM CDT Fri Aug 21 2026

    ...NOAA Weather Radio broadcast for Oxford, MS is unavailable...

    NOAA Weather Radio station KIH-52 operating on a frequency of
    162.55 MHz in Oxford, MS, is unavailable due to a communications
    outage.
    """

  private static let pnsStormSurvey = """
    000
    NOUS44 KMEG 170155
    PNSMEG

    Public Information Statement
    National Weather Service Memphis TN
    855 PM CDT Sat Aug 16 2026

    ...NWS Damage Survey for 08/16/26 Tornado Event...

    .TORNADO NEAR OLIVE BRANCH IN DESOTO COUNTY MISSISSIPPI...

    The National Weather Service has surveyed damage from Saturday's
    storms across DeSoto County.
    """

  private static let pnsStormSurveyWithImage = """
    000
    NOUS44 KMEG 170155
    PNSMEG

    Public Information Statement
    National Weather Service Memphis TN
    855 PM CDT Sat Aug 16 2026

    ...NWS Damage Survey for 08/16/26 Tornado Event...

    .TORNADO NEAR OLIVE BRANCH IN DESOTO COUNTY MISSISSIPPI...

    The National Weather Service has surveyed damage from Saturday's
    storms across DeSoto County.

    Survey photo:
    https://media.weather.gov/meg/survey.jpg
    """

  private static let pnsWithNonImageLinks = """
    000
    NOUS44 KMEG 170155
    PNSMEG

    Public Information Statement
    National Weather Service Memphis TN
    855 PM CDT Sat Aug 16 2026

    ...NWS Damage Survey for 08/16/26 Tornado Event...

    Full discussion:
    https://forecast.weather.gov/product.php?site=NWS&issuedby=MEG&product=PNS
    Office page: https://www.weather.gov/meg/
    Alert feed: https://api.weather.gov/alerts/active
    """

  private static let afdWithKeyMessagesAndImage = """
    000
    FXUS64 KMEG 232334 AAA
    AFDMEG

    Area Forecast Discussion...UPDATED
    National Weather Service Memphis TN
    634 PM CDT Sun Aug 23 2026

    .KEY MESSAGES...
    Issued at 634 PM CDT Sun Aug 23 2026

    - Shower and thunderstorm chances increase late tonight into
      Monday, with organized severe weather not expected.

    - Additional chances for showers and thunderstorms are expected
      through midweek.

    &&

    .DISCUSSION...
    Graphic: https://www.weather.gov/images/meg/outlook.png
    """

  private static let pnsFloodWatch = """
    000
    NOUS44 KMEG 232000
    PNSMEG

    Public Information Statement
    National Weather Service Memphis TN
    300 PM CDT Sun Aug 23 2026

    ...Flash Flood Watch for the Mid-South...

    Slow-moving storms may produce flooding in low-lying areas.
    """

  private static func pnsWithHeadline(_ headline: String) -> String {
    """
    000
    NOUS44 KMEG 232000
    PNSMEG

    Public Information Statement
    National Weather Service Memphis TN
    300 PM CDT Sun Aug 23 2026

    ...\(headline)...

    Additional storm details follow.
    """
  }
}
