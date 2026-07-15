import Foundation

// MARK: - Open-Meteo Response Models (pure Swift, no external deps)

struct OpenMeteoResponse: Decodable {
  let latitude: Double
  let longitude: Double
  let current: Current?
  let hourly: Hourly?
  let daily: Daily?
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
struct SpotterCastWeather: Equatable, Codable {
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

  // Stable identity based on the actual forecast day
  var id: Date { date }

  enum CodingKeys: String, CodingKey {
    case date, high, low, precipChance, weatherCode, symbolName, uvMax, rainSum, showersSum,
      snowfallSum
  }
}

// WMO Weather Code to symbol + text (simplified tactical mapping)
func mapWeatherCode(_ code: Int, isDay: Bool = true) -> (symbol: String, text: String) {
  switch code {
  case 0: return (isDay ? "sun.max.fill" : "moon.stars.fill", "Clear")
  case 1, 2: return (isDay ? "cloud.sun.fill" : "cloud.moon.fill", "Mainly Clear")
  case 3: return ("cloud.fill", "Overcast")
  case 45, 48: return ("cloud.fog.fill", "Fog")
  case 51, 53, 55: return ("cloud.drizzle.fill", "Drizzle")
  case 61, 63, 65: return ("cloud.rain.fill", "Rain")
  case 66, 67: return ("cloud.sleet.fill", "Sleet")
  case 71, 73, 75: return ("cloud.snow.fill", "Snow")
  case 77: return ("cloud.snow.fill", "Snow Grains")
  case 80, 81, 82: return ("cloud.heavyrain.fill", "Rain Showers")
  case 85, 86: return ("cloud.snow.fill", "Snow Showers")
  case 95, 96, 99: return ("cloud.bolt.rain.fill", "Thunderstorm")
  default: return ("cloud.sun.fill", "Variable")
  }
}

// Helper to map NWS shortForecast string to WMO code so that mapWeatherCode can be reused for symbol/text
// (avoids logic duplication for --map-to-existing-models)
func wmoCode(fromNWSShortForecast short: String) -> Int {
  let s = short.lowercased()
  if s.contains("thunder") { return 95 }
  if s.contains("snow") { return 71 }
  if s.contains("sleet") || s.contains("freez") { return 66 }
  if s.contains("rain") { return 61 }
  if s.contains("drizzle") { return 51 }
  if s.contains("fog") { return 45 }
  if s.contains("overcast") || s.contains("cloudy") { return 3 }
  if s.contains("clear") || s.contains("sunny") { return 0 }
  return 2
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
