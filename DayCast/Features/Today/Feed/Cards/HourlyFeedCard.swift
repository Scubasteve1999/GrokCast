import SwiftUI

struct HourlyFeedCard: View {
  @Environment(WeatherStore.self) private var store
  let weather: DayCastWeather
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
            .font(DesignTokens.Typography.subsection())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
                .tracking(DesignTokens.Typography.cardLabelTracking)
          Spacer()
          Image(systemName: "chevron.right")
            .font(DesignTokens.Typography.caption())
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
        .frame(height: DesignTokens.Layout.hourlyRowHeight + DesignTokens.Spacing.space24)
      }
      .padding(DesignTokens.Spacing.space16)
      .cardStyle()
      .accessibilityHidden(true)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilitySummary)
  }

  private var accessibilitySummary: String {
    guard let first = hours.first else {
      return Self.accessibilityLabel(hourLabel: nil, temp: nil, precipChance: nil)
    }
    let cal = weather.locationCalendar
    let now = Date()
    let isNow = cal.isDate(first.time, equalTo: now, toGranularity: .hour)
    return Self.accessibilityLabel(
      hourLabel: isNow ? "Now" : "Next hour",
      temp: Int(round(first.temp)),
      precipChance: first.precipChance
    )
  }

  /// One VoiceOver string for the whole card. Children stay visual-only.
  static func accessibilityLabel(hourLabel: String?, temp: Int?, precipChance: Int?) -> String {
    guard let hourLabel, let temp, let precipChance else {
      return "Hourly forecast. Opens full forecast."
    }
    return
      "Hourly forecast. \(hourLabel) \(temp) degrees, \(precipChance) percent chance of precipitation. Opens full forecast."
  }
}
