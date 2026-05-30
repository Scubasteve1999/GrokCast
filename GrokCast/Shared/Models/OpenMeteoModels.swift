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
    let temperature_2m: Double
    let relative_humidity_2m: Int?
    let apparent_temperature: Double?
    let is_day: Int?
    let precipitation: Double?
    let weather_code: Int
    let wind_speed_10m: Double?
    let wind_direction_10m: Int?
}

struct Hourly: Decodable {
    let time: [String]
    let temperature_2m: [Double]
    let relative_humidity_2m: [Int]?
    let apparent_temperature: [Double]?
    let precipitation_probability: [Int]?
    let precipitation: [Double]?
    let weather_code: [Int]
    let wind_speed_10m: [Double]?
    let uv_index: [Double]?
}

struct Daily: Decodable {
    let time: [String]
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let precipitation_probability_max: [Int]?
    let uv_index_max: [Double]?
}

// Air Quality
struct AirQualityResponse: Decodable {
    let hourly: AirQualityHourly?
}

struct AirQualityHourly: Decodable {
    let time: [String]
    let pm10: [Double]?
    let pm2_5: [Double]?
    let us_aqi: [Int]?
    let uv_index: [Double]?
    // Pollen (may be null in some regions)
    let alder_pollen: [Double]?
    let birch_pollen: [Double]?
    let grass_pollen: [Double]?
}

// Our clean app-facing model (decoupled)
struct GrokCastWeather: Equatable, Codable {
    let location: SavedLocation
    let currentTemp: Double
    let feelsLike: Double
    let conditionCode: Int          // WMO weather code
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
    let pollenLevel: String?        // simplified

    // Hourly (next 24-48)
    let hourly: [HourlyForecast]

    // Daily (10 days)
    let daily: [DailyForecast]
}

struct HourlyForecast: Equatable, Codable, Identifiable {
    let id = UUID()
    let time: Date
    let temp: Double
    let precipChance: Int
    let weatherCode: Int
    let symbolName: String

    enum CodingKeys: String, CodingKey {
        case time, temp, precipChance, weatherCode, symbolName
    }
}

struct DailyForecast: Equatable, Codable, Identifiable {
    let id = UUID()
    let date: Date
    let high: Double
    let low: Double
    let precipChance: Int
    let weatherCode: Int
    let symbolName: String
    let uvMax: Double?

    enum CodingKeys: String, CodingKey {
        case date, high, low, precipChance, weatherCode, symbolName, uvMax
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
    case 71, 73, 75: return ("cloud.snow.fill", "Snow")
    case 80, 81, 82: return ("cloud.heavyrain.fill", "Rain Showers")
    case 85, 86: return ("cloud.snow.fill", "Snow Showers")
    case 95, 96, 99: return ("cloud.bolt.rain.fill", "Thunderstorm")
    default: return ("cloud.sun.fill", "Variable")
    }
}