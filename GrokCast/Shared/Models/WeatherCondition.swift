import Foundation

/// Canonical single source of truth for weather conditions based on WMO codes.
/// Handles mapping, day/night symbols, display text, precip labels, and background/mood categorization.
/// Night bias for tints is encapsulated here.
/// Replaces all duplicated WMO switch blocks across DynamicBackgroundView, WeatherBackgroundView,
/// ForecastView, NWSService, OpenMeteo* etc.
/// Backward-compatible via thin wrapper functions below (existing call sites unchanged).
enum WeatherCondition: Equatable {
  case clear
  case mainlyClear
  case overcast
  case fog
  case drizzle
  case rain
  case sleet
  case snow
  case snowGrains
  case rainShowers
  case snowShowers
  case thunderstorm
  case unknown

  /// Clean canonical initializer from WMO code (primary entry point).
  init(fromWMO code: Int) {
    switch code {
    case 0:
      self = .clear
    case 1, 2:
      self = .mainlyClear
    case 3:
      self = .overcast
    case 45, 48:
      self = .fog
    case 51, 53, 55:
      self = .drizzle
    case 61, 63, 65:
      self = .rain
    case 66, 67:
      self = .sleet
    case 71, 73, 75:
      self = .snow
    case 77:
      self = .snowGrains
    case 80, 81, 82:
      self = .rainShowers
    case 85, 86:
      self = .snowShowers
    case 95, 96, 99:
      self = .thunderstorm
    default:
      self = .unknown
    }
  }

  /// Symbol name (SF Symbol), with day/night awareness moved into the type.
  func symbolName(isDay: Bool = true) -> String {
    switch self {
    case .clear:
      return isDay ? "sun.max.fill" : "moon.stars.fill"
    case .mainlyClear:
      return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
    case .overcast:
      return "cloud.fill"
    case .fog:
      return "cloud.fog.fill"
    case .drizzle:
      return "cloud.drizzle.fill"
    case .rain:
      return "cloud.rain.fill"
    case .sleet:
      return "cloud.sleet.fill"
    case .snow, .snowGrains, .snowShowers:
      return "cloud.snow.fill"
    case .rainShowers:
      return "cloud.heavyrain.fill"
    case .thunderstorm:
      return "cloud.bolt.rain.fill"
    case .unknown:
      return isDay ? "cloud.sun.fill" : "moon.stars.fill"
    }
  }

  /// Human display text (e.g. for conditionText). NWS shortForecast may override at call site.
  var displayText: String {
    switch self {
    case .clear: return "Clear"
    case .mainlyClear: return "Mainly Clear"
    case .overcast: return "Overcast"
    case .fog: return "Fog"
    case .drizzle: return "Drizzle"
    case .rain: return "Rain"
    case .sleet: return "Sleet"
    case .snow: return "Snow"
    case .snowGrains: return "Snow Grains"
    case .rainShowers: return "Rain Showers"
    case .snowShowers: return "Snow Showers"
    case .thunderstorm: return "Thunderstorm"
    case .unknown: return "Variable"
    }
  }

  /// Short precip type label for UI (e.g. "45% Rain" in Forecast rows). Centralizes the old shortPrecipType.
  var shortPrecipType: String {
    switch self {
    case .drizzle, .rain, .rainShowers: return "Rain"
    case .sleet: return "Sleet"
    case .snow, .snowGrains, .snowShowers: return "Snow"
    case .thunderstorm: return "T-Storm"
    default: return "Precip"
    }
  }

  // MARK: - Background categorization (for WeatherBackgroundView + DynamicBackgroundView delegation)
  // Single source; eliminates duplicated WMO case lists.

  enum BackgroundCategory {
    case clear
    case partlyCloudy
    case overcast
    case fog
    case rain
    case sleet
    case snow
    case thunderstorm
    case neutral
  }

  var backgroundCategory: BackgroundCategory {
    switch self {
    case .clear: return .clear
    case .mainlyClear: return .partlyCloudy
    case .overcast: return .overcast
    case .fog: return .fog
    case .drizzle, .rain, .rainShowers: return .rain
    case .sleet: return .sleet
    case .snow, .snowGrains, .snowShowers: return .snow
    case .thunderstorm: return .thunderstorm
    case .unknown: return .neutral
    }
  }

  // MARK: - Dynamic mood category + tints (night bias moved here)
  // Used by DynamicBackgroundView to eliminate its private ConditionCategory + duplicated WMO + tint switches.

  enum MoodCategory {
    case clear
    case partlyCloudyOvercastFog
    case rain
    case thunderstorm
    case neutral
  }

  var moodCategory: MoodCategory {
    switch backgroundCategory {
    case .clear:
      return .clear
    case .partlyCloudy, .overcast, .fog:
      return .partlyCloudyOvercastFog
    case .rain, .sleet:
      return .rain
    case .snow:
      // Dynamic previously fell to neutral for snow; keep behavior via neutral here.
      return .neutral
    case .thunderstorm:
      return .thunderstorm
    case .neutral:
      return .neutral
    }
  }

  /// Returns the exact hex for mood tint (night bias encapsulated; view does Color(hex:)).
  /// Matches prior DynamicBackgroundView night/day tints exactly for no visual change.
  func moodTintHex(isDay: Bool) -> String {
    let cat = moodCategory
    if !isDay {
      // Night: cooler moodier bias across all (even clear).
      switch cat {
      case .clear: return "#0B0E16"
      case .partlyCloudyOvercastFog: return "#0C0F15"
      case .rain: return "#08101A"
      case .thunderstorm: return "#0D0A17"
      case .neutral: return "#0B0E14"
      }
    } else {
      switch cat {
      case .clear: return "#1C160E"
      case .partlyCloudyOvercastFog: return "#0E1015"
      case .rain: return "#0A111B"
      case .thunderstorm: return "#110C1B"
      case .neutral: return "#0F0F0F"
      }
    }
  }

  /// Mood overlay opacity. Night bias + per-cat values.
  func moodOpacity(isNight: Bool) -> Double {
    if isNight { return 0.18 }
    switch moodCategory {
    case .clear: return 0.12
    case .partlyCloudyOvercastFog: return 0.10
    case .rain: return 0.15
    case .thunderstorm: return 0.17
    case .neutral: return 0.10
    }
  }
}

// MARK: - NWS short forecast to WMO (centralized; night not relevant for code itself)
extension WeatherCondition {
  /// Maps NWS shortForecast text to a WMO code for reuse of symbol/text/precip logic.
  static func wmoCode(fromNWSShortForecast short: String) -> Int {
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
}

// MARK: - Backward compatibility thin wrappers (delegating to canonical type)
// Existing call sites (OpenMeteoService, NWSService, WeatherModels, Forecast etc) continue to work unchanged.
// Visual behavior and values identical. Future: callers can migrate to WeatherCondition directly.

/// WMO code -> (SF Symbol name, display text). Delegates to WeatherCondition (single source).
func mapWeatherCode(_ code: Int, isDay: Bool = true) -> (symbol: String, text: String) {
  let cond = WeatherCondition(fromWMO: code)
  return (cond.symbolName(isDay: isDay), cond.displayText)
}

/// NWS text -> WMO code. Delegates to WeatherCondition.
func wmoCode(fromNWSShortForecast short: String) -> Int {
  WeatherCondition.wmoCode(fromNWSShortForecast: short)
}
