import XCTest

@testable import DayCast

final class WeatherStoreFallbackTests: XCTestCase {
  private let olive = SavedLocation.oliveBranch
  private let seattle = SavedLocation(
    name: "Seattle, WA", latitude: 47.6062, longitude: -122.3321)

  func testKeepsLastGoodWhenItBelongsToThisLocation() {
    let weather = makeWeather(location: olive)
    let kept = WeatherStore.lastGoodOpenMeteo(weather, for: olive)
    XCTAssertEqual(kept?.location.id, olive.id)
    XCTAssertEqual(kept?.currentTemp, weather.currentTemp)
  }

  func testDoesNotReuseAnotherCityAsLastGood() {
    let weather = makeWeather(location: olive)
    XCTAssertNil(WeatherStore.lastGoodOpenMeteo(weather, for: seattle))
  }

  func testNilWeatherIsNotLastGood() {
    XCTAssertNil(WeatherStore.lastGoodOpenMeteo(nil, for: olive))
  }

  func testDisplayedWeatherHidesOtherCityNumbers() {
    let weather = makeWeather(location: olive)
    XCTAssertNil(WeatherStore.weatherMatchingSelection(weather, location: seattle))
    XCTAssertEqual(
      WeatherStore.weatherMatchingSelection(weather, location: olive)?.currentTemp, 72)
    XCTAssertEqual(
      WeatherStore.weatherMatchingSelection(weather, location: nil)?.location.id, olive.id)
    XCTAssertNil(WeatherStore.weatherMatchingSelection(nil, location: olive))
  }

  func testFormatWindUsesUnitLabel() {
    XCTAssertEqual(TemperatureUnit.fahrenheit.formatWind(12.4), "12 mph")
    XCTAssertEqual(TemperatureUnit.celsius.formatWind(18.6), "19 km/h")
  }

  func testFormatFromFahrenheitConvertsInCelsius() {
    XCTAssertEqual(TemperatureUnit.fahrenheit.formatFromFahrenheit(68), "68°F")
    XCTAssertEqual(TemperatureUnit.celsius.formatFromFahrenheit(68), "20°C")
  }

  func testFormatWindFromMphConvertsInCelsius() {
    XCTAssertEqual(TemperatureUnit.fahrenheit.formatWindFromMph(10), "10 mph")
    XCTAssertEqual(TemperatureUnit.celsius.formatWindFromMph(10), "16 km/h")
  }

  func testOWMPlaceholderKeyIsNotConfigured() {
    XCTAssertFalse(OpenWeatherMapRadarService.isUsableAPIKey(""))
    XCTAssertFalse(OpenWeatherMapRadarService.isUsableAPIKey("YOUR_OPENWEATHERMAP_API_KEY"))
    XCTAssertFalse(OpenWeatherMapRadarService.isUsableAPIKey("  YOUR_KEY  "))
    XCTAssertTrue(OpenWeatherMapRadarService.isUsableAPIKey("abc123realkey"))
  }

  func testNearestHourPrefersCurrentHourNotMidnight() {
    let midnight = Date(timeIntervalSince1970: 1_767_225_600)  // 2026-01-01 00:00 UTC
    let times: [Date?] = [
      midnight,
      midnight.addingTimeInterval(12 * 3600),
      midnight.addingTimeInterval(13 * 3600),
    ]
    let noon = midnight.addingTimeInterval(12 * 3600 + 10 * 60)
    XCTAssertEqual(OpenMeteoHourIndex.nearest(in: times, to: noon), 1)
  }

  private func makeWeather(location: SavedLocation) -> DayCastWeather {
    DayCastWeather(
      location: location,
      currentTemp: 72,
      feelsLike: 70,
      conditionCode: 0,
      conditionText: "Clear",
      humidity: 40,
      windSpeed: 8,
      uvIndex: 4,
      precipitationChance: 5,
      high: 78,
      low: 61,
      symbolName: "sun.max.fill",
      fetchedAt: Date(),
      timezoneIdentifier: "America/Chicago",
      airQualityIndex: nil,
      pm25: nil,
      pollenLevel: nil,
      hourly: [],
      daily: [],
      minutely15: []
    )
  }
}


// These tests drive real WeatherStore refresh methods, controlling network completion order.
// No sleeps, provider calls, notification writes, or persistence are needed.
extension WeatherStoreFallbackTests {
  private func taggedWeather(_ location: SavedLocation, units: TemperatureUnit = .fahrenheit) -> DayCastWeather {
    var weather = makeWeather(location: location)
    weather.temperatureUnitRawValue = units.rawValue
    return weather
  }

  @MainActor
  func testOfflineUnitSwitchClearsOldValuesAndShowsRecoverableError() async {
    let store = WeatherStore(loadPersistedState: false, fetchers: .init(forecast: { _, _ in
      throw URLError(.notConnectedToInternet)
    }))
    store.currentLocation = olive
    store.currentWeather = taggedWeather(olive)
    XCTAssertNotNil(store.displayedWeather)
    store.temperatureUnit = .celsius
    XCTAssertNil(store.currentWeather)
    XCTAssertNil(store.displayedWeather)
    await store.refreshWeather()
    XCTAssertNil(store.displayedWeather)
    XCTAssertNotNil(store.weatherError)
    XCTAssertFalse(store.isLoadingWeather)
  }

  @MainActor
  func testOlderCityCompletionCannotStopNewCityLoadingOrPublishWeather() async {
    let old = PendingWeatherValue<DayCastWeather>()
    let new = PendingWeatherValue<DayCastWeather>()
    let oldID = olive.id
    let store = WeatherStore(loadPersistedState: false, fetchers: .init(forecast: { location, _ in
      try await (location.id == oldID ? old : new).value()
    }))
    store.currentLocation = olive
    let first = Task { await store.refreshWeather() }
    await old.waitUntilStarted()
    store.currentLocation = seattle
    let second = Task { await store.refreshWeather() }
    await new.waitUntilStarted()
    old.finish(.success(taggedWeather(olive)))
    await first.value
    XCTAssertNil(store.currentWeather)
    XCTAssertTrue(store.isLoadingWeather)
    new.finish(.failure(URLError(.notConnectedToInternet)))
    await second.value
    XCTAssertNil(store.currentWeather)
    XCTAssertNotNil(store.weatherError)
    XCTAssertFalse(store.isLoadingWeather)
  }

  @MainActor
  func testOlderSameCityRequestCannotOverwriteLatestResult() async {
    let firstGate = PendingWeatherValue<DayCastWeather>()
    let secondGate = PendingWeatherValue<DayCastWeather>()
    var calls = 0
    let store = WeatherStore(loadPersistedState: false, fetchers: .init(forecast: { _, _ in
      calls += 1
      return try await (calls == 1 ? firstGate : secondGate).value()
    }))
    store.currentLocation = olive
    let first = Task { await store.refreshWeather() }
    await firstGate.waitUntilStarted()
    let second = Task { await store.refreshWeather() }
    await secondGate.waitUntilStarted()
    let older = taggedWeather(olive)
    let latest = taggedWeather(olive)
    secondGate.finish(.success(latest))
    await second.value
    firstGate.finish(.success(older))
    await first.value
    XCTAssertEqual(store.currentWeather, latest)
    XCTAssertNil(store.weatherError)
    XCTAssertFalse(store.isLoadingWeather)
  }

  @MainActor
  func testChangingUnitsAwayAndBackRejectsOriginalInFlightRequest() async {
    let gate = PendingWeatherValue<DayCastWeather>()
    let store = WeatherStore(loadPersistedState: false, fetchers: .init(forecast: { _, units in
      XCTAssertEqual(units, .fahrenheit)
      return try await gate.value()
    }))
    store.currentLocation = olive
    let first = Task { await store.refreshWeather() }
    await gate.waitUntilStarted()
    store.temperatureUnit = .celsius
    store.temperatureUnit = .fahrenheit
    gate.finish(.success(taggedWeather(olive)))
    await first.value
    XCTAssertNil(store.currentWeather)
  }

  @MainActor
  func testChangingCityAwayAndBackRejectsOriginalInFlightRequest() async {
    let gate = PendingWeatherValue<DayCastWeather>()
    let store = WeatherStore(loadPersistedState: false, fetchers: .init(forecast: { _, _ in
      try await gate.value()
    }))
    store.currentLocation = olive
    let first = Task { await store.refreshWeather() }
    await gate.waitUntilStarted()
    store.currentLocation = seattle
    store.currentLocation = olive
    gate.finish(.success(taggedWeather(olive)))
    await first.value
    XCTAssertNil(store.currentWeather)
  }

  @MainActor
  func testGPSMoveWithSameSavedIDInvalidatesWeather() {
    let store = WeatherStore(loadPersistedState: false)
    store.currentLocation = olive
    store.currentWeather = taggedWeather(olive)
    var moved = olive
    moved.latitude += 1
    store.currentLocation = moved
    XCTAssertNil(store.currentWeather)
    XCTAssertNil(WeatherStore.weatherMatchingSelection(taggedWeather(olive), location: moved, units: .fahrenheit))
  }

  @MainActor
  func testOldNWSFailureCannotClearNewCityObservation() async {
    let gate = PendingWeatherValue<NWSObservation?>()
    let oldID = olive.id
    let latest = NWSObservation(stationId: "NEW", observedAt: Date(), temperatureF: 60,
      windSpeedMph: 4, windDirectionDegrees: nil)
    let store = WeatherStore(loadPersistedState: false, fetchers: .init(observation: { location in
      if location.id == oldID { return try await gate.value() }
      return latest
    }))
    store.currentLocation = olive
    let first = Task { await store.refreshNWSObservation() }
    await gate.waitUntilStarted()
    store.currentLocation = seattle
    XCTAssertNil(store.currentNWSObservation)
    await store.refreshNWSObservation()
    gate.finish(.failure(URLError(.timedOut)))
    await first.value
    XCTAssertEqual(store.currentNWSObservation, latest)
  }

  @MainActor
  func testOldOWMResultCannotReplaceNewCityData() async {
    typealias Hybrid = (OpenWeatherMapCurrentWeather, OpenWeatherMapForecast)
    let gate = PendingWeatherValue<Hybrid>()
    let oldID = olive.id
    let latest = hybridWeather(seattle.name)
    let store = WeatherStore(loadPersistedState: false, fetchers: .init(openWeatherMap: { location in
      if location.id == oldID { return try await gate.value() }
      return latest
    }))
    store.currentLocation = olive
    let first = Task { await store.refreshOpenWeatherMap() }
    await gate.waitUntilStarted()
    store.currentLocation = seattle
    await store.refreshOpenWeatherMap()
    gate.finish(.success(hybridWeather(olive.name)))
    await first.value
    XCTAssertEqual(store.openWeatherMapForecast, latest.1)
    XCTAssertEqual(store.currentOpenWeatherMapWeather, latest.0)
  }

  @MainActor
  func testSupplementalCacheClearsWhenNextCityFails() async {
    let oldID = olive.id
    let old = hybridWeather(olive.name)
    let observation = NWSObservation(stationId: "OLD", observedAt: Date(), temperatureF: 72,
      windSpeedMph: 4, windDirectionDegrees: nil)
    let store = WeatherStore(loadPersistedState: false, fetchers: .init(
      observation: { location in
        guard location.id == oldID else { throw URLError(.notConnectedToInternet) }
        return observation
      }, openWeatherMap: { location in
        guard location.id == oldID else { throw URLError(.notConnectedToInternet) }
        return old
      }))
    store.currentLocation = olive
    await store.refreshNWSObservation()
    await store.refreshOpenWeatherMap()
    XCTAssertNotNil(store.currentNWSObservation)
    XCTAssertNotNil(store.openWeatherMapForecast)
    store.currentLocation = seattle
    XCTAssertNil(store.currentNWSObservation)
    XCTAssertNil(store.openWeatherMapForecast)
    await store.refreshNWSObservation()
    await store.refreshOpenWeatherMap()
    XCTAssertNil(store.currentNWSObservation)
    XCTAssertNil(store.currentOpenWeatherMapWeather)
    XCTAssertNil(store.openWeatherMapForecast)
    XCTAssertNil(store.weatherError) // Additive failures remain silent.
  }

  func testSnapshotUnitsRoundTripAndRejectLegacyOrWrongUnits() throws {
    let snapshot = WidgetWeatherSnapshot(weather: taggedWeather(olive, units: .celsius))
    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(WidgetWeatherSnapshot.self, from: data)
    let weather = DayCastWeather(snapshot: decoded)
    XCTAssertEqual(weather.temperatureUnitRawValue, "celsius")
    XCTAssertNotNil(WeatherStore.lastGoodOpenMeteo(weather, for: olive, units: .celsius))
    XCTAssertNil(WeatherStore.lastGoodOpenMeteo(weather, for: olive, units: .fahrenheit))
    var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    legacy.removeValue(forKey: "temperatureUnitRawValue")
    let oldSnapshot = try JSONDecoder().decode(WidgetWeatherSnapshot.self,
      from: JSONSerialization.data(withJSONObject: legacy))
    XCTAssertNil(oldSnapshot.temperatureUnitRawValue)
    XCTAssertNil(WeatherStore.lastGoodOpenMeteo(DayCastWeather(snapshot: oldSnapshot), for: olive, units: .celsius))
    XCTAssertNil(WeatherStore.lastGoodOpenMeteo(DayCastWeather(snapshot: oldSnapshot), for: olive, units: .fahrenheit))
  }

  private func hybridWeather(_ name: String) -> (OpenWeatherMapCurrentWeather, OpenWeatherMapForecast) {
    (OpenWeatherMapCurrentWeather(locationName: name, temperatureF: 72, feelsLikeF: 70,
      condition: "Clear", humidityPercent: 40, windSpeedMph: 3, windDirectionDegrees: nil,
      cloudCoverPercent: 0, observedAt: Date()),
      OpenWeatherMapForecast(locationName: name, entries: []))
  }
}

@MainActor
private final class PendingWeatherValue<Value> {
  private var continuation: CheckedContinuation<Value, Error>?
  private var started: CheckedContinuation<Void, Never>?

  func value() async throws -> Value {
    try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      started?.resume()
      started = nil
    }
  }

  func waitUntilStarted() async {
    if continuation != nil { return }
    await withCheckedContinuation { started = $0 }
  }

  func finish(_ result: Result<Value, Error>) {
    continuation?.resume(with: result)
    continuation = nil
  }
}
