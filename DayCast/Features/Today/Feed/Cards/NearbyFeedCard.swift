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

  static func fireAccessibility(title: String, subtitle: String) -> String {
    "Fire. \(title). \(subtitle) Opens details."
  }

  static func sunMoonAccessibility(
    sunrise: String,
    sunset: String,
    phase: String,
    litPercent: Int
  ) -> String {
    "Sun and moon. Sunrise \(sunrise), sunset \(sunset). \(phase), \(litPercent) percent illuminated. Opens details."
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
}

/// Fire plate when a local fire or fire-weather alert is live. Sun lives on
/// hourly ticks / Now detail — not an Accu-style strip.
struct NearbyFeedCard: View {
  var fire: FireFeedSummary
  var onFire: () -> Void
  var plated: Bool = true

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      Text("Nearby")
        .font(DesignTokens.Typography.studioTitle())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .accessibilityAddTraits(.isHeader)

      MetricTile(
        label: "Fire",
        value: NearbyTileCopy.fireValue(fire),
        support: NearbyTileCopy.fireSupport(fire),
        action: onFire,
        accessibilityLabel: NearbyTileCopy.fireAccessibility(
          title: fire.title, subtitle: fire.subtitle)
      )
    }
    .padding(plated ? DesignTokens.Spacing.space16 : 0)
    .frame(maxWidth: .infinity, alignment: .leading)
    .weatherModuleChrome(plated)
  }
}
