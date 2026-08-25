import SwiftUI

private let bottomTabClearance = DesignTokens.Layout.tabBarScrollClearance
/// Figma Forecast screen: content starts below status bar with modest top inset.
private let forecastContentTopPadding = DesignTokens.Spacing.space16

struct ForecastView: View {
  @Environment(WeatherStore.self) private var store

  var body: some View {
    NavigationStack {
      ZStack {
        WeatherBackgroundLayer(
          conditionCode: store.displayedWeather?.conditionCode,
          isDay: store.displayedWeather.map {
            WeatherBackgroundView.isDay(from: $0.symbolName)
          }
            ?? WeatherBackgroundView.inferredIsDay(
              timeZone: store.displayedWeather?.locationTimeZone ?? .current
            ),
          intensity: .staticOnly,
          extraOpacity: 1.0
        )

        ForecastAdaptiveBody()
          .adaptiveContainerWidth(AdaptiveLayout.contentCap)
      }
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
    }
    .preferredColorScheme(.dark)
  }
}

private struct ForecastAdaptiveBody: View {
  @Environment(WeatherStore.self) private var store
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.adaptiveContainerWidth) private var adaptiveContainerWidth
  @State private var selectedDay: DailyForecast?
  @State private var showOpenWeatherMapCompare = false

  private var awaitsWidthMeasurement: Bool {
    AdaptiveLayout.awaitingWidthMeasurement(
      width: adaptiveContainerWidth,
      horizontalSizeClass: horizontalSizeClass
    )
  }

  private var prefersWideLayout: Bool {
    AdaptiveLayout.prefersTwoColumn(
      width: adaptiveContainerWidth,
      horizontalSizeClass: horizontalSizeClass
    )
  }

  var body: some View {
    Group {
      if store.displayedWeather == nil && store.isLoadingWeather {
        if awaitsWidthMeasurement {
          neutralForecastSkeleton
        } else if prefersWideLayout {
          wideForecastSkeleton
        } else {
          compactForecastSkeleton
        }
      } else if let weather = store.displayedWeather {
        if awaitsWidthMeasurement {
          neutralForecastContent(for: weather)
        } else if prefersWideLayout {
          wideForecastContent(for: weather)
        } else {
          compactForecastList(for: weather)
        }
      } else if let error = store.weatherError, !error.isEmpty {
        forecastUnavailableState(
          title: "Unable to Load Forecast",
          systemImage: store.isOffline ? "wifi.slash" : "exclamationmark.triangle",
          description: error,
          actionTitle: "Retry"
        ) {
          Task { await store.refreshWeather() }
        }
      } else {
        forecastUnavailableState(
          title: "No Forecast Data",
          systemImage: "calendar",
          description: "Select a location from the Locations tab or pull to refresh.",
          actionTitle: "Refresh"
        ) {
          Task { await store.refreshWeather() }
        }
      }
    }
    .sheet(item: $selectedDay) { day in
      ForecastDayDetailSheet(
        forecast: day,
        calendar: store.displayedWeather?.locationCalendar ?? .current,
        timeZone: store.displayedWeather?.locationTimeZone ?? .current
      )
    }
  }

  @ViewBuilder
  private var errorBanner: some View {
    if let error = store.weatherError, !error.isEmpty {
      HStack(spacing: 8) {
        Image(systemName: store.isOffline ? "wifi.slash" : "exclamationmark.triangle.fill")
          .foregroundStyle(DesignTokens.Palette.danger)
        Text(error)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.danger)
          .lineLimit(2)
        Spacer(minLength: 8)
        Button("Retry") {
          Haptic.impact(.medium)
          Task { await store.refreshWeather() }
        }
        .font(DesignTokens.Typography.caption())
        .buttonStyle(.bordered)
        .tint(DesignTokens.Palette.danger)
        .controlSize(.small)
      }
      .padding(DesignTokens.Spacing.space8)
      .background(DesignTokens.Palette.danger.opacity(0.15))
      .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
    }
  }

  private var neutralForecastSkeleton: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        FigmaScreenTitle(title: "Forecast")
        HourlyGraphSkeleton()

        ForecastDailySkeleton()
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.top, DesignTokens.Spacing.space24)
      .padding(.bottom, bottomTabClearance)
    }
    .refreshable {
      await store.refreshWeather()
    }

  }

  private var compactForecastSkeleton: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        FigmaScreenTitle(title: "Forecast")

        HourlyGraphSkeleton()

        ForecastDailySkeleton()
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.top, forecastContentTopPadding)
      .padding(.bottom, bottomTabClearance)
    }
    .refreshable {
      await store.refreshWeather()
    }

  }

  private var wideForecastSkeleton: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        FigmaScreenTitle(title: "Forecast")
        HStack(alignment: .top, spacing: DesignTokens.Spacing.space24) {
          VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
            HourlyGraphSkeleton()
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          ForecastDailySkeleton()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.top, forecastContentTopPadding)
      .padding(.bottom, bottomTabClearance)
    }
    .refreshable {
      await store.refreshWeather()
    }
  }

  private func neutralForecastContent(for weather: DayCastWeather) -> some View {
    ScrollView {
      let timeZone = weather.locationTimeZone

      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        FigmaScreenTitle(title: "Forecast")

        ForecastHourlySection(weather: weather)

        openWeatherMapCompareSection(timeZone: timeZone)

        ForecastDailySection(weather: weather) { selectedDay = $0 }
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.top, forecastContentTopPadding)
      .padding(.bottom, bottomTabClearance)
    }
    .safeAreaInset(edge: .top) {
      errorBanner
    }
    .refreshable {
      await store.refreshWeather()
    }
  }

  private func compactForecastList(for weather: DayCastWeather) -> some View {
    ScrollView {
      let timeZone = weather.locationTimeZone

      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        FigmaScreenTitle(title: "Forecast")

        ForecastHourlySection(weather: weather)

        openWeatherMapCompareSection(timeZone: timeZone)

        ForecastDailySection(weather: weather) { selectedDay = $0 }
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.top, forecastContentTopPadding)
      .padding(.bottom, bottomTabClearance)
    }
    .safeAreaInset(edge: .top) {
      errorBanner
    }
    .refreshable {
      await store.refreshWeather()
    }

  }

  private func wideForecastContent(for weather: DayCastWeather) -> some View {
    ScrollView {
      let timeZone = weather.locationTimeZone

      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        FigmaScreenTitle(title: "Forecast")

        HStack(alignment: .top, spacing: DesignTokens.Spacing.space24) {
          VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
            ForecastHourlySection(weather: weather)
            openWeatherMapCompareSection(timeZone: timeZone)
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          ForecastDailySection(weather: weather) { selectedDay = $0 }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.top, forecastContentTopPadding)
      .padding(.bottom, bottomTabClearance)
    }
    .safeAreaInset(edge: .top) {
      errorBanner
    }
    .refreshable {
      await store.refreshWeather()
    }
  }

  @ViewBuilder
  private func openWeatherMapCompareSection(timeZone: TimeZone = .current) -> some View {
    if let owm = store.openWeatherMapForecast, !owm.entries.isEmpty {
      DisclosureGroup(isExpanded: $showOpenWeatherMapCompare) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: DesignTokens.Spacing.space8) {
            ForEach(Array(owm.entries.prefix(8))) { entry in
              OpenWeatherMapForecastChip(
                entry: entry, layout: .figma, timeZone: timeZone)
            }
          }
          .padding(.top, DesignTokens.Spacing.space8)
        }
      } label: {
        Text("Compare \(openWeatherMapCompactTitle)")
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }
      .tint(DesignTokens.Palette.textTertiary)
    }
  }

  private var openWeatherMapCompactTitle: String {
    switch store.openWeatherMapService.lastDataSource {
    case .oneCall4:
      return "OpenWeatherMap"
    case .legacy25, .none:
      return "OpenWeatherMap"
    }
  }

  private func forecastUnavailableState(
    title: String,
    systemImage: String,
    description: String,
    actionTitle: String,
    action: @escaping () -> Void
  ) -> some View {
    ScrollView {
      ContentUnavailableView {
        Label(title, systemImage: systemImage)
      } description: {
        Text(description)
      } actions: {
        Button(actionTitle) {
          Haptic.impact(.medium)
          action()
        }
        .buttonStyle(.borderedProminent)
      }
      .padding(DesignTokens.Spacing.space16)
      .frame(maxWidth: .infinity, minHeight: 400)
      .cardStyle(
        background: DesignTokens.Palette.cardBackground,
        stroke: DesignTokens.Palette.cardStroke,
        cornerRadius: DesignTokens.Card.cornerRadiusMedium
      )
      .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.top, DesignTokens.Spacing.space24)
      .padding(.bottom, bottomTabClearance)
    }
    .refreshable {
      await store.refreshWeather()
    }
  }

}

private struct ForecastHourlySection: View {
  let weather: DayCastWeather
  @State private var series: HourlyGraphSeries = .temp

  private var hours: [HourlyForecast] {
    HourlyGraphHours.upcoming(from: weather)
  }

  private var seriesOptions: [HourlyGraphSeries] {
    HourlyGraphSeries.available(in: hours)
  }

  private var resolvedSeries: HourlyGraphSeries {
    seriesOptions.contains(series) ? series : .temp
  }

  var body: some View {
    VStack(alignment: .leading, spacing: TodayGlanceLayout.hourlyInnerSpacing) {
      HStack(spacing: DesignTokens.Spacing.space8) {
        Text("Hourly")
          .font(DesignTokens.Typography.subsection())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
          .tracking(DesignTokens.Typography.cardLabelTracking)
          .lineLimit(1)
        Spacer(minLength: 4)
        HourlySeriesPicker(options: seriesOptions, selection: $series)
      }
      .frame(height: TodayGlanceLayout.hourlyHeaderHeight)

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
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilitySummary)
  }

  private var accessibilitySummary: String {
    HourlyFeedCard.accessibilityLabel(
      title: "Hourly",
      hourLabel: hours.isEmpty ? nil : "Now",
      temp: hours.first.map { Int(round($0.temp)) },
      precipChance: hours.first?.precipChance,
      opensForecast: false
    )
  }
}

private struct ForecastDailySection: View {
  let weather: DayCastWeather
  var onSelect: (DailyForecast) -> Void

  private var periodLow: Double? { weather.daily.map(\.low).min() }
  private var periodHigh: Double? { weather.daily.map(\.high).max() }

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      Text("10-Day")
        .font(DesignTokens.Typography.subsection())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .tracking(DesignTokens.Typography.cardLabelTracking)

      VStack(spacing: 0) {
        ForEach(weather.daily) { day in
          DailyRow(
            forecast: day,
            layout: .figma,
            periodLow: periodLow,
            periodHigh: periodHigh,
            calendar: weather.locationCalendar,
            timeZone: weather.locationTimeZone,
            onSelect: { onSelect(day) }
          )
        }
      }
    }
    .padding(DesignTokens.Spacing.space16)
    .cardStyle()
  }
}

private struct ForecastDailySkeleton: View {
  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      ShimmerBlock(width: 72, height: 12, cornerRadius: 4)
      VStack(spacing: 0) {
        ForEach(0..<6, id: \.self) { index in
          DailyRowSkeleton(layout: .figma, isToday: index == 0)
        }
      }
    }
    .padding(DesignTokens.Spacing.space16)
    .cardStyle()
  }
}

#Preview("Forecast — iPhone") {
  ForecastView()
    .environment(WeatherStore())
}

#Preview("Forecast — 700pt regular") {
  ForecastView()
    .environment(WeatherStore())
    .frame(width: 700, height: 900)
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("Forecast — iPad Pro 11-inch (M4)") {
  ForecastView()
    .environment(WeatherStore())
}
