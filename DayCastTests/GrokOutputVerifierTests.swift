import XCTest

@testable import DayCast

/// The app half of `/v1/verify`. The contract that matters: any failure is
/// `.unavailable`, and `.unavailable` never blocks — the verifier is additive.
@MainActor
final class GrokOutputVerifierTests: XCTestCase {

  private let auth = GrokAuthContext(
    baseURL: URL(string: "https://proxy.example.com/v1")!,
    authorizationHeader: "Bearer test-secret",
    tier: .pro,
    transactionJWS: "signed.transaction.jws"
  )

  private func body(_ request: URLRequest?) throws -> [String: Any] {
    let data = try XCTUnwrap(request?.httpBody)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  // MARK: - Request

  func testBriefRequestCarriesProxyAuthAndOnlyTheText() throws {
    let request = GrokOutputVerifier.request(for: .brief("Leave extra time tonight."), auth: auth)

    XCTAssertEqual(request?.url?.absoluteString, "https://proxy.example.com/v1/verify")
    XCTAssertEqual(request?.httpMethod, "POST")
    XCTAssertEqual(request?.value(forHTTPHeaderField: "Authorization"), "Bearer test-secret")
    XCTAssertEqual(
      request?.value(forHTTPHeaderField: GrokAuthContext.transactionHeader), "signed.transaction.jws")
    XCTAssertEqual(request?.timeoutInterval, GrokOutputVerifier.timeout)
    let json = try body(request)
    XCTAssertEqual(json["kind"] as? String, "brief")
    XCTAssertEqual(json["text"] as? String, "Leave extra time tonight.")
    XCTAssertNil(json["pin"])
  }

  func testRadarRequestSendsTheRawChanceForTheProxyToBucket() throws {
    let request = GrokOutputVerifier.request(
      for: .radar("Rain over Austin.", location: "Austin", condition: "Partly cloudy",
        precipitationChance: 25),
      auth: auth)
    let pin = try XCTUnwrap(try body(request)["pin"] as? [String: Any])
    XCTAssertEqual(pin["location"] as? String, "Austin")
    XCTAssertEqual(pin["condition"] as? String, "Partly cloudy")
    XCTAssertEqual(pin["precipitation_chance"] as? Int, 25)
  }

  func testSubjectsTheProxyWouldRejectSkipTheRoundTrip() {
    XCTAssertNil(GrokOutputVerifier.request(for: .brief("   "), auth: auth))
    XCTAssertNil(
      GrokOutputVerifier.request(
        for: .brief(String(repeating: "a", count: GrokOutputVerifier.maxTextLength + 1)), auth: auth))
    XCTAssertNil(
      GrokOutputVerifier.request(
        for: .radar("Text", location: "Austin", condition: "Rain", precipitationChance: 101),
        auth: auth))
    XCTAssertNil(
      GrokOutputVerifier.request(
        for: .radar("Text", location: "", condition: "Rain", precipitationChance: 50), auth: auth))
  }

  // MARK: - Verdict

  func testPassAndBlockVerdictsParse() {
    XCTAssertEqual(
      GrokOutputVerifier.verdict(statusCode: 200, data: Data(#"{"verdict":"pass","reasons":[]}"#.utf8)),
      .pass)
    XCTAssertEqual(
      GrokOutputVerifier.verdict(
        statusCode: 200,
        data: Data(#"{"verdict":"block","reasons":["unsupported_precipitation"]}"#.utf8)),
      .block(reasons: ["unsupported_precipitation"]))
  }

  func testAnythingElseIsUnavailableAndNeverBlocks() {
    let cases: [(Int?, String)] = [
      (502, #"{"error":{"message":"Verification is temporarily unavailable."}}"#),
      (429, #"{"verdict":"block"}"#),
      (200, "not json"),
      (200, #"{"verdict":"maybe"}"#),
      (nil, ""),
    ]
    for (status, payload) in cases {
      let verdict = GrokOutputVerifier.verdict(statusCode: status, data: Data(payload.utf8))
      XCTAssertEqual(verdict, .unavailable, "\(String(describing: status)) \(payload)")
      XCTAssertFalse(verdict.blocks)
    }
  }

  func testWithoutProTheVerifierStaysSilent() async {
    // Tests run without a Pro transaction, so this must not touch the network.
    XCTAssertFalse(SubscriptionManager.shared.isPro)
    let verdict = await GrokOutputVerifier.verify(.brief("It's raining in Austin."))
    XCTAssertEqual(verdict, .unavailable)
  }

  // MARK: - Explain Radar subject

  private func radarContext(condition: String?, precip: Int?) -> RadarExplainContext {
    RadarExplainContext(
      modeLabel: "Live",
      frameLabel: "Now",
      productName: "Rain",
      productTechnicalName: "composite reflectivity",
      locationName: "Austin",
      locationID: UUID(),
      conditionText: condition,
      precipitationChance: precip
    )
  }

  func testRadarSubjectUsesThePinForecastWhenLoaded() {
    XCTAssertEqual(
      RadarExplainCopy.verifierSubject(
        "Showers moving in.", context: radarContext(condition: "Showers", precip: 70)),
      .radar("Showers moving in.", location: "Austin", condition: "Showers", precipitationChance: 70))
  }

  func testRadarSubjectFallsBackToABriefCheckWithoutAForecast() {
    XCTAssertEqual(
      RadarExplainCopy.verifierSubject(
        "Showers moving in.", context: radarContext(condition: nil, precip: 70)),
      .brief("Showers moving in."))
  }
}
