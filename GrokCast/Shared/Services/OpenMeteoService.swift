import Foundation
import CoreLocation

@Observable
final class OpenMeteoService {
    var isLoading = false
    var error: String?

    // Main forecast + current
    func fetchForecast(for location: SavedLocation) async throws -> GrokCastWeather {
        isLoading = true
        error = nil

        let url = URL(string: "https://api.open-meteo.com/v1/forecast")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: "\(location.latitude)"),
            URLQueryItem(name: "longitude", value: "\(location.longitude)"),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability,uv_index"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "10")
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)

        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

        // Air quality (separate call, best effort)
        let air = try? await fetchAirQuality(for: location)

        let weather = mapToGrokCastWeather(
            location: location,
            response: decoded,
            airQuality: air
        )

        isLoading = false
        return weather
    }

    private func fetchAirQuality(for location: SavedLocation) async throws -> AirQualityResponse {
        let url = URL(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: "\(location.latitude)"),
            URLQueryItem(name: "longitude", value: "\(location.longitude)"),
            URLQueryItem(name: "hourly", value: "pm10,pm2_5,us_aqi,uv_index,alder_pollen,birch_pollen,grass_pollen"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(AirQualityResponse.self, from: data)
    }

    private func mapToGrokCastWeather(
        location: SavedLocation,
        response: OpenMeteoResponse,
        airQuality: AirQualityResponse?
    ) -> GrokCastWeather {

        let current = response.current
        let hourly = response.hourly
        let daily = response.daily

        let currentTemp = current?.temperature_2m ?? 0
        let feels = current?.apparent_temperature ?? currentTemp
        let humidity = current?.relative_humidity_2m ?? 50
        let wind = current?.wind_speed_10m ?? 0
        let code = current?.weather_code ?? 0
        let (symbol, text) = mapWeatherCode(code, isDay: (current?.is_day ?? 1) == 1)

        // Build hourly array (next 24)
        var hourlyForecasts: [HourlyForecast] = []
        if let h = hourly {
            let count = min(24, h.time.count)
            for i in 0..<count {
                let date = ISO8601DateFormatter().date(from: h.time[i]) ?? Date()
                let (sym, _) = mapWeatherCode(h.weather_code[i])
                hourlyForecasts.append(HourlyForecast(
                    time: date,
                    temp: h.temperature_2m[i],
                    precipChance: h.precipitation_probability?[i] ?? 0,
                    weatherCode: h.weather_code[i],
                    symbolName: sym
                ))
            }
        }

        // Build daily (10 days)
        var dailyForecasts: [DailyForecast] = []
        if let d = daily {
            let count = min(10, d.time.count)
            for i in 0..<count {
                let date = ISO8601DateFormatter().date(from: d.time[i]) ?? Date()
                let (sym, _) = mapWeatherCode(d.weather_code[i])
                dailyForecasts.append(DailyForecast(
                    date: date,
                    high: d.temperature_2m_max[i],
                    low: d.temperature_2m_min[i],
                    precipChance: d.precipitation_probability_max?[i] ?? 0,
                    weatherCode: d.weather_code[i],
                    symbolName: sym,
                    uvMax: d.uv_index_max?[i]
                ))
            }
        }

        // Air quality extraction (current hour)
        var aqi: Int? = nil
        var pm25: Double? = nil
        var pollen = "Low"

        if let aq = airQuality?.hourly, !aq.time.isEmpty {
            aqi = aq.us_aqi?.first
            pm25 = aq.pm2_5?.first
            // Simple pollen aggregation
            let maxPollen = max(
                aq.grass_pollen?.first ?? 0,
                aq.birch_pollen?.first ?? 0,
                aq.alder_pollen?.first ?? 0
            )
            if maxPollen > 50 { pollen = "High" }
            else if maxPollen > 20 { pollen = "Moderate" }
        }

        let high = dailyForecasts.first?.high ?? currentTemp + 5
        let low = dailyForecasts.first?.low ?? currentTemp - 8
        let precip = hourlyForecasts.first?.precipChance ?? 0
        let uv = dailyForecasts.first?.uvMax ?? hourly?.uv_index?.first ?? 3.0

        return GrokCastWeather(
            location: location,
            currentTemp: currentTemp,
            feelsLike: feels,
            conditionCode: code,
            conditionText: text,
            humidity: humidity,
            windSpeed: wind,
            uvIndex: uv,
            precipitationChance: precip,
            high: high,
            low: low,
            symbolName: symbol,
            fetchedAt: Date(),
            airQualityIndex: aqi,
            pm25: pm25,
            pollenLevel: pollen,
            hourly: hourlyForecasts,
            daily: dailyForecasts
        )
    }
}