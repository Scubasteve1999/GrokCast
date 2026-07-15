import Foundation  // for Date etc if needed
import SwiftUI

struct ForecastView: View {
  @Environment(WeatherStore.self) private var store

  var body: some View {
    NavigationStack {
      ForecastAdaptiveBody()
        .adaptiveContainerWidth(AdaptiveLayout.contentCap)
        .navigationTitle("FORECAST")
        .navigationBarTitleDisplayMode(.large)
    }
    .weatherBackground(
      conditionCode: store.currentWeather?.conditionCode,
      isDay: store.currentWeather.map {
        WeatherBackgroundView.isDay(from: $0.symbolName)
      } ?? WeatherBackgroundView.inferredIsDay,
      intensity: .subtle
    )
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
          .foregroundStyle(.red)
        Text(error)
          .font(.caption)
          .foregroundStyle(.red)
          .lineLimit(2)
        Spacer(minLength: 8)
        Button("Retry") {
          Haptic.impact(.medium)
          Task { await store.refreshWeather() }
        }
        .font(.caption.bold())
        .buttonStyle(.bordered)
        .tint(.red)
        .controlSize(.small)
      }
      .padding(8)
      .background(Color.red.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }

  private var neutralForecastSkeleton: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        forecastSectionHeader("HOURLY — NEXT 24H")
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 16) {
            ForEach(0..<8, id: \.self) { index in
              HourlyRowSkeleton(isNow: index == 0)
            }
          }
          .padding(.vertical, 6)
        }

        forecastSectionHeader("10-DAY OUTLOOK")
        ForEach(0..<6, id: \.self) { _ in
          DailyRowSkeleton()
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
    }
    .refreshable {
      await store.refreshWeather()
    }
  }

  private var compactForecastSkeleton: some View {
    List {
      Section("HOURLY — NEXT 24H") {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 16) {
            ForEach(0..<8, id: \.self) { index in
              HourlyRowSkeleton(isNow: index == 0)
            }
          }
          .padding(.vertical, 6)
        }
      }

      Section("10-DAY OUTLOOK") {
        ForEach(0..<6, id: \.self) { _ in
          DailyRowSkeleton()
        }
      }
    }
    .scrollContentBackground(.hidden)
    .refreshable {
      await store.refreshWeather()
    }
  }

  private var wideForecastSkeleton: some View {
    ScrollView {
      HStack(alignment: .top, spacing: 24) {
        VStack(alignment: .leading, spacing: 12) {
          forecastSectionHeader("HOURLY — NEXT 24H")
          LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
            spacing: 16
          ) {
            ForEach(0..<24, id: \.self) { index in
              HourlyRowSkeleton(isNow: index == 0)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        VStack(alignment: .leading, spacing: 8) {
          forecastSectionHeader("10-DAY OUTLOOK")
          ForEach(0..<6, id: \.self) { _ in
            DailyRowSkeleton()
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
    }
    .refreshable {
      await store.refreshWeather()
    }
  }

  private func neutralForecastContent(for weather: SpotterCastWeather) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        forecastSectionHeader("HOURLY — NEXT 24H")
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 16) {
            ForEach(Array(weather.hourly.prefix(24).enumerated()), id: \.element.time) {
              index, hour in
              HourlyRow(
                forecast: hour,
                isNow: index == 0
              )
            }
          }
          .padding(.vertical, 6)
        }

        forecastSectionHeader("10-DAY OUTLOOK")
        ForEach(weather.daily) { day in
          DailyRow(forecast: day)
            .padding(.vertical, 6)
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
    }
    .safeAreaInset(edge: .top) {
      errorBanner
    }
    .refreshable {
      await store.refreshWeather()
    }
  }

  private func compactForecastList(for weather: SpotterCastWeather) -> some View {
    List {
      Section("HOURLY — NEXT 24H") {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 16) {
            ForEach(Array(weather.hourly.prefix(24).enumerated()), id: \.element.time) {
              index, hour in
              HourlyRow(
                forecast: hour,
                isNow: index == 0
              )
            }
          }
          .padding(.vertical, 6)
        }
      }

      Section("10-DAY OUTLOOK") {
        ForEach(weather.daily) { day in
          DailyRow(forecast: day)
        }
      }
    }
    .scrollContentBackground(.hidden)
    .safeAreaInset(edge: .top) {
      errorBanner
    }
    .refreshable {
      await store.refreshWeather()
    }
  }

  private func wideForecastContent(for weather: SpotterCastWeather) -> some View {
    ScrollView {
      VStack(spacing: 16) {
        HStack(alignment: .top, spacing: 24) {
          VStack(alignment: .leading, spacing: 12) {
            forecastSectionHeader("HOURLY — NEXT 24H")
            LazyVGrid(
              columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
              spacing: 16
            ) {
              ForEach(Array(weather.hourly.prefix(24).enumerated()), id: \.element.time) {
                index, hour in
                HourlyRow(
                  forecast: hour,
                  isNow: index == 0
                )
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          VStack(alignment: .leading, spacing: 4) {
            forecastSectionHeader("10-DAY OUTLOOK")
            ForEach(weather.daily) { day in
              DailyRow(forecast: day)
                .padding(.vertical, 6)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
    }
    .safeAreaInset(edge: .top) {
      errorBanner
    }
    .refreshable {
      await store.refreshWeather()
    }
  }

  private func forecastSectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
      .textCase(.uppercase)
      .padding(.bottom, 4)
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
      .padding(16)
      .frame(maxWidth: .infinity, minHeight: 400)
      .background(Color.white.opacity(0.06))
      .overlay(
        RoundedRectangle(cornerRadius: 14)
          .stroke(Color.white.opacity(0.1), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    .refreshable {
      await store.refreshWeather()
    }
  }
}

struct HourlyRow: View {
  let forecast: HourlyForecast
  var isNow: Bool = false

  var body: some View {
    VStack(spacing: 6) {
      // Time label or "Now"
      Text(isNow ? "Now" : formattedTime)
        .font(.caption)
        .fontWeight(isNow ? .semibold : .regular)
        .foregroundStyle(isNow ? .blue : .secondary)

      // Weather symbol
      Image(systemName: forecast.symbolName)
        .font(.title2)
        .symbolRenderingMode(.multicolor)

      // Temperature
      Text("\(Int(forecast.temp))°")
        .font(.headline)
        .fontWeight(.semibold)

      // Precipitation chance labeled with dominant type (rain/snow/sleet/hail etc)
      if forecast.precipChance > 20 {
        let type = shortPrecipType(code: forecast.weatherCode)
        Text("\(forecast.precipChance)% \(type)")
          .font(.caption2)
          .foregroundStyle(.blue)
        // Amount (only when >=0.1"; liquid=rain+showers; snow separate). Uses amount-only text to keep compact next to type %.
        let liq = (forecast.rain ?? 0) + (forecast.showers ?? 0)
        let sn = forecast.snowfall ?? 0
        if let amt = precipAmountText(liquid: liq, snow: sn) {
          Text(amt)
            .font(.caption2)
            .foregroundStyle(.blue)
        }
      }
    }
    .frame(width: 52)
  }

  private var formattedTime: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "ha"
    return formatter.string(from: forecast.time)
  }
}

struct DailyRow: View {
  let forecast: DailyForecast

  var body: some View {
    HStack {
      Text(forecast.date, format: .dateTime.weekday(.abbreviated))
        .font(.body.weight(.medium))
        .frame(width: 52, alignment: .leading)

      Image(systemName: forecast.symbolName)
        .font(.title3)
        .frame(width: 28)

      Spacer()

      if let uv = forecast.uvMax {
        Text("UV \(Int(uv))").font(.caption2).foregroundStyle(.secondary)
      }

      HStack(spacing: 10) {
        Text("\(Int(round(forecast.low)))°").foregroundStyle(.secondary)
        Text("\(Int(round(forecast.high)))°").fontWeight(.semibold)
      }
      .monospacedDigit()

      // Precip % labeled with type (rain/snow/sleet/hail etc) - lightweight addition
      if forecast.precipChance > 20 {
        let type = shortPrecipType(code: forecast.weatherCode)
        // Group type % + amount (if sig) with tight spacing for "on right" polish; padding on first Text preserves separation from temps (minimal change inside existing if).
        HStack(spacing: 4) {
          Text("\(forecast.precipChance)% \(type)")
            .font(.caption2)
            .foregroundStyle(.blue)
            .padding(.leading, 4)
          // Daily row: total precip amount (liquid or snow) on right, small text. >=0.1" only. Amount-only to avoid repeating type from %.
          let liq = (forecast.rainSum ?? 0) + (forecast.showersSum ?? 0)
          let sn = forecast.snowfallSum ?? 0
          if let amt = precipAmountText(liquid: liq, snow: sn) {
            Text(amt)
              .font(.caption2)
              .foregroundStyle(.blue)
          }
        }
      }
    }
    .padding(.vertical, 2)
  }
}

// Lightweight helper for labeling precip % with type (rain/snow/sleet/hail etc percentages)
// Reuses the same WMO logic as the forecast models for consistency.
private func shortPrecipType(code: Int) -> String {
  switch code {
  case 51, 53, 55, 61, 63, 65, 80, 81, 82: return "Rain"
  case 66, 67: return "Sleet"
  case 71, 73, 75, 77, 85, 86: return "Snow"
  case 95, 96, 99: return "T-Storm"
  default: return "Precip"
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
