import XCTest

@testable import GrokCast

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

  func testProviderTokenIsOmittedWhenUnset() {
    // The link has to work before the provider token is configured, otherwise
    // shipping without it would break sharing rather than just attribution.
    let url = ShareAttribution.appStoreURL(for: .stormReport)
    if ShareAttribution.providerToken == nil {
      XCTAssertFalse(url.absoluteString.contains("pt="))
    }
    XCTAssertTrue(url.absoluteString.hasPrefix("https://apps.apple.com/app/id"))
  }

  func testFooterEmbedsAnOpenableLink() {
    let footer = ShareAttribution.footer(for: .alertsSummary)
    XCTAssertTrue(footer.contains("SpotterCast"))

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
