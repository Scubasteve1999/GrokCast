import CoreLocation
import Foundation
import WeatherKit

final class WeatherService {
  private let service = WeatherService.shared
  
  func fetchWeather(for location: CLLocationCoordinate2D) async throws -> Weather {
    return try await service.weather(for: .init(latitude: location.latitude, longitude: location.longitude))
  }
}
