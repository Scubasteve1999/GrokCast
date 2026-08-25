import SwiftUI

struct HourlyFeedCard: View {
  @Environment(WeatherStore.self) private var store
  let weather: DayCastWeather
  var briefingItems: [LocalBriefingItem] = []
  var onTap: () -> Void

  @State private var series: HourlyGraphSeries = .temp

  private var hours: [HourlyForecast] {
    HourlyGraphHours.upcoming(from: weather)
  }

  private var outlook: TonightOutlook.Result {
    TonightOutlook.make(
      weather: weather,
      briefingItems: briefingItems,
      unit: store.temperatureUnit
    )
  }

  private var seriesOptions: [HourlyGraphSeries] {
    HourlyGraphSeries.available(in: hours)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: TodayGlanceLayout.hourlyInnerSpacing) {
      header
      Text(outlook.sentence)
        .font(DesignTokens.Typography.callout())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .lineLimit(2)
        .minimumScaleFactor(0.85)
        .frame(
          maxWidth: .infinity,
          minHeight: TodayGlanceLayout.hourlyTonightLineHeight,
          maxHeight: TodayGlanceLayout.hourlyTonightLineHeight,
          alignment: .topLeading
        )

      HourlyGraphView(
        hours: hours,
        series: resolvedSeries,
        sunrise: weather.daily.first?.sunrise,
        sunset: weather.daily.first?.sunset,
        timeZone: weather.locationTimeZone
      )
      .frame(height: TodayGlanceLayout.hourlyGraphHeight)
    }
    .padding(TodayGlanceLayout.hourlyCardPadding)
    .cardStyle()
    .contentShape(Rectangle())
    .onTapGesture {
      onTap()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilitySummary)
    .accessibilityAddTraits(.isButton)
  }

  private var header: some View {
    HStack(spacing: DesignTokens.Spacing.space8) {
      Text(outlook.title)
        .font(DesignTokens.Typography.subsection())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .tracking(DesignTokens.Typography.cardLabelTracking)
        .lineLimit(1)

      Spacer(minLength: 4)

      HourlySeriesPicker(options: seriesOptions, selection: $series)

      Image(systemName: "chevron.right")
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .accessibilityHidden(true)
    }
    .frame(height: TodayGlanceLayout.hourlyHeaderHeight)
  }

  private var resolvedSeries: HourlyGraphSeries {
    seriesOptions.contains(series) ? series : .temp
  }

  private var accessibilitySummary: String {
    Self.accessibilityLabel(
      title: outlook.title,
      sentence: outlook.sentence,
      hourLabel: hours.isEmpty ? nil : "Now",
      temp: hours.first.map { Int(round($0.temp)) },
      precipChance: hours.first?.precipChance
    )
  }

  /// One VoiceOver string for the whole card. Children stay visual-only.
  static func accessibilityLabel(
    title: String? = nil,
    sentence: String? = nil,
    hourLabel: String?,
    temp: Int?,
    precipChance: Int?,
    opensForecast: Bool = true
  ) -> String {
    var parts: [String] = []
    if let title, !title.isEmpty { parts.append(title) }
    if let sentence, !sentence.isEmpty { parts.append(sentence) }
    if let hourLabel, let temp, let precipChance {
      parts.append(
        "\(hourLabel) \(temp) degrees, \(precipChance) percent chance of precipitation.")
    }
    if parts.isEmpty {
      return opensForecast ? "Hourly forecast. Opens full forecast." : "Hourly forecast."
    }
    if opensForecast {
      parts.append("Opens full forecast.")
    }
    return parts.joined(separator: " ")
  }
}
