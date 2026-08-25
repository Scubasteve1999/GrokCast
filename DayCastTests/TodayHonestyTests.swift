import XCTest

@testable import DayCast

final class TodayHonestyTests: XCTestCase {
  private let fetchedAt = Date(timeIntervalSince1970: 1_700_000_000)

  func testUpdatedLabelJustNowUnderOneMinute() {
    let now = fetchedAt.addingTimeInterval(12)
    XCTAssertEqual(
      WidgetRelativeTime.updatedLabel(for: fetchedAt, relativeTo: now),
      "Updated just now")
  }

  func testUpdatedLabelMinutesUntilThreeHours() {
    let now = fetchedAt.addingTimeInterval(12 * 60)
    XCTAssertEqual(
      WidgetRelativeTime.updatedLabel(for: fetchedAt, relativeTo: now),
      "Updated 12m ago")
    let almostStale = fetchedAt.addingTimeInterval(179 * 60)
    XCTAssertEqual(
      WidgetRelativeTime.updatedLabel(for: fetchedAt, relativeTo: almostStale),
      "Updated 179m ago")
  }

  func testUpdatedLabelHoursAfterThreeHours() {
    let now = fetchedAt.addingTimeInterval(3 * 3600)
    XCTAssertEqual(
      WidgetRelativeTime.updatedLabel(for: fetchedAt, relativeTo: now),
      "Updated 3h ago")
    XCTAssertTrue(WidgetRelativeTime.isStale(fetchedAt, relativeTo: now.addingTimeInterval(1)))
    XCTAssertFalse(WidgetRelativeTime.isStale(fetchedAt, relativeTo: now))
  }

  func testHRRRSoftFailKeepsOriginalFetchedAt() {
    let previous = hrrrContext(fetchedAt: fetchedAt)
    let now = fetchedAt.addingTimeInterval(20 * 60)
    let kept = ShortTermPrecipContext.keepingLastGood(
      previous, locationID: previous.locationID, at: now)
    XCTAssertEqual(kept.fetchedAt, fetchedAt)
    XCTAssertTrue(kept.hasHRRRSlots)
    XCTAssertEqual(kept.source, .hrrr)
  }

  func testHRRRSoftFailDoesNotStampNow() {
    let previous = hrrrContext(fetchedAt: fetchedAt)
    let now = fetchedAt.addingTimeInterval(10 * 60)
    let kept = ShortTermPrecipContext.keepingLastGood(
      previous, locationID: previous.locationID, at: now)
    XCTAssertNotEqual(kept.fetchedAt, now)
  }

  func testHRRRSoftFailDropsAfter45Minutes() {
    let previous = hrrrContext(fetchedAt: fetchedAt)
    let atCutoff = fetchedAt.addingTimeInterval(ShortTermPrecipContext.maxUsableAge)
    let dropped = ShortTermPrecipContext.keepingLastGood(
      previous, locationID: previous.locationID, at: atCutoff)
    XCTAssertFalse(dropped.hasHRRRSlots)
    XCTAssertEqual(dropped.source, .none)
    XCTAssertTrue(dropped.slots.isEmpty)
  }

  func testHRRRStillUsableJustUnder45Minutes() {
    let previous = hrrrContext(fetchedAt: fetchedAt)
    let now = fetchedAt.addingTimeInterval(ShortTermPrecipContext.maxUsableAge - 1)
    XCTAssertTrue(previous.isUsableHRRR(at: now))
    let kept = ShortTermPrecipContext.keepingLastGood(
      previous, locationID: previous.locationID, at: now)
    XCTAssertTrue(kept.hasHRRRSlots)
    XCTAssertEqual(kept.fetchedAt, fetchedAt)
  }

  func testStaleHRRRIsNotUsableForDisplay() {
    let previous = hrrrContext(fetchedAt: fetchedAt)
    let now = fetchedAt.addingTimeInterval(46 * 60)
    XCTAssertFalse(previous.isUsableHRRR(at: now))
  }

  func testSoftFailOtherLocationClearsHRRR() {
    let previous = hrrrContext(fetchedAt: fetchedAt)
    let cleared = ShortTermPrecipContext.keepingLastGood(
      previous, locationID: "other-city", at: fetchedAt)
    XCTAssertFalse(cleared.hasHRRRSlots)
    XCTAssertEqual(cleared.locationID, "other-city")
  }

  func testErrorBannerLeadsFeedRows() {
    let items: [FeedItem] = [.now, .hourly, .daily, .nearby]
    let rows = FeedAssembler.rows(
      items: items, weatherError: "The weather service timed out. Tap RETRY in a moment.")
    XCTAssertEqual(rows.first, .errorBanner)
    XCTAssertEqual(Array(rows.dropFirst()), items.map(TodayFeedRow.item))
  }

  func testErrorBannerSitsAboveNowNotAfterSunMoon() {
    let items = FeedItem.defaultOrder
    let rows = FeedAssembler.rows(items: items, weatherError: "No internet connection.")
    XCTAssertEqual(rows.first, .errorBanner)
    XCTAssertEqual(rows.dropFirst().first, .item(.now))
    XCTAssertTrue(rows.contains(.item(.now)))
    XCTAssertEqual(rows.last, .item(.nearby))
    XCTAssertNotEqual(rows.last, .errorBanner)
  }

  func testEmptyErrorOmitsBannerRow() {
    XCTAssertEqual(
      FeedAssembler.rows(items: [.now], weatherError: nil),
      [.item(.now)])
    XCTAssertEqual(
      FeedAssembler.rows(items: [.now], weatherError: ""),
      [.item(.now)])
  }

  private func hrrrContext(fetchedAt: Date) -> ShortTermPrecipContext {
    ShortTermPrecipContext(
      locationID: "loc-olive",
      fetchedAt: fetchedAt,
      source: .hrrr,
      slots: [
        MinutelyForecast(time: fetchedAt, precipitation: 0.12, precipChance: 80)
      ],
      summary: nil
    )
  }
}
