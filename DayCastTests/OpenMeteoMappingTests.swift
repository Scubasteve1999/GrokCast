import XCTest

@testable import DayCast

final class OpenMeteoMappingTests: XCTestCase {
  private let olive = SavedLocation(
    name: "Olive Branch", latitude: 34.9618, longitude: -89.8295)

  func testMapsOptionalHourlyFields() throws {
    let json = """
      {
        "latitude": 34.96,
        "longitude": -89.83,
        "timezone": "America/Chicago",
        "current": {
          "time": "2099-08-25T12:00",
          "temperature_2m": 82.0,
          "relative_humidity_2m": 55,
          "apparent_temperature": 85.0,
          "dew_point_2m": 64.0,
          "is_day": 1,
          "precipitation": 0,
          "weather_code": 1,
          "wind_speed_10m": 8.0,
          "wind_direction_10m": 210,
          "visibility": 16093.4,
          "surface_pressure": 1016.2,
          "cloud_cover": 40
        },
        "hourly": {
          "time": ["2099-08-25T12:00"],
          "temperature_2m": [82.0],
          "relative_humidity_2m": [55],
          "apparent_temperature": [85.0],
          "dew_point_2m": [64.0],
          "precipitation_probability": [12],
          "weather_code": [1],
          "wind_speed_10m": [8.0],
          "wind_direction_10m": [210],
          "uv_index": [7.2],
          "visibility": [16093.4],
          "surface_pressure": [1016.2],
          "cloud_cover": [40],
          "rain": [0.0],
          "showers": [0.0],
          "snowfall": [0.0],
          "is_day": [1]
        },
        "daily": {
          "time": ["2099-08-25"],
          "weather_code": [1],
          "temperature_2m_max": [88.0],
          "temperature_2m_min": [70.0],
          "precipitation_probability_max": [12],
          "uv_index_max": [7.2]
        }
      }
      """
    let response = try decode(OpenMeteoResponse.self, json)
    let weather = OpenMeteoWeatherMapper.map(
      location: olive, response: response, airQuality: nil)
    XCTAssertEqual(weather.windDirection, 210)
    XCTAssertEqual(weather.dewPoint, 64)
    XCTAssertEqual(weather.visibilityMeters ?? 0, 16093.4, accuracy: 0.2)
    XCTAssertEqual(weather.pressureHPa ?? 0, 1016.2, accuracy: 0.05)
    XCTAssertEqual(weather.cloudCoverPercent, 40)
    XCTAssertEqual(weather.hourly.first?.humidity, 55)
    XCTAssertEqual(weather.hourly.first?.windDirection, 210)
    XCTAssertEqual(weather.hourly.first?.uvIndex ?? 0, 7.2, accuracy: 0.01)
    XCTAssertEqual(weather.uvIndex, 7.2, accuracy: 0.01)
    XCTAssertEqual(weather.currentUVIndex ?? 0, 7.2, accuracy: 0.01)
    XCTAssertEqual(weather.hourly.first?.cloudCoverPercent, 40)
    XCTAssertNil(weather.pollen)
    XCTAssertNil(weather.pollenLevel)
    XCTAssertNil(weather.pm10)
  }

  func testMissingHourlyArraysStayNilInsteadOfInvented() throws {
    let json = """
      {
        "latitude": 34.96,
        "longitude": -89.83,
        "timezone": "America/Chicago",
        "current": {
          "time": "2099-08-25T12:00",
          "temperature_2m": 70.0,
          "weather_code": 0
        },
        "hourly": {
          "time": ["2099-08-25T12:00", "2099-08-25T13:00"],
          "temperature_2m": [70.0],
          "weather_code": [0]
        }
      }
      """
    let response = try decode(OpenMeteoResponse.self, json)
    let weather = OpenMeteoWeatherMapper.map(
      location: olive, response: response, airQuality: nil)
    XCTAssertEqual(weather.hourly.first?.temp, 70)
    XCTAssertNil(weather.hourly.first?.feelsLike)
    XCTAssertNil(weather.hourly.first?.humidity)
    XCTAssertNil(weather.hourly.first?.visibilityMeters)
    XCTAssertNil(weather.hourly.first?.pressureHPa)
    XCTAssertNil(weather.dewPoint)
    XCTAssertNil(weather.visibilityMeters)
    let rows = HourlyDetailMetrics.rows(
      hour: weather.hourly[0], unit: .fahrenheit)
    XCTAssertEqual(rows.first { $0.label == "Feels" }?.value, "—")
    XCTAssertEqual(rows.first { $0.label == "Visibility" }?.value, "—")
  }

  func testNoPollenRegionHidesPollen() throws {
    let json = """
      {
        "hourly": {
          "time": ["2099-08-25T12:00"],
          "pm2_5": [8.2],
          "pm10": [12.4],
          "us_aqi": [42],
          "alder_pollen": [null],
          "birch_pollen": [null],
          "grass_pollen": [null],
          "ragweed_pollen": [null]
        },
        "timezone": "America/Chicago"
      }
      """
    let air = try decode(AirQualityResponse.self, json)
    let weather = OpenMeteoWeatherMapper.map(
      location: olive,
      response: try decode(
        OpenMeteoResponse.self,
        """
        {
          "latitude": 34.96,
          "longitude": -89.83,
          "timezone": "America/Chicago",
          "current": {"time": "2026-08-25T12:00", "temperature_2m": 80, "weather_code": 0}
        }
        """
      ),
      airQuality: air
    )
    XCTAssertNil(weather.pollen)
    XCTAssertNil(weather.pollenLevel)
    XCTAssertEqual(weather.airQualityIndex, 42)
    XCTAssertEqual(weather.pm25 ?? 0, 8.2, accuracy: 0.05)
    XCTAssertEqual(weather.pm10 ?? 0, 12.4, accuracy: 0.05)
  }

  func testPollenCategoryFromPeakSpecies() {
    XCTAssertNil(PollenConditions.from(grass: nil, birch: nil, alder: nil, ragweed: nil))
    XCTAssertEqual(
      PollenConditions.from(grass: 12, birch: nil, alder: nil, ragweed: nil)?.category,
      "Low"
    )
    XCTAssertEqual(
      PollenConditions.from(grass: 21, birch: 8, alder: nil, ragweed: nil)?.category,
      "Moderate"
    )
    XCTAssertEqual(
      PollenConditions.from(grass: 8, birch: 4, alder: 60, ragweed: nil)?.category,
      "High"
    )
  }

  func testVisibilityAndPressureUnits() {
    XCTAssertEqual(
      HourlyDetailMetrics.visibilityValue(16093.4, unit: .fahrenheit), "10 mi")
    XCTAssertEqual(
      HourlyDetailMetrics.visibilityValue(16093.4, unit: .celsius), "16 km")
    XCTAssertEqual(
      HourlyDetailMetrics.pressureValue(1016.0, unit: .celsius), "1016 hPa")
    XCTAssertTrue(
      HourlyDetailMetrics.pressureValue(1016.0, unit: .fahrenheit).contains("inHg"))
    XCTAssertEqual(HourlyDetailMetrics.visibilityValue(nil, unit: .fahrenheit), "—")
  }

  func testNWSFallbackLeavesNewFieldsNil() {
    let weather = DayCastWeather(
      location: olive,
      currentTemp: 82,
      feelsLike: 82,
      conditionCode: 1,
      conditionText: "Partly cloudy",
      humidity: 50,
      windSpeed: 6,
      uvIndex: 0,
      precipitationChance: 10,
      high: 88,
      low: 70,
      symbolName: "cloud.sun.fill",
      fetchedAt: Date(),
      timezoneIdentifier: nil,
      airQualityIndex: nil,
      pm25: nil,
      pollenLevel: nil,
      hourly: [
        HourlyForecast(
          time: Date(),
          temp: 82,
          precipChance: 10,
          weatherCode: 1,
          symbolName: "cloud.sun.fill",
          rain: nil,
          showers: nil,
          snowfall: nil
        )
      ],
      daily: [],
      minutely15: []
    )
    XCTAssertNil(weather.dewPoint)
    XCTAssertNil(weather.visibilityMeters)
    XCTAssertNil(weather.pressureHPa)
    XCTAssertNil(weather.pm10)
    XCTAssertNil(weather.pollen)
    XCTAssertNil(weather.hourly.first?.humidity)
    XCTAssertNil(weather.hourly.first?.uvIndex)
    XCTAssertNil(weather.currentUVIndex)
    XCTAssertEqual(weather.uvIndex, 0)
    XCTAssertNil(weather.hourly.first?.visibilityMeters)
    let rows = HourlyDetailMetrics.rows(
      hour: weather.hourly[0], unit: .fahrenheit)
    XCTAssertEqual(rows.first { $0.label == "Humidity" }?.value, "—")
    XCTAssertEqual(rows.first { $0.label == "Clouds" }?.value, "—")
  }

  func testCurrentUVUsesHourlyNotDailyMax() throws {
    let json = """
      {
        "latitude": 34.96,
        "longitude": -89.83,
        "timezone": "America/Chicago",
        "current": {
          "time": "2099-08-25T21:00",
          "temperature_2m": 70.0,
          "weather_code": 0
        },
        "hourly": {
          "time": ["2099-08-25T21:00"],
          "temperature_2m": [70.0],
          "weather_code": [0],
          "uv_index": [0.0]
        },
        "daily": {
          "time": ["2099-08-25"],
          "weather_code": [0],
          "temperature_2m_max": [88.0],
          "temperature_2m_min": [70.0],
          "uv_index_max": [11.0]
        }
      }
      """
    let weather = OpenMeteoWeatherMapper.map(
      location: olive, response: try decode(OpenMeteoResponse.self, json), airQuality: nil)
    XCTAssertEqual(weather.uvIndex, 0)
    XCTAssertEqual(weather.currentUVIndex, 0)
    XCTAssertEqual(weather.daily.first?.uvMax, 11)
  }

  func testMapsFortyEightUpcomingHoursForForecast() throws {
    let stamps = (0..<50).map { offset -> String in
      let day = 25 + offset / 24
      let h = offset % 24
      return String(format: "2099-08-%02dT%02d:00", day, h)
    }
    let temps = stamps.map { _ in "70.0" }.joined(separator: ",")
    let codes = stamps.map { _ in "0" }.joined(separator: ",")
    let quoted = stamps.map { "\"\($0)\"" }.joined(separator: ",")
    let json = """
      {
        "latitude": 34.96,
        "longitude": -89.83,
        "timezone": "America/Chicago",
        "current": {"time": "2099-08-25T00:00", "temperature_2m": 70.0, "weather_code": 0},
        "hourly": {
          "time": [\(quoted)],
          "temperature_2m": [\(temps)],
          "weather_code": [\(codes)]
        }
      }
      """
    let weather = OpenMeteoWeatherMapper.map(
      location: olive, response: try decode(OpenMeteoResponse.self, json), airQuality: nil)
    XCTAssertEqual(weather.hourly.count, HourlyGraphHours.fullLimit)
  }

  private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
  }
}
