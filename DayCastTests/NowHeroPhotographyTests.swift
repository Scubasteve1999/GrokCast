import XCTest

@testable import DayCast

final class NowHeroPhotographyTests: XCTestCase {
  func testNowHeroIsPhotographyNotASystemGlyph() {
    XCTAssertFalse(NowHeroPhotography.glyphIsSectionFace)

    let samples: [(Int?, Bool)] = [
      (0, true), (0, false), (2, true), (3, true), (45, true),
      (61, true), (71, false), (95, true), (nil, true),
    ]
    for (code, isDay) in samples {
      switch NowHeroPhotography.treatment(conditionCode: code, isDay: isDay) {
      case .systemGlyph(let symbol):
        XCTFail("Now face must not be SF Symbol \(symbol) for code \(String(describing: code))")
      case .photography(let asset):
        XCTAssertTrue(
          NowHeroPhotography.knownAssetNames.contains(asset),
          "Unknown still \(asset) for code \(String(describing: code))"
        )
        XCTAssertEqual(
          asset,
          NowHeroPhotography.stillName(conditionCode: code, isDay: isDay)
        )
        XCTAssertFalse(asset.hasPrefix("cloud"))
        XCTAssertFalse(asset.contains("sun.max"))
      }
    }
  }

  func testHeroPlateUsesFeedWidthNotTheStillIntrinsicSize() {
    let feedWidth: CGFloat = 353
    let phone = NowHeroPhotography.plateSize(containerWidth: feedWidth)
    XCTAssertEqual(phone.width, feedWidth)
    XCTAssertEqual(phone.height, NowHeroPhotography.plateHeight)
    XCTAssertEqual(phone.height, TodayGlanceLayout.nowBudgetHeight)
    XCTAssertNotEqual(phone.width, phone.height)
    let wide = NowHeroPhotography.plateSize(containerWidth: 390)
    XCTAssertEqual(wide.width, 390)
    XCTAssertEqual(wide.height, phone.height)
    XCTAssertEqual(NowHeroPhotography.plateSize(containerWidth: 0).width, 0)
  }

  func testStageSizeUsesScreenBoundsNotJPEGIntrinsic() {
    let screen = CGSize(width: 393, height: 852)
    let size = NowHeroPhotography.stageSize(containerSize: screen)
    XCTAssertEqual(size.width, 393)
    XCTAssertEqual(size.height, 852)
    XCTAssertEqual(
      NowHeroPhotography.stageSize(containerSize: .zero),
      .zero
    )
  }

  func testConditionMapsOntoTheBundledCinematicStills() {
    XCTAssertEqual(
      NowHeroPhotography.stillName(conditionCode: 0, isDay: true),
      "NewsHeroSky"
    )
    XCTAssertEqual(
      NowHeroPhotography.stillName(conditionCode: 95, isDay: true),
      "NewsHeroLightning"
    )
    XCTAssertEqual(
      NowHeroPhotography.stillName(conditionCode: 45, isDay: true),
      "NewsHeroHaze"
    )
    XCTAssertEqual(
      NowHeroPhotography.treatment(conditionCode: 61, isDay: true),
      .photography(assetName: "NewsHeroStorm")
    )
  }

  func testNewsRailPrefersRealImageURLAndNeverInventStockHeroes() {
    let photo = URL(string: "https://media.weather.gov/meg/survey.jpg")!
    let withPhoto = LocalBriefingItem(
      id: "pns-photo",
      title: "Tornado survey for DeSoto County",
      sourceName: "NWS Memphis",
      issuedAt: Date(timeIntervalSince1970: 1_787_515_000),
      url: LocalBriefingParser.productPageURL(cwa: "MEG", productCode: "PNS"),
      productCode: "PNS",
      officeID: "MEG",
      imageURL: photo
    )
    XCTAssertEqual(YourNewsPhotography.cardImageURL(for: withPhoto), photo)

    let textOnly = LocalBriefingItem(
      id: "afd-km0",
      title: "Lightning and flood threat this afternoon",
      sourceName: "NWS Memphis",
      issuedAt: Date(timeIntervalSince1970: 1_787_515_000),
      url: LocalBriefingParser.productPageURL(cwa: "MEG", productCode: "AFD"),
      productCode: "AFD",
      officeID: "MEG",
      imageURL: nil
    )
    XCTAssertNil(YourNewsPhotography.cardImageURL(for: textOnly))
    XCTAssertNil(YourNewsPhotography.bundledStockHeroName(matchingTitle: textOnly.title))
    XCTAssertNil(YourNewsPhotography.bundledStockHeroName(matchingTitle: "TORNADO WARNING"))
    XCTAssertNil(YourNewsPhotography.bundledStockHeroName(matchingTitle: "Flooding rain"))
  }

  func testParserDoesNotInventImageURLsFromStormKeywords() {
    let now = Date()
    let items = LocalBriefingParser.assemble(
      cwa: "MEG",
      officeName: "Memphis, TN",
      afd: nil,
      pns: [
        (
          id: "keywords",
          issuedAt: now.addingTimeInterval(-3600),
          text: """
            National Weather Service Memphis TN
            TORNADO survey. Lightning. Flooding rain. No photo URL in this product.
            """
        )
      ],
      now: now
    )
    XCTAssertEqual(items.count, 1)
    XCTAssertNil(items[0].imageURL)
    XCTAssertNil(YourNewsPhotography.cardImageURL(for: items[0]))
    XCTAssertNil(YourNewsPhotography.bundledStockHeroName(matchingTitle: items[0].title))
  }
}
