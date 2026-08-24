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

  func testAFDMEGKeyMessagesYieldsFirstBulletAndProductURL() {
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
    XCTAssertEqual(items.count, 1)
    let card = items[0]
    XCTAssertEqual(card.id, "afd-d7681823-d4be-4d15-93b2-e5d65d79dd0a")
    XCTAssertEqual(
      card.title,
      "Shower and thunderstorm chances increase late tonight into Monday, with organized severe weather not expected."
    )
    XCTAssertEqual(card.sourceName, "NWS Memphis")
    XCTAssertEqual(card.productCode, "AFD")
    XCTAssertEqual(card.officeID, "MEG")
    XCTAssertTrue(card.url.absoluteString.contains("issuedby=MEG"), card.url.absoluteString)
    XCTAssertTrue(card.url.absoluteString.contains("product=AFD"), card.url.absoluteString)
    XCTAssertEqual(card.relativeIssuedLabel(relativeTo: now), "2h ago")
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
    XCTAssertEqual(items.count, 1)
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
    XCTAssertEqual(items[0].productCode, "AFD")
    XCTAssertEqual(items[1].productCode, "PNS")
    XCTAssertEqual(items[2].productCode, "PNS")
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

  // MARK: - Hero stills

  func testHeroKeywordTable() {
    XCTAssertEqual(
      LocalBriefingHero.matching(title: "Thunderstorms increase late tonight"),
      .storm
    )
    XCTAssertEqual(
      LocalBriefingHero.matching(
        title: "NWS Damage Survey for 08/16/26 Tornado Event"
      ),
      .storm
    )
    XCTAssertEqual(
      LocalBriefingHero.matching(title: "Tornado warning until 8 PM"),
      .storm
    )
    XCTAssertEqual(
      LocalBriefingHero.matching(title: "Lightning and tornado debris"),
      .lightning
    )
    XCTAssertEqual(
      LocalBriefingHero.matching(title: "Flash flood warning for DeSoto County"),
      .flood
    )
    XCTAssertEqual(
      LocalBriefingHero.matching(title: "Wildfire smoke reduces visibility"),
      .haze
    )
    XCTAssertEqual(
      LocalBriefingHero.matching(title: "Dense smoke and haze across the Mid-South"),
      .haze
    )
    XCTAssertEqual(
      LocalBriefingHero.matching(title: "High pressure remains parked over the region"),
      .dawn
    )
    XCTAssertEqual(
      LocalBriefingHero.matching(title: "A quiet pattern continues"),
      .sky
    )
  }

  func testHeroUniquenessDoesNotCloneThunderstormCrops() {
    let titles = [
      "Thunderstorms increase late tonight into Monday",
      "Additional chances for showers and thunderstorms through midweek",
      "Flash flood watch for the Mid-South",
    ]
    XCTAssertEqual(
      LocalBriefingHero.uniqueHeroes(for: titles),
      [.storm, .lightning, .flood]
    )
  }

  func testHeroAssetNamesMatchCatalog() {
    XCTAssertEqual(LocalBriefingHero.storm.assetName, "NewsHeroStorm")
    XCTAssertEqual(LocalBriefingHero.lightning.assetName, "NewsHeroLightning")
    XCTAssertEqual(LocalBriefingHero.sky.assetName, "NewsHeroSky")
    XCTAssertEqual(LocalBriefingHero.flood.assetName, "NewsHeroFlood")
    XCTAssertEqual(LocalBriefingHero.haze.assetName, "NewsHeroHaze")
    XCTAssertEqual(LocalBriefingHero.dawn.assetName, "NewsHeroDawn")
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
}
