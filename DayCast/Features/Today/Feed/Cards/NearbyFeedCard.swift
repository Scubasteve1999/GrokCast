import SwiftUI

/// Copy for the Nearby tiles. Keep the US AQI number; name an official alert
/// instead of restating "Good" when NWS has an air-quality product up.
enum NearbyTileCopy {
  static func isAirQualityAlert(_ event: String) -> Bool {
    event.localizedCaseInsensitiveContains("air quality")
  }

  static func airQualitySupport(aqi: Int, hasNWSAirQualityAlert: Bool) -> String {
    if hasNWSAirQualityAlert { return "NWS alert" }
    return AirQualityCategory(usAQI: aqi).title
  }

  static func airQualityAccessibility(aqi: Int, title: String, guidance: String) -> String {
    "Air quality \(aqi), \(title). \(guidance) Opens details."
  }

  static func airQualityAccessibility(aqi: Int, hasNWSAirQualityAlert: Bool) -> String {
    let category = AirQualityCategory(usAQI: aqi)
    if hasNWSAirQualityAlert {
      return
        "Air quality \(aqi), \(category.title). NWS air quality alert in effect. Opens details."
    }
    return airQualityAccessibility(
      aqi: aqi, title: category.title, guidance: category.guidance)
  }

  static func fireValue(_ summary: FireFeedSummary) -> String {
    if summary.hotspotCount > 0 { return "\(summary.hotspotCount) pts" }
    if summary.incidentCount > 0 { return "\(summary.incidentCount)" }
    return "—"
  }

  static func fireSupport(_ summary: FireFeedSummary) -> String {
    if let miles = summary.distanceMiles {
      return String(format: "%.0f mi", miles)
    }
    return summary.title
  }

  static func fireAccessibility(title: String, subtitle: String) -> String {
    "Fire. \(title). \(subtitle) Opens details."
  }

  static func sunValue(sunrise: Date?, sunset: Date?, now: Date, timeZone: TimeZone) -> (
    value: String, support: String
  ) {
    let formatter = LocationTimezone.formatter(dateFormat: "h:mm a", timeZone: timeZone)
    if let sunset, now < sunset {
      return (formatter.string(from: sunset), "sunset")
    }
    if let sunrise {
      return (formatter.string(from: sunrise), "sunrise")
    }
    if let sunset {
      return (formatter.string(from: sunset), "sunset")
    }
    return ("--:--", "sun")
  }

  static func sunMoonAccessibility(
    sunrise: String,
    sunset: String,
    phase: String,
    litPercent: Int
  ) -> String {
    "Sun and moon. Sunrise \(sunrise), sunset \(sunset). \(phase), \(litPercent) percent illuminated. Opens details."
  }
}

/// One plate, Fire and Sun tiles. AQI lives on Conditions. Below the fold.
struct NearbyFeedCard: View {
  var fire: FireFeedSummary?
  var sunrise: Date?
  var sunset: Date?
  var timeZone: TimeZone = .current
  var now: Date = Date()
  var onFire: (() -> Void)?
  var onSunMoon: (() -> Void)?

  private var showsSun: Bool { sunrise != nil || sunset != nil }

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      Text("Nearby")
        .font(DesignTokens.Typography.studioTitle())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .accessibilityAddTraits(.isHeader)

      HStack(alignment: .top, spacing: DesignTokens.Spacing.space12) {
        if let fire, let onFire {
          MetricTile(
            label: "Fire",
            value: NearbyTileCopy.fireValue(fire),
            support: NearbyTileCopy.fireSupport(fire),
            action: onFire,
            accessibilityLabel: NearbyTileCopy.fireAccessibility(
              title: fire.title, subtitle: fire.subtitle)
          )
        }
        if showsSun, let onSunMoon {
          let sun = NearbyTileCopy.sunValue(
            sunrise: sunrise, sunset: sunset, now: now, timeZone: timeZone)
          MetricTile(
            label: "Sun",
            value: sun.value,
            support: sun.support,
            action: onSunMoon,
            accessibilityLabel: NearbyTileCopy.sunMoonAccessibility(
              sunrise: formatTime(sunrise),
              sunset: formatTime(sunset),
              phase: MoonPhase.phase(on: now).phase.displayName,
              litPercent: Int(round(MoonPhase.phase(on: now).illumination * 100))
            )
          )
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func formatTime(_ date: Date?) -> String {
    guard let date else { return "--:--" }
    return LocationTimezone.formatter(dateFormat: "h:mm a", timeZone: timeZone)
      .string(from: date)
  }
}
