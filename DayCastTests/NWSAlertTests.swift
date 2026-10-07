import XCTest

@testable import DayCast

final class NWSAlertTests: XCTestCase {

  private func makeAlert(
    event: String = "Special Weather Statement",
    severity: String? = nil,
    expires: Date? = nil
  ) -> NWSAlert {
    NWSAlert(
      id: "test",
      event: event,
      severity: severity,
      headline: nil,
      description: nil,
      instruction: nil,
      expires: expires,
      areaDesc: nil,
      latitude: nil,
      longitude: nil
    )
  }

  // MARK: - severityLevel

  func testSeverityLevelExtremeIsFour() {
    XCTAssertEqual(makeAlert(severity: "Extreme").severityLevel, 4)
  }

  func testSeverityLevelSevereIsThree() {
    XCTAssertEqual(makeAlert(severity: "Severe").severityLevel, 3)
  }

  func testSeverityLevelModerateIsTwo() {
    XCTAssertEqual(makeAlert(severity: "Moderate").severityLevel, 2)
  }

  func testSeverityLevelMinorIsOne() {
    XCTAssertEqual(makeAlert(severity: "Minor").severityLevel, 1)
  }

  func testSeverityLevelUnknownIsZero() {
    XCTAssertEqual(makeAlert(severity: nil).severityLevel, 0)
    XCTAssertEqual(makeAlert(severity: "Unknown").severityLevel, 0)
  }

  func testSeverityLevelIsCaseInsensitive() {
    XCTAssertEqual(makeAlert(severity: "EXTREME").severityLevel, 4)
    XCTAssertEqual(makeAlert(severity: "severe").severityLevel, 3)
  }

  // MARK: - isWarning / isWatch

  func testIsWarningTrueForWarningEvent() {
    XCTAssertTrue(makeAlert(event: "Tornado Warning").isWarning)
    XCTAssertTrue(makeAlert(event: "Flash Flood Warning").isWarning)
    XCTAssertTrue(makeAlert(event: "Winter Storm Warning").isWarning)
  }

  func testIsWarningFalseForNonWarning() {
    XCTAssertFalse(makeAlert(event: "Dense Fog Advisory").isWarning)
    XCTAssertFalse(makeAlert(event: "Tornado Watch").isWarning)
  }

  func testIsWatchTrueForWatchEvent() {
    XCTAssertTrue(makeAlert(event: "Tornado Watch").isWatch)
    XCTAssertTrue(makeAlert(event: "Severe Thunderstorm Watch").isWatch)
  }

  func testIsWatchFalseWhenEventIsAlsoAWarning() {
    // An event containing both "watch" and "warning" must not be classified as a watch.
    XCTAssertFalse(makeAlert(event: "Tornado Warning Watch").isWatch)
  }

  func testIsWatchFalseForAdvisory() {
    XCTAssertFalse(makeAlert(event: "Wind Advisory").isWatch)
  }

  func testIsWarningIsCaseInsensitive() {
    XCTAssertTrue(makeAlert(event: "TORNADO WARNING").isWarning)
  }

  // MARK: - isSevereEvent

  func testIsSevereEventTrueForWarning() {
    XCTAssertTrue(makeAlert(event: "Winter Storm Warning").isSevereEvent)
  }

  func testIsSevereEventTrueForWatch() {
    XCTAssertTrue(makeAlert(event: "Winter Storm Watch").isSevereEvent)
  }

  func testIsSevereEventFalseForAdvisory() {
    XCTAssertFalse(makeAlert(event: "Freeze Advisory").isSevereEvent)
  }

  func testIsSevereEventFalseForStatement() {
    XCTAssertFalse(makeAlert(event: "Special Weather Statement").isSevereEvent)
  }

  // MARK: - isRadarRelevant

  func testRadarRelevantTrueForStormWarningAndWatch() {
    XCTAssertTrue(makeAlert(event: "Tornado Warning").isRadarRelevant)
    XCTAssertTrue(makeAlert(event: "Severe Thunderstorm Watch").isRadarRelevant)
    XCTAssertTrue(makeAlert(event: "Flash Flood Warning").isRadarRelevant)
    XCTAssertTrue(makeAlert(event: "Winter Storm Warning").isRadarRelevant)
    XCTAssertTrue(makeAlert(event: "Special Marine Warning").isRadarRelevant)
  }

  func testRadarRelevantFalseForHeatAndAirQuality() {
    XCTAssertFalse(makeAlert(event: "Heat Advisory").isRadarRelevant)
    XCTAssertFalse(makeAlert(event: "Extreme Heat Warning").isRadarRelevant)
    XCTAssertFalse(makeAlert(event: "Excessive Heat Warning").isRadarRelevant)
    XCTAssertFalse(makeAlert(event: "Air Quality Alert").isRadarRelevant)
    XCTAssertFalse(makeAlert(event: "Air Quality Warning").isRadarRelevant)
  }

  func testRadarRelevantFalseForFreezeFogFireAndWind() {
    XCTAssertFalse(makeAlert(event: "Freeze Advisory").isRadarRelevant)
    XCTAssertFalse(makeAlert(event: "Hard Freeze Warning").isRadarRelevant)
    XCTAssertFalse(makeAlert(event: "Dense Fog Advisory").isRadarRelevant)
    XCTAssertFalse(makeAlert(event: "Red Flag Warning").isRadarRelevant)
    XCTAssertFalse(makeAlert(event: "High Wind Warning").isRadarRelevant)
    XCTAssertFalse(makeAlert(event: "Special Weather Statement").isRadarRelevant)
  }

  // MARK: - isLifeThreatening

  func testTornadoWarningIsLifeThreatening() {
    XCTAssertTrue(makeAlert(event: "Tornado Warning").isLifeThreatening)
  }

  func testHurricaneWarningIsLifeThreatening() {
    XCTAssertTrue(makeAlert(event: "Hurricane Warning").isLifeThreatening)
  }

  func testExtremeWindWarningIsLifeThreatening() {
    XCTAssertTrue(makeAlert(event: "Extreme Wind Warning").isLifeThreatening)
  }

  func testFlashFloodEmergencyIsLifeThreatening() {
    XCTAssertTrue(makeAlert(event: "Flash Flood Emergency").isLifeThreatening)
  }

  func testExtremeSeverityIsLifeThreatening() {
    XCTAssertTrue(makeAlert(event: "Blizzard Warning", severity: "Extreme").isLifeThreatening)
  }

  func testSevereThunderstormWarningIsNotLifeThreatening() {
    XCTAssertFalse(makeAlert(event: "Severe Thunderstorm Warning", severity: "Severe").isLifeThreatening)
  }

  // MARK: - Warning emphasis (ALL CAPS + danger red)

  func testWarningEmphasisIsReservedForWarningsAndEmergencies() {
    XCTAssertTrue(makeAlert(event: "Tornado Warning").usesWarningEmphasis)
    XCTAssertTrue(makeAlert(event: "Flash Flood Emergency").usesWarningEmphasis)
    XCTAssertFalse(makeAlert(event: "Tornado Watch").usesWarningEmphasis)
    XCTAssertFalse(makeAlert(event: "Air Quality Alert", severity: "Severe").usesWarningEmphasis)
    XCTAssertFalse(makeAlert(event: "Dense Fog Advisory").usesWarningEmphasis)
  }

  func testDangerTintIsReservedForWarningEmphasis() {
    XCTAssertEqual(
      NWSAlertStyle.emphasis(for: makeAlert(event: "Tornado Warning")),
      .warning
    )
    XCTAssertEqual(
      NWSAlertStyle.emphasis(for: makeAlert(event: "Tornado Watch")),
      .watch
    )
    XCTAssertEqual(
      NWSAlertStyle.emphasis(for: makeAlert(event: "Air Quality Alert", severity: "Severe")),
      .watch
    )
    XCTAssertEqual(
      NWSAlertStyle.emphasis(for: makeAlert(event: "Dense Fog Advisory", severity: "Minor")),
      .advisory
    )
    XCTAssertEqual(
      NWSAlertStyle.iconName(for: makeAlert(event: "Air Quality Alert", severity: "Severe")),
      "exclamationmark.circle.fill"
    )
    XCTAssertEqual(
      NWSAlertStyle.iconName(for: makeAlert(event: "Tornado Watch")),
      "exclamationmark.triangle.fill"
    )
  }

  // MARK: - isExpired

  func testIsExpiredFalseWhenNoExpiresDate() {
    XCTAssertFalse(makeAlert().isExpired)
  }

  func testIsExpiredTrueForPastExpiry() {
    let past = Date(timeIntervalSinceNow: -3600)
    XCTAssertTrue(makeAlert(expires: past).isExpired)
  }

  func testIsExpiredFalseForFutureExpiry() {
    let future = Date(timeIntervalSinceNow: 3600)
    XCTAssertFalse(makeAlert(expires: future).isExpired)
  }

  func testIsExpiredAtUsesProvidedNowNotWallClock() {
    let expires = Date(timeIntervalSinceNow: -3_600)
    let alert = makeAlert(expires: expires)
    XCTAssertTrue(alert.isExpired)
    XCTAssertFalse(alert.isExpired(at: expires.addingTimeInterval(-60)))
    XCTAssertTrue(alert.isExpired(at: expires.addingTimeInterval(60)))
  }

  // MARK: - AlertsLoadState

  func testAlertsLoadStatePendingUntilThisCityIsAttempted() {
    let seattle = UUID()
    XCTAssertEqual(
      AlertsLoadState.resolve(
        currentLocationID: seattle, attemptedLocationID: nil, lastSucceeded: false),
      .pending)
    XCTAssertEqual(
      AlertsLoadState.resolve(
        currentLocationID: seattle, attemptedLocationID: UUID(), lastSucceeded: true),
      .pending)
  }

  func testAlertsLoadStateLoadedOnlyAfterSuccessForThisCity() {
    let seattle = UUID()
    XCTAssertEqual(
      AlertsLoadState.resolve(
        currentLocationID: seattle, attemptedLocationID: seattle, lastSucceeded: true),
      .loaded)
  }

  func testAlertsLoadStateFailedDoesNotLookLikeAllClear() {
    let seattle = UUID()
    XCTAssertEqual(
      AlertsLoadState.resolve(
        currentLocationID: seattle, attemptedLocationID: seattle, lastSucceeded: false),
      .failed)
  }

  // MARK: - Alert history is per city

  func testAlertHistoryForOneCityIsNotShownOnAnother() {
    let olive = UUID()
    let seattle = UUID()
    let heat = makeAlert(event: "Extreme Heat Warning")
    AlertHistoryStore.saveHistory([heat], for: olive)

    XCTAssertEqual(AlertHistoryStore.loadHistory(for: olive).map(\.event), [
      "Extreme Heat Warning"
    ])
    XCTAssertTrue(AlertHistoryStore.loadHistory(for: seattle).isEmpty)
  }

  func testLegacyUnscopedAlertHistoryIsDiscarded() throws {
    let mixed = [makeAlert(event: "Severe Thunderstorm Warning")]
    let data = try JSONEncoder().encode(mixed)
    UserDefaults.standard.set(data, forKey: AlertHistoryStore.historyKey)

    XCTAssertTrue(AlertHistoryStore.loadHistory(for: UUID()).isEmpty)
    XCTAssertNil(UserDefaults.standard.data(forKey: AlertHistoryStore.historyKey))
  }

  // MARK: - /alerts/active decoding

  func testAlertWithNullFieldsStillDecodes() throws {
    let json = """
      {
        "features": [
          {
            "id": "https://api.weather.gov/alerts/urn:oid:2.49.0.1.840.0.null-fields",
            "geometry": null,
            "properties": {
              "event": "Tornado Warning",
              "severity": null,
              "urgency": null,
              "certainty": null,
              "headline": null,
              "description": null,
              "instruction": null,
              "sent": null,
              "expires": null,
              "areaDesc": null
            }
          }
        ]
      }
      """.data(using: .utf8)!

    let alerts = try NWSService.alerts(from: json)

    XCTAssertEqual(alerts.count, 1)
    let alert = try XCTUnwrap(alerts.first)
    XCTAssertEqual(alert.event, "Tornado Warning")
    XCTAssertNil(alert.severity)
    XCTAssertNil(alert.headline)
    XCTAssertNil(alert.sent)
    XCTAssertNil(alert.expires)
    XCTAssertNil(alert.areaDesc)
    XCTAssertNil(alert.latitude)
    XCTAssertNil(alert.polygonCoordinates)
  }

  func testMalformedFeaturesAreSkippedNotFatal() throws {
    let json = """
      {
        "features": [
          { "id": "null-event", "properties": { "event": null, "severity": "Minor" } },
          { "id": "empty-event", "properties": { "event": "  " } },
          { "id": "null-properties", "properties": null },
          {
            "id": "mistyped-optionals",
            "geometry": "not geojson",
            "properties": { "event": "Flash Flood Warning", "severity": 3, "expires": false }
          },
          {
            "id": "valid",
            "properties": {
              "event": "Severe Thunderstorm Warning",
              "severity": "Severe",
              "expires": "2026-10-07T23:45:00-05:00"
            }
          }
        ]
      }
      """.data(using: .utf8)!

    let alerts = try NWSService.alerts(from: json)

    XCTAssertEqual(alerts.map(\.id), ["mistyped-optionals", "valid"])
    XCTAssertEqual(alerts[0].event, "Flash Flood Warning")
    XCTAssertNil(alerts[0].severity)
    XCTAssertNil(alerts[0].expires)
    XCTAssertNil(alerts[0].latitude)
    XCTAssertEqual(alerts[1].severity, "Severe")
    XCTAssertNotNil(alerts[1].expires)
  }

  func testNullFeaturesDecodesAsNoAlerts() throws {
    let json = #"{ "features": null }"#.data(using: .utf8)!
    XCTAssertEqual(try NWSService.alerts(from: json), [])
  }

  func testNonAlertPayloadStillThrowsSoLastKnownAlertsAreKept() {
    // Callers treat a throw as a soft failure and keep last-known alerts.
    XCTAssertThrowsError(try NWSService.alerts(from: Data("<html>503</html>".utf8)))
    XCTAssertThrowsError(try NWSService.alerts(from: Data(#"["features"]"#.utf8)))
  }

  // MARK: - /observations/latest decoding

  func testNullObservationValuesDecodeAsNil() throws {
    // NWS sends `"value": null` for sensors with no reading this cycle.
    let json = """
      {
        "properties": {
          "station": "https://api.weather.gov/stations/KOLV",
          "timestamp": "2026-10-07T21:53:00+00:00",
          "temperature": { "unitCode": "wmoUnit:degC", "value": null, "qualityControl": "Z" },
          "windSpeed": { "unitCode": "wmoUnit:km_h-1", "value": 18, "qualityControl": "V" },
          "windDirection": null
        }
      }
      """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(NWSObservationResponse.self, from: json)
    let props = decoded.properties

    XCTAssertEqual(props.timestamp, "2026-10-07T21:53:00+00:00")
    XCTAssertNil(props.temperature?.value)
    XCTAssertEqual(props.temperature?.unitCode, "wmoUnit:degC")
    XCTAssertEqual(props.windSpeed?.value, 18)
    XCTAssertNil(props.windDirection)
  }

  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: AlertHistoryStore.historyKey)
    UserDefaults.standard.removeObject(forKey: AlertHistoryStore.historyByLocationKey)
    super.tearDown()
  }
}
