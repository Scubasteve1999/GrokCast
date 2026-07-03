import SwiftUI

private let bottomTabClearance = DesignTokens.Spacing.space32
/// Figma Forecast screen: content starts below status bar with modest top inset.
private let forecastContentTopPadding = DesignTokens.Spacing.space16

struct ForecastView: View {
  @Environment(WeatherStore.self) private var store

  var body: some View {
    NavigationStack {
      ZStack {
        TodaySkyBackground(
          conditionCode: store.currentWeather?.conditionCode ?? 1,
          isDay: store.currentWeather.map {
            WeatherBackgroundView.isDay(from: $0.symbolName)
          } ?? WeatherBackgroundView.inferredIsDay
        )
        .ignoresSafeArea()

        ForecastAdaptiveBody()
          .adaptiveContainerWidth(AdaptiveLayout.contentCap)
          .navigationTitle("")
          .navigationBarTitleDisplayMode(.inline)
      }
    }
    .preferredColorScheme(.dark)
  }
}

private struct ForecastAdaptiveBody: View {
  @Environment(WeatherStore.self) private var store
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.adaptiveContainerWidth) private var adaptiveContainerWidth

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
      if store.isLoadingWeather {  // --skeletons: shimmer for NWS primary loading states (Today, Forecast, Alerts)
        if awaitsWidthMeasurement {
          neutralForecastSkeleton
        } else if prefersWideLayout {
          wideForecastSkeleton
        } else {
          compactForecastSkeleton
        }
      } else if let weather = store.currentWeather {
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
  }

  @ViewBuilder
  private var errorBanner: some View {
    if let error = store.weatherError, !error.isEmpty {
      HStack(spacing: 8) {
        Image(systemName: store.isOffline ? "wifi.slash" : "exclamationmark.triangle.fill")
          .foregroundStyle(DesignTokens.Palette.danger)
        Text(error)
          .font(.caption)
          .foregroundStyle(DesignTokens.Palette.danger)
          .lineLimit(2)
        Spacer(minLength: 8)
        Button("Retry") {
          Haptic.impact(.medium)
          Task { await store.refreshWeather() }
        }
        .font(.caption.bold())
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
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space32) {
        forecastSectionHeader("Hourly — Next 24H")
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: DesignTokens.Spacing.space24) {
            ForEach(0..<8, id: \.self) { index in
              HourlyRowSkeleton(isNow: index == 0)
            }
          }
          .padding(.vertical, DesignTokens.Spacing.space8)
        }

        forecastSectionHeader("10-Day Outlook")
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
          ForEach(0..<6, id: \.self) { _ in
            DailyRowSkeleton()
          }
        }
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
        Text("FORECAST")
          .font(DesignTokens.Figma.Typography.screenTitle)
          .foregroundStyle(TodayBright.textPrimary)
          .skyTextShadow()

        TodaySectionHeader(title: "HOURLY", systemImage: "clock")
        ShimmerBlock(width: nil, height: 140, cornerRadius: DesignTokens.Card.cornerRadiusMedium)
          .todayGlassCard()

        TodaySectionHeader(title: "10-DAY", systemImage: "calendar")
        ShimmerBlock(width: nil, height: 220, cornerRadius: DesignTokens.Card.cornerRadiusMedium)
          .todayGlassCard()
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.top, forecastContentTopPadding)
      .padding(.bottom, bottomTabClearance)
    }
    .scrollContentBackground(.hidden)
    .refreshable {
      await store.refreshWeather()
    }
  }

  private var wideForecastSkeleton: some View {
    ScrollView {
      HStack(alignment: .top, spacing: DesignTokens.Spacing.space24) {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
          forecastSectionHeader("Hourly — Next 24H")
          LazyVGrid(
            columns: Array(
              repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.space12), count: 4),
            spacing: DesignTokens.Spacing.space16
          ) {
            ForEach(0..<24, id: \.self) { index in
              HourlyRowSkeleton(isNow: index == 0)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
          forecastSectionHeader("10-Day Outlook")
          ForEach(0..<6, id: \.self) { _ in
            DailyRowSkeleton()
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.top, DesignTokens.Spacing.space24)
      .padding(.bottom, bottomTabClearance)
    }
    .refreshable {
      await store.refreshWeather()
    }
  }

  private func neutralForecastContent(for weather: GrokCastWeather) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space32) {
        let hourly24 = Array(weather.hourly.prefix(24))
        let now = Date()
        let nowHourIndex = hourly24.firstIndex(where: { h in
          Calendar.current.isDate(h.time, equalTo: now, toGranularity: .hour)
        }) ?? 0

        forecastSectionHeader("Hourly — Next 24H")
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: DesignTokens.Spacing.space24) {
            ForEach(Array(hourly24.enumerated()), id: \.element.time) {
              index, hour in
              hourlyRow(forecast: hour, isNow: index == nowHourIndex)
            }
          }
          .padding(.vertical, DesignTokens.Spacing.space8)
        }

        openWeatherMapHybridSection

        forecastSectionHeader("10-Day Outlook")
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
          ForEach(weather.daily) { day in
            DailyRow(forecast: day)
          }
        }
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.top, DesignTokens.Spacing.space24)
      .padding(.bottom, bottomTabClearance)
    }
    .safeAreaInset(edge: .top) {
      errorBanner
    }
    .refreshable {
      await store.refreshWeather()
    }
  }

  private func compactForecastList(for weather: GrokCastWeather) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        Text("FORECAST")
          .font(DesignTokens.Figma.Typography.screenTitle)
          .foregroundStyle(TodayBright.textPrimary)
          .skyTextShadow()

        TodaySectionHeader(title: "HOURLY", systemImage: "clock")
        TodaySummaryHourlyCard(weather: weather)

        TodayTenDayCard(daily: weather.daily, currentTemp: weather.currentTemp)
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

  private func wideForecastContent(for weather: GrokCastWeather) -> some View {
    ScrollView {
      let hourly24 = Array(weather.hourly.prefix(24))
      let now = Date()
      let nowHourIndex = hourly24.firstIndex(where: { h in
        Calendar.current.isDate(h.time, equalTo: now, toGranularity: .hour)
      }) ?? 0

      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space24) {
        FigmaScreenTitle(title: "FORECAST")
          .padding(.bottom, DesignTokens.Spacing.space8)

        HStack(alignment: .top, spacing: DesignTokens.Spacing.space24) {
          VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
            forecastSectionHeader("Hourly — Next 24H")
            LazyVGrid(
              columns: Array(
                repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.space12), count: 4),
              spacing: DesignTokens.Spacing.space16
            ) {
              ForEach(Array(hourly24.enumerated()), id: \.element.time) {
                index, hour in
                hourlyRow(forecast: hour, isNow: index == nowHourIndex)
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
            openWeatherMapHybridSection
            forecastSectionHeader("10-Day Outlook")
            ForEach(weather.daily) { day in
              DailyRow(forecast: day)
            }
          }
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

  private func hourlyRow(
    forecast: HourlyForecast,
    isNow: Bool,
    layout: HourlyRowLayout = .standard
  ) -> some View {
    let hybrid = store.openWeatherMapEntry(closestTo: forecast.time)
    return HourlyRow(
      forecast: forecast,
      isNow: isNow,
      layout: layout,
      openWeatherMapTempF: hybrid.map { Int(round($0.temperatureF)) },
      openWeatherMapPrecipChance: hybrid?.precipitationChance
    )
  }

  private func figmaSectionHeader(_ title: String) -> some View {
    FigmaSubsectionLabel(title: title)
  }

  private var openWeatherMapSectionTitle: String {
    switch store.openWeatherMapService.lastDataSource {
    case .oneCall4:
      return "OpenWeatherMap — Hourly Outlook"
    case .legacy25, .none:
      return "OpenWeatherMap — 3-Hour Outlook"
    }
  }

  @ViewBuilder
  private var openWeatherMapHybridSection: some View {
    if let owm = store.openWeatherMapForecast, !owm.entries.isEmpty {
      forecastSectionHeader(openWeatherMapSectionTitle)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: DesignTokens.Spacing.space16) {
          ForEach(Array(owm.entries.prefix(8))) { entry in
            OpenWeatherMapForecastChip(entry: entry)
          }
        }
        .padding(.vertical, DesignTokens.Spacing.space8)
      }
    }
  }

  private func forecastSectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.system(size: 20, weight: .semibold))
      .tracking(DesignTokens.Typography.headerTracking)
      .foregroundStyle(DesignTokens.Palette.textPrimary)
      .padding(.bottom, DesignTokens.Spacing.space8)
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
