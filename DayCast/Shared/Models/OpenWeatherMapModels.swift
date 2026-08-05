import Foundation

struct OpenWeatherMapCurrentResponse: Decodable {
  let coord: Coord
  let weather: [WeatherDescription]
  let main: Main
  let wind: Wind?
  let clouds: Clouds?
  let dt: TimeInterval
  let name: String

  struct Coord: Decodable {
    let lat: Double
    let lon: Double
  }

  struct WeatherDescription: Decodable {
    let id: Int
    let main: String
    let description: String
    let icon: String
  }

  struct Main: Decodable {
    let temp: Double
    let feelsLike: Double
    let tempMin: Double
    let tempMax: Double
    let pressure: Int
    let humidity: Int

    enum CodingKeys: String, CodingKey {
      case temp
      case feelsLike = "feels_like"
      case tempMin = "temp_min"
      case tempMax = "temp_max"
      case pressure
      case humidity
    }
  }

  struct Wind: Decodable {
    let speed: Double
    let deg: Int?
    let gust: Double?
  }

  struct Clouds: Decodable {
    let all: Int
  }
}

struct OpenWeatherMapForecastResponse: Decodable {
  let list: [ForecastItem]
  let city: City

  struct ForecastItem: Decodable {
    let dt: TimeInterval
    let main: OpenWeatherMapCurrentResponse.Main
    let weather: [OpenWeatherMapCurrentResponse.WeatherDescription]
    let clouds: OpenWeatherMapCurrentResponse.Clouds?
    let wind: OpenWeatherMapCurrentResponse.Wind?
    let pop: Double?
  }

  struct City: Decodable {
    let name: String
    let country: String
    let coord: OpenWeatherMapCurrentResponse.Coord
  }
}

struct OpenWeatherMapCurrentWeather: Equatable {
  let locationName: String
  let temperatureF: Double
  let feelsLikeF: Double
  let condition: String
  let humidityPercent: Int
  let windSpeedMph: Double
  let windDirectionDegrees: Int?
  let cloudCoverPercent: Int
  let observedAt: Date
}

struct OpenWeatherMapForecastEntry: Equatable, Identifiable {
  var id: Date { time }
  let time: Date
  let temperatureF: Double
  let condition: String
  let iconCode: String
  let precipitationChance: Int
  let windSpeedMph: Double

  var symbolName: String {
    switch iconCode {
    case "01d": return "sun.max.fill"
    case "01n": return "moon.fill"
    case "02d": return "cloud.sun.fill"
    case "02n": return "cloud.moon.fill"
    case "03d", "03n": return "cloud.fill"
    case "04d", "04n": return "smoke.fill"
    case "09d", "09n": return "cloud.drizzle.fill"
    case "10d": return "cloud.sun.rain.fill"
    case "10n": return "cloud.moon.rain.fill"
    case "11d", "11n": return "cloud.bolt.fill"
    case "13d", "13n": return "cloud.snow.fill"
    case "50d", "50n": return "cloud.fog.fill"
    default: return "cloud.fill"
    }
  }
}

struct OpenWeatherMapForecast: Equatable {
  let locationName: String
  let entries: [OpenWeatherMapForecastEntry]
}

// MARK: - One Call API 4.0

struct OneCallWeatherDescription: Decodable, Equatable {
  let id: Int
  let main: String
  let description: String
  let icon: String
}

struct OneCallCurrentDataPoint: Decodable, Equatable {
  let dt: TimeInterval
  let temp: Double
  let feelsLike: Double
  let pressure: Int
  let humidity: Int
  let clouds: Int
  let windSpeed: Double
  let windDeg: Int?
  let weather: [OneCallWeatherDescription]

  enum CodingKeys: String, CodingKey {
    case dt, temp, pressure, humidity, clouds, weather
    case feelsLike = "feels_like"
    case windSpeed = "wind_speed"
    case windDeg = "wind_deg"
  }
}

struct OneCallCurrentResponse: Decodable {
  let lat: Double
  let lon: Double
  let timezone: String?
  let data: [OneCallCurrentDataPoint]
}

struct OneCallTimelineDataPoint: Decodable, Equatable {
  let dt: TimeInterval
  let temp: Double
  let feelsLike: Double
  let humidity: Int
  let clouds: Int
  let windSpeed: Double
  let pop: Double?
  let weather: [OneCallWeatherDescription]

  enum CodingKeys: String, CodingKey {
    case dt, temp, humidity, clouds, weather, pop
    case feelsLike = "feels_like"
    case windSpeed = "wind_speed"
  }
}

struct OneCallTimelineResponse: Decodable {
  let lat: Double
  let lon: Double
  let timezone: String?
  let data: [OneCallTimelineDataPoint]
  let next: String?
  let prev: String?
}

struct OneCallMinuteDataPoint: Decodable, Equatable {
  let dt: TimeInterval
  let precipitation: Double
}

struct OneCallMinuteTimelineResponse: Decodable {
  let data: [OneCallMinuteDataPoint]
}