import XCTest

@testable import DayCast

final class ShareAttributionTests: XCTestCase {

  func testAppStoreURLCarriesTheSurfaceAsCampaignToken() {
    let url = ShareAttribution.appStoreURL(for: .todayCard)
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
    let items = Dictionary(
      uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value ?? "") })

    XCTAssertEqual(components.host, "apps.apple.com")
    XCTAssertTrue(components.path.contains(ShareAttribution.appStoreID))
    XCTAssertEqual(items["ct"], "share_today")
  }

  func testEverySurfaceProducesADistinctCampaignToken() {
    let surfaces: [ShareAttribution.Surface] = [
      .todayCard, .alertsSummary, .radarExplanation, .stormReport, .stormPhoto,
    ]
    let tokens = Set(surfaces.map(\.rawValue))
    XCTAssertEqual(tokens.count, surfaces.count, "campaign tokens must not collide")
  }

  func testProviderTokenIsIncludedWhenSet() {
    let url = ShareAttribution.appStoreURL(for: .stormReport)
    if let token = ShareAttribution.providerToken {
      XCTAssertTrue(url.absoluteString.contains("pt=\(token)"))
    } else {
      // The link must still work before the token is configured — otherwise
      // shipping without it would break sharing, not just attribution.
      XCTAssertFalse(url.absoluteString.contains("pt="))
    }
  }

  func testURLMatchesTheLinkAppStoreConnectGeneratedByteForByte() {
    // Apple's campaign format: /app/apple-store/id{app}?pt={provider}&ct={surface}&mt=8.
    // App ID remapped 2026-08-14 when listing 6780682022 was replaced by 6798461672.
    // pt is account-level and was kept.
    let expected =
      "https://apps.apple.com/app/apple-store/id6798461672?pt=128792554&ct=share_today&mt=8"

    XCTAssertEqual(ShareAttribution.appStoreURL(for: .todayCard).absoluteString, expected)
  }

  func testReviewURLsPointAtTheLiveListing() {
    XCTAssertEqual(ShareAttribution.appStoreID, "6798461672")
    XCTAssertTrue(AppReviewPrompt.appStoreURL.absoluteString.contains(ShareAttribution.appStoreID))
    XCTAssertEqual(
      AppReviewPrompt.writeReviewURL.absoluteString,
      "https://apps.apple.com/app/id6798461672?action=write-review")
    XCTAssertEqual(AppLinks.appStore, AppReviewPrompt.appStoreURL)
    XCTAssertEqual(AppLinks.writeReview, AppReviewPrompt.writeReviewURL)
  }

  func testFooterEmbedsAnOpenableLink() {
    let footer = ShareAttribution.footer(for: .alertsSummary)
    XCTAssertTrue(footer.contains("DayCast"))

    let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    let matches = detector.matches(
      in: footer, range: NSRange(footer.startIndex..., in: footer))
    XCTAssertEqual(matches.count, 1, "recipients need exactly one tappable route to the App Store")
  }

  func testSharedWeatherTextEndsWithAnInstallLink() {
    // The whole point of the share loop: a recipient must be able to get the app.
    let text = ShareableBriefText.weatherBrief(
      locationName: "Olive Branch, MS",
      temperatureLine: "78°F",
      condition: "Partly cloudy",
      brief: "Storms possible after 4pm."
    )
    XCTAssertTrue(text.contains("apps.apple.com"))
    XCTAssertTrue(text.contains("ct=share_today"))
  }

  func testEachShareSurfaceTagsItsOwnText() {
    let alerts = ShareableBriefText.alertsSummary(
      locationName: "Memphis, TN", summary: "Severe thunderstorm warning until 6pm.",
      alertEvents: ["Severe Thunderstorm Warning"])
    XCTAssertTrue(alerts.contains("ct=share_alerts"))

    let storm = ShareableBriefText.stormSpotterReport(
      locationName: "Southaven, MS", observerNotes: nil, analysis: "Shelf cloud, outflow dominant.")
    XCTAssertTrue(storm.contains("ct=share_storm_report"))
  }
}
