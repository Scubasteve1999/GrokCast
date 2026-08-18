import XCTest

@testable import DayCast

final class RadarTimelineTests: XCTestCase {

  // MARK: - Helpers

  private func makeFrame(
    provider: RadarTileProvider = .rainViewer,
    kind: RadarFrame.Kind = .livePrecipitation,
    tileEpoch: Int = 0,
    timestamp: Date = Date(),
    urlSuffix: String = "/path/to/tiles"
  ) -> RadarFrame {
    RadarFrame(
      provider: provider,
      kind: kind,
      tileEpoch: tileEpoch,
      timestamp: timestamp,
      tileURLTemplates: ["https://example.com\(urlSuffix)/{z}/{x}/{y}"]
    )
  }

  private func makeTimeline(liveCount: Int = 0, forecastCount: Int = 0) -> RadarTimeline {
    let anchor = Date(timeIntervalSince1970: 0)
    let live = (0..<liveCount).map { i in
      makeFrame(
        kind: .livePrecipitation,
        tileEpoch: i,
        timestamp: anchor.addingTimeInterval(Double(i) * 600)
      )
    }
    let forecast = (0..<forecastCount).map { i in
      makeFrame(
        kind: .forecastPrecipitation,
        tileEpoch: i,
        timestamp: anchor.addingTimeInterval(Double(i) * 3600)
      )
    }
    return RadarTimeline(live: live, forecast: forecast)
  }

  // MARK: - frames(showingFuture:)

  func testFramesShowingFutureFalseReturnsLive() {
    let timeline = makeTimeline(liveCount: 3, forecastCount: 2)
    XCTAssertEqual(timeline.frames(showingFuture: false).count, 3)
  }

  func testFramesShowingFutureTrueReturnsForecast() {
    let timeline = makeTimeline(liveCount: 3, forecastCount: 2)
    XCTAssertEqual(timeline.frames(showingFuture: true).count, 2)
  }

  func testHasLiveAndHasForecast() {
    let empty = RadarTimeline()
    XCTAssertFalse(empty.hasLive)
    XCTAssertFalse(empty.hasForecast)

    let timeline = makeTimeline(liveCount: 1, forecastCount: 1)
    XCTAssertTrue(timeline.hasLive)
    XCTAssertTrue(timeline.hasForecast)
  }

  // MARK: - futureRelativeLabels(count:)

  func testFutureLabelsWithNoForecastReturnsQuestionMarks() {
    let timeline = makeTimeline(forecastCount: 0)
    XCTAssertEqual(timeline.futureRelativeLabels(count: 3), ["?", "?", "?"])
  }

  func testFutureLabelsCountZeroReturnsEmpty() {
    let timeline = makeTimeline(forecastCount: 4)
    XCTAssertTrue(timeline.futureRelativeLabels(count: 0).isEmpty)
  }

  func testFutureLabelsFirstIndexIsNow() {
    let timeline = makeTimeline(forecastCount: 4)
    let labels = timeline.futureRelativeLabels(count: 4)
    XCTAssertEqual(labels.first, "Now")
  }

  func testFutureLabelsUseHourlyStepFromFrameDelta() {
    // Each forecast frame is 1 hour apart, so labels should be +1h, +2h, +3h.
    let timeline = makeTimeline(forecastCount: 4)
    let labels = timeline.futureRelativeLabels(count: 4)
    XCTAssertEqual(labels, ["Now", "+1h", "+2h", "+3h"])
  }

  func testFutureLabelsWithSingleFrame() {
    let timeline = makeTimeline(forecastCount: 1)
    XCTAssertEqual(timeline.futureRelativeLabels(count: 1), ["Now"])
  }

  // MARK: - RadarFrame.forecastLabel(anchor:)

  func testForecastLabelNilAnchorReturnsDisplayTime() {
    let frame = makeFrame(timestamp: Date(timeIntervalSince1970: 0))
    XCTAssertFalse(
      frame.forecastLabel(anchor: nil, timeZone: TimeZone(identifier: "UTC")!).isEmpty)
  }

  func testLiveFrameClockUsesCityTimezoneNotDevice() {
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(secondsFromGMT: 0)!
    let date = utc.date(
      from: DateComponents(year: 2026, month: 8, day: 18, hour: 18, minute: 40))!
    let chicago = TimeZone(identifier: "America/Chicago")!
    let losAngeles = TimeZone(identifier: "America/Los_Angeles")!

    XCTAssertEqual(
      RadarDataset.displayTimeString(from: date, timeZone: chicago),
      "1:40 PM")
    XCTAssertEqual(
      RadarDataset.displayTimeString(from: date, timeZone: losAngeles),
      "11:40 AM")

    var timeline = RadarTimeline()
    timeline.live = [makeFrame(timestamp: date)]
    XCTAssertEqual(
      timeline.activeFrameLabels(showingFuture: false, timeZone: losAngeles),
      ["11:40 AM"])
    XCTAssertEqual(
      timeline.activeFrameLabels(showingFuture: false, timeZone: chicago),
      ["1:40 PM"])
  }

  func testForecastLabelAtOrBeforeAnchorReturnsNow() {
    let anchor = Date(timeIntervalSince1970: 1_000)
    let frame = makeFrame(timestamp: Date(timeIntervalSince1970: 900))
    XCTAssertEqual(frame.forecastLabel(anchor: anchor), "Now")
  }

  func testForecastLabelMinutesUnderAnHour() {
    let anchor = Date(timeIntervalSince1970: 0)
    let frame = makeFrame(timestamp: anchor.addingTimeInterval(30 * 60)) // +30m
    XCTAssertEqual(frame.forecastLabel(anchor: anchor), "+30m")
  }

  func testForecastLabelExactlyOneHour() {
    let anchor = Date(timeIntervalSince1970: 0)
    let frame = makeFrame(timestamp: anchor.addingTimeInterval(3600)) // +1h
    XCTAssertEqual(frame.forecastLabel(anchor: anchor), "+1h")
  }

  func testForecastLabelHoursAndMinutes() {
    let anchor = Date(timeIntervalSince1970: 0)
    let frame = makeFrame(timestamp: anchor.addingTimeInterval(90 * 60)) // +1h 30m
    XCTAssertEqual(frame.forecastLabel(anchor: anchor), "+1h 30m")
  }

  func testForecastLabelTwoHoursExact() {
    let anchor = Date(timeIntervalSince1970: 0)
    let frame = makeFrame(timestamp: anchor.addingTimeInterval(7200)) // +2h
    XCTAssertEqual(frame.forecastLabel(anchor: anchor), "+2h")
  }

  // MARK: - RadarFrame.tileKey

  func testRainViewerLiveTileKey() {
    let frame = makeFrame(
      provider: .rainViewer,
      kind: .livePrecipitation,
      tileEpoch: 42,
      urlSuffix: "/suffix-used-for-fingerprint"
    )
    XCTAssertTrue(frame.tileKey.hasPrefix("rv:radar:42:"))
  }

  func testRainViewerForecastTileKey() {
    let frame = makeFrame(
      provider: .rainViewer,
      kind: .forecastPrecipitation,
      tileEpoch: 7
    )
    XCTAssertTrue(frame.tileKey.hasPrefix("rv:nowcast:7:"))
  }

  func testXweatherLiveTileKey() {
    let frame = makeFrame(provider: .xweather, kind: .livePrecipitation, tileEpoch: 99)
    XCTAssertEqual(frame.tileKey, "xw:radar:99")
  }

  func testXweatherForecastTileKey() {
    let frame = makeFrame(provider: .xweather, kind: .forecastPrecipitation, tileEpoch: 5)
    XCTAssertEqual(frame.tileKey, "xw:fradar:5")
  }

  func testOpenWeatherMapLiveTileKey() {
    let frame = makeFrame(provider: .openWeatherMap, kind: .livePrecipitation, tileEpoch: 3)
    XCTAssertEqual(frame.tileKey, "owm:radar:3")
  }

  func testIEMTileKeyIncludesEpochAndFingerprint() {
    let frame = makeFrame(
      provider: .iem,
      kind: .livePrecipitation,
      tileEpoch: 12,
      urlSuffix: "/iem/site/product/scan"
    )
    XCTAssertTrue(frame.tileKey.hasPrefix("iem:12:"))
  }
}

final class RadarExplainCopyTests: XCTestCase {
  private func context(
    location: String = "Seattle",
    condition: String? = "Clear",
    precip: Int? = 0
  ) -> RadarExplainContext {
    RadarExplainContext(
      modeLabel: "Live",
      frameLabel: "Now",
      productName: "Rain",
      productTechnicalName: "composite reflectivity",
      locationName: location,
      locationID: UUID(),
      conditionText: condition,
      precipitationChance: precip
    )
  }

  func testZeroPrecipUsesLocalCopyAndDoesNotInventRainAtThePin() {
    let ctx = context(condition: "Clear", precip: 0)
    XCTAssertTrue(RadarExplainCopy.shouldUseLocalExplanation(ctx))
    let copy = RadarExplainCopy.localExplanation(for: ctx)
    XCTAssertTrue(copy.contains("Seattle"))
    XCTAssertTrue(copy.contains("Clear"))
    XCTAssertTrue(copy.contains("0%"))
    XCTAssertFalse(copy.localizedCaseInsensitiveContains("showers"))
    XCTAssertFalse(copy.localizedCaseInsensitiveContains("raining"))
    XCTAssertFalse(copy.localizedCaseInsensitiveContains("downpour"))
  }

  func testLocalCopyUsesTheSelectedConditionNotAHardcodedClear() {
    let copy = RadarExplainCopy.localExplanation(
      for: context(location: "Denver", condition: "Fog", precip: 0))
    XCTAssertTrue(copy.contains("currently Fog"))
    XCTAssertFalse(copy.contains("currently Clear"))
    XCTAssertTrue(copy.contains("Denver"))
  }

  func testMissingForecastDoesNotGuessPrecipitation() {
    let ctx = context(condition: nil, precip: nil)
    XCTAssertTrue(RadarExplainCopy.shouldUseLocalExplanation(ctx))
    let copy = RadarExplainCopy.localExplanation(for: ctx)
    XCTAssertTrue(copy.localizedCaseInsensitiveContains("will not guess"))
  }

  func testLowPrecipUsesLocalCopyAndDoesNotInventRain() {
    let ctx = context(condition: "Clear", precip: 2)
    XCTAssertTrue(RadarExplainCopy.shouldUseLocalExplanation(ctx))
    let copy = RadarExplainCopy.localExplanation(for: ctx)
    XCTAssertTrue(copy.contains("Clear"))
    XCTAssertTrue(copy.contains("2%"))
    XCTAssertTrue(copy.contains("labeled \"Rain\""))
    XCTAssertTrue(copy.contains("slight chance"))
    XCTAssertFalse(copy.localizedCaseInsensitiveContains("showers"))
    XCTAssertFalse(copy.localizedCaseInsensitiveContains("raining"))
  }

  func testFourteenPercentStillUsesLocalCopy() {
    XCTAssertTrue(
      RadarExplainCopy.shouldUseLocalExplanation(context(condition: "Overcast", precip: 14)))
  }

  func testMeaningfulPrecipKeepsGrokPath() {
    XCTAssertFalse(
      RadarExplainCopy.shouldUseLocalExplanation(context(condition: "Rain", precip: 20)))
    XCTAssertFalse(
      RadarExplainCopy.shouldUseLocalExplanation(context(condition: "Rain", precip: 80)))
  }

  func testLocalCopyUsesTheSelectedConditionAtLowPrecip() {
    let copy = RadarExplainCopy.localExplanation(
      for: context(location: "Olive Branch, MS", condition: "Fog", precip: 2))
    XCTAssertTrue(copy.contains("currently Fog"))
    XCTAssertFalse(copy.contains("currently Clear"))
  }

  func testActivePrecipKeepsGrokPath() {
    XCTAssertFalse(
      RadarExplainCopy.shouldUseLocalExplanation(context(condition: "Rain", precip: 80)))
  }

  func testPromptIncludesSelectedCityForecast() {
    let prompt = RadarExplainCopy.systemPrompt(for: context(condition: "Clear", precip: 0))
    XCTAssertTrue(prompt.contains("Clear"))
    XCTAssertTrue(prompt.contains("0%"))
    XCTAssertTrue(prompt.contains("Do not invent precipitation"))
  }

  func testDetectsInventedRainWhenForecastIsDry() {
    let ctx = context(condition: "Clear", precip: 0)
    XCTAssertTrue(
      RadarExplainCopy.inventsPrecipitationAtPin(
        "Showers are moving into Seattle this hour.", context: ctx))
    XCTAssertFalse(
      RadarExplainCopy.inventsPrecipitationAtPin(
        "The Rain product is a reflectivity layer. No precipitation is forecast here.",
        context: ctx))
  }
}
