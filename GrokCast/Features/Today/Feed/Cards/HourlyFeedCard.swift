import SwiftUI

struct HourlyFeedCard: View {
  @Environment(WeatherStore.self) private var store
  let weather: GrokCastWeather
  var onTap: () -> Void

  private var hours: [HourlyForecast] {
    let cutoff = Date().addingTimeInterval(-45 * 60)
    let upcoming = weather.hourly.filter { $0.time >= cutoff }
    let slice = upcoming.isEmpty ? weather.hourly : upcoming
    return Array(slice.prefix(24))
  }

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
        HStack {
          Text("Hourly")
            .font(DesignTokens.Figma.Typography.subsectionLabel)
            .foregroundStyle(DesignTokens.Palette.textTertiary)
                .tracking(DesignTokens.Typography.cardLabelTracking)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: DesignTokens.Spacing.space12) {
            ForEach(Array(hours.enumerated()), id: \.element.time) { index, hour in
              HourlyRow(
                forecast: hour,
                isNow: index == 0,
                layout: .figma,
                timeZone: weather.locationTimeZone
              )
            }
          }
        }
        .frame(height: DesignTokens.Figma.Metrics.hourlyRowHeight + DesignTokens.Spacing.space8)
      }
      .padding(DesignTokens.Spacing.space16)
      .cardStyle()
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilitySummary)
    .accessibilityAddTraits(.isButton)
  }

  private var accessibilitySummary: String {
    guard let first = hours.first else {
      return "Hourly forecast. Opens full forecast."
    }
    let cal = weather.locationCalendar
    let now = Date()
    let isNow = cal.isDate(first.time, equalTo: now, toGranularity: .hour)
    let label = isNow ? "Now" : "Next hour"
    return
      "Hourly forecast. \(label) \(Int(round(first.temp))) degrees, \(first.precipChance) percent chance of precipitation. Opens full forecast."
  }
}
