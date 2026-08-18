import CoreLocation
import MapKit
import XCTest

@testable import DayCast

final class CitySearchTests: XCTestCase {
  func testWorldwideRequestDoesNotClampToALocalCity() {
    let request = CitySearch.makeMapKitRequest(query: "Seattle")
    XCTAssertEqual(request.naturalLanguageQuery, "Seattle")
    XCTAssertEqual(request.resultTypes, .address)
    XCTAssertGreaterThanOrEqual(request.region.span.latitudeDelta, 80)
    XCTAssertGreaterThanOrEqual(request.region.span.longitudeDelta, 160)
    XCTAssertEqual(request.regionPriority, .default)
  }

  func testEmptyMessageIncludesTheQueryAndIsNotLocalOnly() {
    let message = CitySearch.emptyMessage(for: "  Seattle  ")
    XCTAssertTrue(message.contains("Seattle"))
    XCTAssertFalse(message.localizedCaseInsensitiveContains("Memphis"))
    XCTAssertFalse(message.localizedCaseInsensitiveContains("Nashville"))
  }

  func testDisplayNamePrefersCityAndState() {
    XCTAssertEqual(
      CitySearch.displayName(
        city: "Seattle", administrativeArea: "WA", country: "United States", fallback: "Seattle"),
      "Seattle, WA")
    XCTAssertEqual(
      CitySearch.displayName(
        city: "London", administrativeArea: nil, country: "United Kingdom", fallback: "London"),
      "London, United Kingdom")
    XCTAssertEqual(
      CitySearch.displayName(
        city: nil, administrativeArea: "WA", country: nil, fallback: "Space Needle"),
      "Space Needle")
  }

  func testResultRejectsInvalidCoordinatesAndBlankNames() {
    XCTAssertNil(CitySearch.result(name: "Seattle, WA", subtitle: nil, latitude: .nan, longitude: 0))
    XCTAssertNil(CitySearch.result(name: "   ", subtitle: nil, latitude: 47.6, longitude: -122.3))
    XCTAssertEqual(
      CitySearch.result(name: " Seattle, WA ", subtitle: nil, latitude: 47.6062, longitude: -122.3321)?
        .name,
      "Seattle, WA")
  }

  func testDedupeCollapsesNearDuplicateCities() {
    let seattle = CitySearch.result(
      name: "Seattle, WA", subtitle: nil, latitude: 47.6062, longitude: -122.3321)!
    let seattleDup = CitySearch.result(
      name: "Seattle, WA", subtitle: "King County", latitude: 47.6100, longitude: -122.3300)!
    let portland = CitySearch.result(
      name: "Portland, OR", subtitle: nil, latitude: 45.5152, longitude: -122.6784)!

    XCTAssertEqual(CitySearch.dedupe([seattle, seattleDup, portland]).map(\.name), [
      "Seattle, WA", "Portland, OR",
    ])
  }

  func testPlacemarkNotFoundIsEmptyNotAnError() {
    let notFound = NSError(
      domain: MKErrorDomain, code: Int(MKError.Code.placemarkNotFound.rawValue))
    XCTAssertNil(CitySearch.errorMessage(for: notFound))
    XCTAssertNil(CitySearch.errorMessage(for: CancellationError()))
  }

  func testNetworkFailureHasRetryCopy() {
    let message = CitySearch.errorMessage(for: URLError(.notConnectedToInternet))
    XCTAssertEqual(message, "Couldn't search cities. Check your connection and try again.")
  }

  func testSelectingANewCityReplacesTheSingleNonGPSSlot() {
    let olive = SavedLocation.oliveBranch
    let seattle = SavedLocation(name: "Seattle, WA", latitude: 47.6062, longitude: -122.3321)
    XCTAssertEqual(
      CitySearch.selection(candidate: seattle, saved: [olive], canAdd: false),
      .replace(olive)
    )
  }

  func testSelectingDoesNotReplaceACurrentGPSPin() {
    let gps = SavedLocation(
      name: "Olive Branch, MS", latitude: 34.9618, longitude: -89.8295, isCurrent: true)
    let seattle = SavedLocation(name: "Seattle, WA", latitude: 47.6062, longitude: -122.3321)
    XCTAssertEqual(
      CitySearch.selection(candidate: seattle, saved: [gps], canAdd: false),
      .paywall
    )
  }

  func testSelectingAnExistingCityDoesNotAddADuplicate() {
    let seattle = SavedLocation(name: "Seattle, WA", latitude: 47.6062, longitude: -122.3321)
    XCTAssertEqual(
      CitySearch.selection(candidate: seattle, saved: [seattle], canAdd: false),
      .selectExisting(seattle)
    )
  }
}
