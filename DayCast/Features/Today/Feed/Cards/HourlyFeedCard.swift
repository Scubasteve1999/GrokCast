import SwiftUI

struct HourlyFeedCard: View {
  @Environment(WeatherStore.self) private var store
  let weather: DayCastWeather
  var briefingItems: [LocalBriefingItem] = []
  var plated: Bool = true
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
        .font(DesignTokens.Typography.body())
        .foregroundStyle(DesignTokens.Palette.textSecondary)
        .lineLimit(3)
        .minimumScaleFactor(0.85)
        .fixedSize(horizontal: false, vertical: true)
        .frame(
          maxWidth: .infinity,
          minHeight: TodayGlanceLayout.hourlyTonightLineHeight,
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

      HourlySeriesPicker(options: seriesOptions, selection: $series, compact: false)
        .frame(height: TodayGlanceLayout.hourlyPickerHeight, alignment: .leading)
    }
    .padding(plated ? TodayGlanceLayout.hourlyCardPadding : 0)
    .weatherModuleChrome(plated)
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
      Text(outlook.period.outlookTitle)
        .font(DesignTokens.Typography.studioTitle())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)

      Spacer(minLength: 4)

      Image(systemName: "chevron.right")
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .accessibilityHidden(true)
    }
    .frame(minHeight: TodayGlanceLayout.hourlyHeaderHeight)
  }

  private var resolvedSeries: HourlyGraphSeries {
    seriesOptions.contains(series) ? series : .temp
  }

  private var accessibilitySummary: String {
    Self.accessibilityLabel(
      title: outlook.period.outlookTitle,
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
