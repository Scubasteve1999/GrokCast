import Foundation

// MARK: - Open-Meteo Response Models (pure Swift, no external deps)

struct OpenMeteoResponse: Decodable {
  let latitude: Double
  let longitude: Double
  let current: Current?
  let hourly: Hourly?
  let daily: Daily?
  let minutely_15: Minutely15?
}

struct Minutely15: Decodable {
  let time: [String]
  let precipitation: [Double?]?
  let precipitation_probability: [Int?]?
}

struct Current: Decodable {
  let time: String
  let temperature_2m: Double?
  let relative_humidity_2m: Int?
  let apparent_temperature: Double?
  let is_day: Int?
  let precipitation: Double?
  let weather_code: Int?
  let wind_speed_10m: Double?
  let wind_direction_10m: Int?
}

struct Hourly: Decodable {
  let time: [String]
  let temperature_2m: [Double?]
  let relative_humidity_2m: [Int]?
  let apparent_temperature: [Double]?
  let precipitation_probability: [Int?]?
  let precipitation: [Double?]?
  let rain: [Double?]?
  let showers: [Double?]?
  let snowfall: [Double?]?
  let weather_code: [Int?]
  let wind_speed_10m: [Double]?
  let uv_index: [Double?]?
}

struct Daily: Decodable {
  let time: [String]
  let weather_code: [Int?]
  let temperature_2m_max: [Double?]
  let temperature_2m_min: [Double?]
  let precipitation_probability_max: [Int?]?
  let rain_sum: [Double?]?
  let showers_sum: [Double?]?
  let snowfall_sum: [Double?]?
  let uv_index_max: [Double?]?
  let sunrise: [String]?
  let sunset: [String]?
}

// Air Quality
struct AirQualityResponse: Decodable {
  let hourly: AirQualityHourly?
}

struct AirQualityHourly: Decodable {
  let time: [String]
  let pm10: [Double?]?
  let pm2_5: [Double?]?
  let us_aqi: [Int?]?
  let uv_index: [Double?]?
  // Pollen (may be null in some regions)
  let alder_pollen: [Double?]?
  let birch_pollen: [Double?]?
  let grass_pollen: [Double?]?
}

// Our clean app-facing model (decoupled)
struct GrokCastWeather: Equatable, Codable {
  let location: SavedLocation
  let currentTemp: Double
  let feelsLike: Double
  let conditionCode: Int  // WMO weather code
  let conditionText: String
  let humidity: Int
  let windSpeed: Double
  let uvIndex: Double
  let precipitationChance: Int
  let high: Double
  let low: Double
  let symbolName: String
  let fetchedAt: Date

  // Extended for competing with AccuWeather
  let airQualityIndex: Int?
  let pm25: Double?
  let pollenLevel: String?  // simplified

  // Hourly (next 24-48)
  let hourly: [HourlyForecast]

  // Daily (10 days)
  let daily: [DailyForecast]

  /// Next ~2 hours in 15-minute steps (Open-Meteo minutely_15).
  let minutely15: [MinutelyForecast]
}

struct MinutelyForecast: Equatable, Codable, Identifiable {
  let time: Date
  let precipitation: Double
  let precipChance: Int

  var id: Date { time }
}

// MARK: - Daily forecast derivation (hourly → daily precip % + representative code)

enum OpenMeteoDailyDerivation {
  struct HourlySlice {
    let time: Date
    let precipChance: Int
    let weatherCode: Int
  }

  /// Max hourly precip probability for a calendar day (Open-Meteo timezone=auto).
  static func hourlySlices(
    for day: Date,
    hourly: Hourly,
    parseHour: (String) -> Date,
    calendar: Calendar = .current
  ) -> [HourlySlice] {
    let start = calendar.startOfDay(for: day)
    guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

    var slices: [HourlySlice] = []
    let count = hourly.time.count
    for i in 0..<count {
      let time = parseHour(hourly.time[i])
      guard time >= start, time < end else { continue }
      slices.append(
        HourlySlice(
          time: time,
          precipChance: hourly.precipitation_probability?[i] ?? 0,
          weatherCode: hourly.weather_code[i] ?? 0
        ))
    }
    return slices
  }

  /// Prefer the higher of daily API max and hourly-derived max (hourly often more accurate).
  static func derivedPrecipChance(dailyAPI: Int, slices: [HourlySlice]) -> Int {
    let hourlyMax = slices.map(\.precipChance).max() ?? 0
    return max(dailyAPI, hourlyMax)
  }

  /// Pick a weather code that matches derived precip (mode from hourly when dry, peak hour when wet).
  static func derivedWeatherCode(dailyAPI: Int, precipChance: Int, slices: [HourlySlice]) -> Int {
    guard !slices.isEmpty else {
      return softenWetDailyCodeIfDry(dailyAPI, precipChance: precipChance)
    }

    if precipChance >= 15 {
      let peak = slices.max(by: { $0.precipChance < $1.precipChance })
      return peak?.weatherCode ?? dailyAPI
    }

    var counts: [Int: Int] = [:]
    for slice in slices {
      counts[slice.weatherCode, default: 0] += 1
    }
    let mode = counts.max(by: { $0.value < $1.value })?.key ?? dailyAPI
    if isWetWeatherCode(dailyAPI), !isWetWeatherCode(mode) {
      return mode
    }
    if isWetWeatherCode(dailyAPI), precipChance < 15 {
      return mode
    }
    return dailyAPI
  }

  private static func softenWetDailyCodeIfDry(_ code: Int, precipChance: Int) -> Int {
    guard precipChance < 15, isWetWeatherCode(code) else { return code }
    return 2
  }

  private static func isWetWeatherCode(_ code: Int) -> Bool {
    switch code {
    case 51, 53, 55, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99:
      return true
    default:
      return false
    }
  }
}

struct HourlyForecast: Equatable, Codable, Identifiable {
  let time: Date
  let temp: Double
  let precipChance: Int
  let weatherCode: Int
  let symbolName: String
  let rain: Double?
  let showers: Double?
  let snowfall: Double?

  // Stable identity based on the actual forecast time (prevents ForEach duplication bugs)
  var id: Date { time }

  enum CodingKeys: String, CodingKey {
    case time, temp, precipChance, weatherCode, symbolName, rain, showers, snowfall
  }
}

struct DailyForecast: Equatable, Codable, Identifiable {
  let date: Date
  let high: Double
  let low: Double
  let precipChance: Int
  let weatherCode: Int
  let symbolName: String
  let uvMax: Double?
  let rainSum: Double?
  let showersSum: Double?
  let snowfallSum: Double?
  let sunrise: Date?
  let sunset: Date?

  var id: Date { date }

  enum CodingKeys: String, CodingKey {
    case date, high, low, precipChance, weatherCode, symbolName, uvMax, rainSum, showersSum,
      snowfallSum, sunrise, sunset
  }
}

// MARK: - Precipitation amount helpers (lightweight addition for display)
// Values received from Open-Meteo are already in inches (see precipitation_unit=inch + hourly_units/daily_units).
// mmToInches / cmToInches provided per requirements for reference / future-proofing / if unit param ever omitted.
func mmToInches(_ mm: Double) -> Double { mm / 25.4 }
func cmToInches(_ cm: Double) -> Double { cm / 2.54 }

func formattedPrecipInches(_ inches: Double) -> String {
  guard inches >= 0.1 else { return "" }
  let r = (inches * 10).rounded() / 10
  return r.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(r))\"" : String(format: "%.1f\"", r)
}

// Returns e.g. "0.5\" Rain" or "2.1\" Snow" (or nil). Uses snow amt if significant, else combined liquid as "Rain".
// (Dominant type simplified to liquid vs snow per display rules; type label from % uses shortPrecipType in UI.)
func precipAmountLabel(liquid: Double, snow: Double) -> String? {
  if snow >= 0.1 {
    let s = formattedPrecipInches(snow)
    return s.isEmpty ? nil : "\(s) Snow"
  } else if liquid >= 0.1 {
    let s = formattedPrecipInches(liquid)
    return s.isEmpty ? nil : "\(s) Rain"
  }
  return nil
}

// Returns just the formatted amount (e.g. "0.5\"") for use next to type-labeled % (avoids label duplication in tight hourly rows).
func precipAmountText(liquid: Double, snow: Double) -> String? {
  if snow >= 0.1 {
    return formattedPrecipInches(snow)
  } else if liquid >= 0.1 {
    return formattedPrecipInches(liquid)
  }
  return nil
}
