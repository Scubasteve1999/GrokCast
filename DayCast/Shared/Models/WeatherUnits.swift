import Foundation

enum TemperatureUnit: String, CaseIterable, Codable, Identifiable {
  case fahrenheit
  case celsius

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .fahrenheit: "Fahrenheit (°F)"
    case .celsius: "Celsius (°C)"
    }
  }

  /// One VoiceOver name for the Settings units row. The chevron sibling stays visual-only.
  var settingsRowAccessibilityLabel: String {
    "Temperature, \(displayName)"
  }

  var openMeteoTemperatureUnit: String {
    switch self {
    case .fahrenheit: "fahrenheit"
    case .celsius: "celsius"
    }
  }

  var openMeteoWindSpeedUnit: String {
    switch self {
    case .fahrenheit: "mph"
    case .celsius: "kmh"
    }
  }

  /// Compact UI label, e.g. `72°` (matches existing DayCast typography).
  func formatShort(_ value: Double) -> String {
    "\(Int(round(value)))°"
  }

  /// Full label for prompts and accessibility, e.g. `72°F`.
  func format(_ value: Double) -> String {
    switch self {
    case .fahrenheit: "\(Int(round(value)))°F"
    case .celsius: "\(Int(round(value)))°C"
    }
  }

  func formatWind(_ value: Double) -> String {
    switch self {
    case .fahrenheit: "\(Int(round(value))) mph"
    case .celsius: "\(Int(round(value))) km/h"
    }
  }

  /// NWS observations are °F. Convert when the app is in Celsius.
  func formatFromFahrenheit(_ fahrenheit: Double) -> String {
    switch self {
    case .fahrenheit: format(fahrenheit)
    case .celsius: format((fahrenheit - 32) * 5 / 9)
    }
  }

  /// NWS observations are mph. Convert when the app is in Celsius.
  func formatWindFromMph(_ mph: Double) -> String {
    switch self {
    case .fahrenheit: formatWind(mph)
    case .celsius: formatWind(mph * 1.609_34)
    }
  }
}
