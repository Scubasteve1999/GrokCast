import SwiftUI

/// Conditions 2×2 on the Today sheet: precip, humidity, visibility, AQI.
/// Pollen stays off this grid; it hides when the region has no data elsewhere.
struct HealthFeedCard: View {
  @Environment(WeatherStore.self) private var store
  let weather: DayCastWeather
  var hasNWSAirQualityAlert: Bool = false
  var onAirQuality: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      Text(ConditionsCopy.title)
        .font(DesignTokens.Typography.studioTitle())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .accessibilityAddTraits(.isHeader)

      LazyVGrid(
        columns: [
          GridItem(.flexible(), spacing: DesignTokens.Spacing.space12),
          GridItem(.flexible(), spacing: DesignTokens.Spacing.space12),
        ],
        spacing: DesignTokens.Spacing.space12
      ) {
        conditionTile(
          label: "Precipitation",
          value: precip.value,
          support: precip.support,
          accessibilityLabel: "Precipitation \(precip.value), \(precip.support)"
        )
        conditionTile(
          label: "Humidity",
          value: "\(weather.humidity)%",
          support: ConditionsCopy.humiditySupport(weather.humidity),
          accessibilityLabel:
            "Humidity \(weather.humidity) percent, \(ConditionsCopy.humiditySupport(weather.humidity))"
        )
        conditionTile(
          label: "Visibility",
          value: HourlyDetailMetrics.visibilityValue(weather.visibilityMeters, unit: store.temperatureUnit),
          support: weather.visibilityMeters == nil ? "Unavailable" : "Current",
          accessibilityLabel: visibilityAccessibility
        )
        if let aqi = weather.airQualityIndex {
          let category = AirQualityCategory(usAQI: aqi)
          conditionTile(
            label: "Air Quality",
            value: "\(aqi)",
            support: NearbyTileCopy.airQualitySupport(
              aqi: aqi, hasNWSAirQualityAlert: hasNWSAirQualityAlert),
            valueColor: category.color,
            accessibilityLabel: NearbyTileCopy.airQualityAccessibility(
              aqi: aqi, hasNWSAirQualityAlert: hasNWSAirQualityAlert),
            action: onAirQuality
          )
        } else {
          conditionTile(
            label: "Air Quality",
            value: HourlyDetailMetrics.unknown,
            support: "Unavailable",
            accessibilityLabel: "Air quality unavailable"
          )
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityIdentifier(DayCastAccessibility.Today.health)
  }

  private var precip: (value: String, support: String) {
    ConditionsCopy.precipTile(weather: weather, unit: store.temperatureUnit)
  }

  private var visibilityAccessibility: String {
    let value = HourlyDetailMetrics.visibilityValue(
      weather.visibilityMeters, unit: store.temperatureUnit)
    if weather.visibilityMeters == nil {
      return "Visibility unavailable"
    }
    return "Visibility \(value)"
  }

  @ViewBuilder
  private func conditionTile(
    label: String,
    value: String,
    support: String,
    valueColor: Color = DesignTokens.Palette.textPrimary,
    accessibilityLabel: String,
    action: (() -> Void)? = nil
  ) -> some View {
    let content = VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
      Text(label)
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textSecondary)
      Text(value)
        .font(DesignTokens.Typography.metric())
        .foregroundStyle(valueColor)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .monospacedDigit()
      Text(support)
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textSecondary)
        .lineLimit(1)
    }
    .padding(DesignTokens.Spacing.space12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
        .fill(DesignTokens.Palette.cardBackground.opacity(0.55))
    )

    if let action {
      Button(action: action) {
        content.contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(accessibilityLabel)
    } else {
      content.accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
  }
}
