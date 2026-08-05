import ActivityKit
import Foundation

struct WeatherLiveActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var locationName: String
    var temperatureText: String
    var conditionText: String
    var score: Int
    var scoreLabel: String
    var minutecastMessage: String
    var symbolName: String
  }
}
