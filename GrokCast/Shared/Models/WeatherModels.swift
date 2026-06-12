import Foundation
import WeatherKit
import CoreLocation

// Lightweight wrappers and helpers around WeatherKit types for the app

struct WeatherData: Equatable {
    let location: SavedLocation
    let current: CurrentWeather
    let hourly: Forecast<HourWeather>
    let daily: Forecast<DayWeather>
    let fetchedAt: Date

    var currentCondition: WeatherCondition { current.condition }
    var currentTemp: Double { current.temperature.value }
    var feelsLike: Double { current.apparentTemperature.value }
    var high: Double { daily.first?.highTemperature.value ?? currentTemp }
    var low: Double { daily.first?.lowTemperature.value ?? currentTemp }
    var symbolName: String { weatherSymbol(for: current.condition, isDaylight: current.isDaylight) }
    var conditionDescription: String { current.condition.description }

    var precipitationChance: Double {
        hourly.first?.precipitationChance ?? 0
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp = Date()
    let imageData: Data?  // optional thumbnail for photo-based user messages (e.g. Storm Spotter); full data for API call + on assistant storm messages for regeneration (UI thumbnail only for .user)
    let isStormSpotterAnalysis: Bool
    let originalNotes: String?

    enum Role: String {
        case system
        case user
        case assistant
    }

    static func user(_ text: String) -> ChatMessage {
        ChatMessage(role: .user, content: text, imageData: nil, isStormSpotterAnalysis: false, originalNotes: nil)
    }

    static func assistant(_ text: String) -> ChatMessage {
        ChatMessage(role: .assistant, content: text, imageData: nil, isStormSpotterAnalysis: false, originalNotes: nil)
    }

    // For photo uploads with thumbnail (notes appended to content if provided)
    static func userWithPhoto(text: String, imageData: Data?) -> ChatMessage {
        ChatMessage(role: .user, content: text, imageData: imageData, isStormSpotterAnalysis: false, originalNotes: nil)
    }
}

enum QuickPrompt: String, CaseIterable, Identifiable {
    case grokTake = "Grok's Take"
    case outfit = "What to Wear"
    case activity = "Good for a Walk?"
    case weekend = "Weekend Outlook"
    case fun = "Fun Weather Fact"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .grokTake: "sparkles"
        case .outfit: "tshirt"
        case .activity: "figure.walk"
        case .weekend: "calendar"
        case .fun: "lightbulb"
        }
    }
    var prompt: String {
        switch self {
        case .grokTake: "Give me a short, witty Grok-style summary of today's weather and vibe."
        case .outfit: "Based on the current weather, temperature, wind, and UV, recommend what I should wear today. Be specific and fun."
        case .activity: "Is today a good day for an outdoor walk or hike? Consider temperature, precipitation chance, wind, and air quality if available. Give a yes/no with reason."
        case .weekend: "Summarize the weekend forecast in 2-3 sentences with activity suggestions."
        case .fun: "Tell me one interesting or surprising fact about today's weather or season in this location."
        }
    }
}

// Maps WeatherKit conditions to reliable SF Symbols
func weatherSymbol(for condition: WeatherCondition, isDaylight: Bool = true) -> String {
    switch condition {
    case .clear:
        return isDaylight ? "sun.max.fill" : "moon.stars.fill"
    case .mostlyClear:
        return isDaylight ? "sun.max.fill" : "moon.stars.fill"
    case .partlyCloudy:
        return isDaylight ? "cloud.sun.fill" : "cloud.moon.fill"
    case .mostlyCloudy:
        return "cloud.fill"
    case .cloudy:
        return "cloud.fill"
    case .foggy, .haze, .smoky:
        return "cloud.fog.fill"
    case .windy:
        return "wind"
    case .drizzle, .rain:
        return "cloud.rain.fill"
    case .heavyRain:
        return "cloud.heavyrain.fill"
    case .isolatedThunderstorms, .scatteredThunderstorms, .thunderstorms:
        return "cloud.bolt.rain.fill"
    case .hail:
        return "cloud.hail.fill"
    case .sleet:
        return "cloud.sleet.fill"
    case .snow, .flurries, .heavySnow:
        return "cloud.snow.fill"
    case .blowingSnow, .blowingDust:
        return "wind.snow"
    case .freezingDrizzle, .freezingRain:
        return "cloud.rain.fill" // could use custom
    case .frigid:
        return "thermometer.snowflake"
    case .hot:
        return "thermometer.sun"
    case .hurricane, .tropicalStorm:
        return "hurricane"
    case .sunFlurries:
        return "sun.snow"
    default:
        return isDaylight ? "sun.max.fill" : "moon.stars.fill"
    }
}

extension WeatherCondition {
    var shortDescription: String {
        switch self {
        case .clear: "Clear"
        case .mostlyClear: "Mostly Clear"
        case .partlyCloudy: "Partly Cloudy"
        case .mostlyCloudy: "Mostly Cloudy"
        case .cloudy: "Cloudy"
        case .foggy: "Fog"
        case .haze: "Haze"
        case .smoky: "Smoke"
        case .windy: "Windy"
        case .drizzle: "Drizzle"
        case .rain: "Rain"
        case .heavyRain: "Heavy Rain"
        case .isolatedThunderstorms: "Isolated T-Storms"
        case .scatteredThunderstorms: "Scattered T-Storms"
        case .thunderstorms: "Thunderstorms"
        case .snow: "Snow"
        case .heavySnow: "Heavy Snow"
        case .flurries: "Flurries"
        default: description
        }
    }
}