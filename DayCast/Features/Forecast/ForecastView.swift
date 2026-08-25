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
      .weatherShowsThroughNavigationBar()
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
        ForecastScreenHeader(locationName: nil)
        HourlyGraphSkeleton(style: .full)

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
        ForecastScreenHeader(locationName: nil)

        HourlyGraphSkeleton(style: .full)

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
        ForecastScreenHeader(locationName: nil)
        HStack(alignment: .top, spacing: DesignTokens.Spacing.space24) {
          VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
            HourlyGraphSkeleton(style: .full)
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
        ForecastScreenHeader(locationName: weather.location.name)

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

      VStack(spacing: 0) {
        ForecastScreenHeader(locationName: weather.location.name)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, DesignTokens.Spacing.space20)
          .padding(.top, forecastContentTopPadding)
          .padding(.bottom, DesignTokens.Spacing.space16)

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space24) {
          ForecastHourlySection(weather: weather, plated: false)
          openWeatherMapCompareSection(timeZone: timeZone)
          ForecastDailySection(weather: weather, plated: false) { selectedDay = $0 }
        }
        .padding(.horizontal, DesignTokens.Spacing.space20)
        .padding(.top, DesignTokens.Spacing.space20)
        .padding(.bottom, bottomTabClearance)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Palette.bgSecondary)
        .clipShape(
          UnevenRoundedRectangle(
            topLeadingRadius: TodayGlanceLayout.sheetTopRadius,
            topTrailingRadius: TodayGlanceLayout.sheetTopRadius,
            style: .continuous
          )
        )
      }
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
        ForecastScreenHeader(locationName: weather.location.name)

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

private struct ForecastScreenHeader: View {
  let locationName: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      FigmaScreenTitle(title: "Forecast")
        .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
      if let locationName, !locationName.isEmpty {
        Text(locationName)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
      } else {
        ShimmerBlock(width: 120, height: 12, cornerRadius: 4)
      }
    }
  }
}

private struct ForecastHourlySection: View {
  @Environment(WeatherStore.self) private var store
  @Environment(LocalBriefingStore.self) private var briefingStore
  let weather: DayCastWeather
  var plated: Bool = true
  @State private var series: HourlyGraphSeries = .temp
  @State private var inspectedHour: HourlyForecast?

  private var hours: [HourlyForecast] {
    HourlyGraphHours.upcoming(from: weather, limit: HourlyGraphHours.fullLimit)
  }

  private var briefingItems: [LocalBriefingItem] {
    guard let locID = store.currentLocation?.id.uuidString,
      briefingStore.locationID == locID
    else { return [] }
    return briefingStore.items
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

  private var resolvedSeries: HourlyGraphSeries {
    seriesOptions.contains(series) ? series : .temp
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      Text("Hourly")
        .font(DesignTokens.Typography.studioTitle())
        .foregroundStyle(DesignTokens.Palette.textPrimary)

      Text(outlook.period.outlookTitle)
        .font(DesignTokens.Typography.subsection())
        .foregroundStyle(DesignTokens.Palette.textSecondary)

      Text(outlook.sentence)
        .font(DesignTokens.Typography.body())
        .foregroundStyle(DesignTokens.Palette.textSecondary)
        .lineLimit(3)
        .minimumScaleFactor(0.85)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel(outlook.sentence)

      HourlyGraphView(
        hours: hours,
        series: resolvedSeries,
        style: .full,
        sunEvents: HourlyGraphSunEvent.inWindow(days: weather.daily, hours: hours),
        timeZone: weather.locationTimeZone,
        calendar: weather.locationCalendar,
        onInspectedHourChange: { inspectedHour = $0 }
      )
      .frame(height: HourlyGraphLayout.height(for: .full))

      HourlySeriesPicker(options: seriesOptions, selection: $series, compact: false)

      if let hour = inspectedHour ?? hours.first {
        HourlyDetailGrid(hour: hour, unit: store.temperatureUnit)
      }

      ForecastHourlyList(
        hours: hours,
        unit: store.temperatureUnit,
        calendar: weather.locationCalendar,
        timeZone: weather.locationTimeZone
      )
    }
    .padding(plated ? DesignTokens.Spacing.space16 : 0)
    .weatherModuleChrome(plated)
  }
}

private struct ForecastDailySection: View {
  @Environment(WeatherStore.self) private var store
  let weather: DayCastWeather
  var plated: Bool = true
  var onSelect: (DailyForecast) -> Void
  @State private var selectedID: Date?

  private var days: [DailyForecast] { weather.daily }
  private var periodLow: Double? { days.map(\.low).min() }
  private var periodHigh: Double? { days.map(\.high).max() }
  private var selected: DailyForecast? {
    days.first(where: { $0.id == selectedID }) ?? days.first
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      Text("Daily")
        .font(DesignTokens.Typography.studioTitle())
        .foregroundStyle(DesignTokens.Palette.textPrimary)

      WeekDayChipStrip(
        days: days,
        selectedID: selected?.id,
        calendar: weather.locationCalendar,
        timeZone: weather.locationTimeZone,
        unit: store.temperatureUnit,
        periodLow: periodLow,
        periodHigh: periodHigh,
        onSelect: { selectedID = $0.id }
      )

      if let selected {
        Button {
          Haptic.selection()
          onSelect(selected)
        } label: {
          Text(
            DailyOutlook.sentence(
              day: selected,
              unit: store.temperatureUnit,
              calendar: weather.locationCalendar,
              timeZone: weather.locationTimeZone
            )
          )
          .font(DesignTokens.Typography.body())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens day details")

        DailySelectedMetrics(
          day: selected,
          unit: store.temperatureUnit,
          timeZone: weather.locationTimeZone
        )
      }
    }
    .padding(plated ? DesignTokens.Spacing.space16 : 0)
    .weatherModuleChrome(plated)
    .onAppear {
      if selectedID == nil { selectedID = days.first?.id }
    }
  }
}

private struct DailySelectedMetrics: View {
  let day: DailyForecast
  var unit: TemperatureUnit
  var timeZone: TimeZone = .current

  var body: some View {
    LazyVGrid(
      columns: [
        GridItem(.flexible(), spacing: DesignTokens.Spacing.space16),
        GridItem(.flexible(), spacing: DesignTokens.Spacing.space16),
      ],
      alignment: .leading,
      spacing: DesignTokens.Spacing.space16
    ) {
      metric("Temperature", unit.formatShort(day.high))
      metric("Low", unit.formatShort(day.low))
      metric("Condition", WeatherCondition(fromWMO: day.weatherCode).displayText)
      metric(
        "Precipitation",
        day.precipChance > 0 ? "\(day.precipChance)%" : HourlyDetailMetrics.unknown
      )
      if let uv = day.uvMax {
        metric("UV Index", "\(Int(round(uv))) · \(UVCategory(index: uv).title)")
      }
      if let rise = day.sunrise {
        metric("Sunrise", time(rise))
      }
      if let set = day.sunset {
        metric("Sunset", time(set))
      }
    }
  }

  private func metric(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textSecondary)
      Text(value)
        .font(DesignTokens.Typography.headline())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func time(_ date: Date) -> String {
    LocationTimezone.formatter(dateFormat: "h:mm a", timeZone: timeZone)
      .string(from: date)
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
    .weatherModuleStyle()
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
