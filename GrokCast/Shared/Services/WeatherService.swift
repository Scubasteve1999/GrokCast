import Foundation
import WeatherKit
import CoreLocation

@Observable
final class WeatherService {
    private let weatherKitService = WeatherKit.WeatherService.shared // Apple's WeatherKit service
    var isLoading = false
    var error: Error?

    func fetchWeather(for location: SavedLocation) async throws -> WeatherData {
        isLoading = true
        error = nil

        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        do {
            let (current, hourly, daily) = try await weatherKitService.weather(
                for: clLocation,
                including: .current, .hourly, .daily
            )

            let weatherData = WeatherData(
                location: location,
                current: current,
                hourly: hourly,
                daily: daily,
                fetchedAt: Date()
            )

            isLoading = false
            return weatherData
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }

    // Convenience for current device location
    func fetchWeather(for coordinate: CLLocationCoordinate2D, name: String = "Current Location") async throws -> WeatherData {
        let loc = SavedLocation(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude, isCurrent: true)
        return try await fetchWeather(for: loc)
    }
}