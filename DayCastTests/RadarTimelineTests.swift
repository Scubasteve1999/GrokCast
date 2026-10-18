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
  // MARK: - NOAA HRRR forecast (IEM)

  private func utc(_ text: String) -> Date {
    ISO8601DateFormatter().date(from: text)!
  }

  func testHRRRFramesUseValidTimesAndPinnedRunLeads() {
    // 04Z run, viewed at 05:47Z: frames start at 05Z ("Now") with lead +60m.
    let initTime = utc("2026-10-18T04:00:00Z")
    let frames = IEMHRRRForecastService.frames(initTime: initTime, now: utc("2026-10-18T05:47:16Z"))
    XCTAssertEqual(frames.count, RadarTimelineConfig.forecastMaxFrames)
    XCTAssertEqual(frames.first?.timestamp, utc("2026-10-18T05:00:00Z"))
    XCTAssertEqual(frames.last?.timestamp, utc("2026-10-18T16:00:00Z"))
    XCTAssertEqual(
      frames.first?.tileURLTemplates,
      [
        "https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/hrrr::REFD-F0060-202610180400/{z}/{x}/{y}.png"
      ])
    XCTAssertTrue(frames.last!.tileURLTemplates[0].contains("REFD-F0720-202610180400"))
    XCTAssertTrue(frames.allSatisfy { $0.provider == .hrrr && $0.kind == .forecastPrecipitation })
    XCTAssertEqual(Set(frames.map(\.tileKey)).count, frames.count, "each frame needs its own tiles")
  }

  func testHRRRDropsFramesBeyondTheRunsEighteenHours() {
    let initTime = utc("2026-10-18T00:00:00Z")
    let frames = IEMHRRRForecastService.frames(initTime: initTime, now: utc("2026-10-18T10:30:00Z"))
    // 10Z…18Z are within +18h of 00Z; 19Z…21Z are not.
    XCTAssertEqual(frames.count, 9)
    XCTAssertTrue(frames.last!.tileURLTemplates[0].contains("REFD-F1080-"))
  }

  func testHRRRReadsTheLatestRunFromIEM() {
    let json = """
      {"model_init_utc": "2026-10-18T04:00:00Z", "forecast_minute": 0.0, "model_forecast_utc": "2026-10-18T04:00:00Z"}
      """.data(using: .utf8)!
    XCTAssertEqual(IEMHRRRForecastService.parseInitTime(from: json), utc("2026-10-18T04:00:00Z"))
    XCTAssertNil(IEMHRRRForecastService.parseInitTime(from: Data("nope".utf8)))
  }

  func testHRRRLabelsItselfAsAModelForecast() {
    XCTAssertTrue(RadarTileProvider.hrrr.forecastFooterLabel.contains("HRRR"))
    XCTAssertTrue(RadarTileProvider.hrrr.forecastFooterLabel.localizedCaseInsensitiveContains("model"))
  }

  // MARK: - HRRR run selection

  /// Counts lookups so cache tests can tell a network call from a cache hit.
  private actor LookupLog {
    var latestCalls = 0
    var probedLeads: [Int] = []
    func noteLatest() { latestCalls += 1 }
    func noteProbe(_ lead: Int) { probedLeads.append(lead) }
  }

  private func source(
    latest: Date?, served: Set<Int>, log: LookupLog
  ) -> IEMHRRRForecastService.RunSource {
    IEMHRRRForecastService.RunSource(
      latestInitTime: {
        await log.noteLatest()
        return latest
      },
      tileIsServed: { _, lead in
        await log.noteProbe(lead)
        return served.contains(lead)
      })
  }

  func testHRRRFallsBackToThePreviousRunWhenTheNewestIsNotRendered() async {
    // 05:47Z: newest run 04Z needs F0720 (16Z); it is not rendered yet. 03Z needs F0780.
    let log = LookupLog()
    let run = await IEMHRRRForecastService.selectRun(
      now: utc("2026-10-18T05:47:00Z"),
      source: source(latest: utc("2026-10-18T04:00:00Z"), served: [780], log: log))
    XCTAssertEqual(run, utc("2026-10-18T03:00:00Z"))
    let probed = await log.probedLeads
    XCTAssertEqual(probed, [720, 780])
  }

  func testHRRRReportsNoRunWhenNeitherIsRendered() async {
    let log = LookupLog()
    let run = await IEMHRRRForecastService.selectRun(
      now: utc("2026-10-18T05:47:00Z"),
      source: source(latest: utc("2026-10-18T04:00:00Z"), served: [], log: log))
    XCTAssertNil(run)
  }

  @MainActor
  func testHRRRRunCacheHoldsWithinTheHourAndReProbesTheNext() async {
    IEMHRRRForecastService.resetRunCacheForTesting()
    defer { IEMHRRRForecastService.resetRunCacheForTesting() }
    let log = LookupLog()
    let src = source(latest: utc("2026-10-18T04:00:00Z"), served: [720, 780], log: log)
    _ = await IEMHRRRForecastService.usableRun(now: utc("2026-10-18T05:56:00Z"), source: src)
    _ = await IEMHRRRForecastService.usableRun(now: utc("2026-10-18T05:59:00Z"), source: src)
    var calls = await log.latestCalls
    XCTAssertEqual(calls, 1, "same hour, inside the TTL: cache hit")
    // 06:01Z is inside the 5-minute TTL but a new hour, so the last lead is now F0780.
    _ = await IEMHRRRForecastService.usableRun(now: utc("2026-10-18T06:01:00Z"), source: src)
    calls = await log.latestCalls
    XCTAssertEqual(calls, 2)
    let probed = await log.probedLeads
    XCTAssertEqual(probed.last, 780)
  }

  @MainActor
  func testHRRRRemembersAFailureBrieflyThenRetries() async {
    IEMHRRRForecastService.resetRunCacheForTesting()
    defer { IEMHRRRForecastService.resetRunCacheForTesting() }
    let log = LookupLog()
    let src = source(latest: utc("2026-10-18T04:00:00Z"), served: [], log: log)
    let failedAt = utc("2026-10-18T05:30:00Z")
    _ = await IEMHRRRForecastService.usableRun(now: failedAt, source: src)
    _ = await IEMHRRRForecastService.usableRun(
      now: failedAt.addingTimeInterval(IEMHRRRForecastService.failureCacheTTL - 1), source: src)
    var calls = await log.latestCalls
    XCTAssertEqual(calls, 1, "callers inside the failure window do not wait out timeouts again")
    _ = await IEMHRRRForecastService.usableRun(
      now: failedAt.addingTimeInterval(IEMHRRRForecastService.failureCacheTTL), source: src)
    calls = await log.latestCalls
    XCTAssertEqual(calls, 2)
  }

  @MainActor
  func testHRRRCallersArrivingTogetherShareOneLookup() async {
    IEMHRRRForecastService.resetRunCacheForTesting()
    defer { IEMHRRRForecastService.resetRunCacheForTesting() }
    let log = LookupLog()
    let src = source(latest: utc("2026-10-18T04:00:00Z"), served: [720], log: log)
    let now = utc("2026-10-18T05:47:00Z")
    async let first = IEMHRRRForecastService.usableRun(now: now, source: src)
    async let second = IEMHRRRForecastService.usableRun(now: now, source: src)
    let runs = await [first, second]
    XCTAssertEqual(runs, [utc("2026-10-18T04:00:00Z"), utc("2026-10-18T04:00:00Z")])
    let calls = await log.latestCalls
    XCTAssertEqual(calls, 1)
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
