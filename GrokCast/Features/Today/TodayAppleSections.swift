import SwiftUI

// Apple-Weather-style sections for the bright Today tab: alert card, summary + hourly
// strip, 10-day forecast list with proportional range bars, and detail chips.
// All render on the translucent `todayGlassCard` frosted surface (see TodayBrightTheme).

// MARK: - Alert card

/// Heat-Advisory-style alert card: severity glyph + event title + description + source.
struct TodayAlertCard: View {
  let alert: NWSAlert

  var body: some View {
    HStack(alignment: .top, spacing: DesignTokens.Spacing.space12) {
      Image(systemName: NWSAlertStyle.iconName(for: alert))
        .font(.title3.weight(.semibold))
        .foregroundStyle(NWSAlertStyle.tint(for: alert))
        .padding(.top, 2)

      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
        Text(alert.event)
          .font(.headline.weight(.semibold))
          .foregroundStyle(TodayBright.textPrimary)

        if let headline = alert.headline, !headline.isEmpty {
          Text(headline)
            .font(.subheadline)
            .foregroundStyle(TodayBright.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Text("National Weather Service")
          .font(.caption)
          .foregroundStyle(TodayBright.textTertiary)
          .padding(.top, DesignTokens.Spacing.space2)
      }

      Spacer(minLength: 0)
    }
    .padding(DesignTokens.Spacing.space16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .todayGlassCard()
  }
}

// MARK: - Summary + hourly

/// Plain-language conditions summary followed by a horizontal hourly strip, in one card.
struct TodaySummaryHourlyCard: View {
  @Environment(WeatherStore.self) private var store
  let weather: GrokCastWeather

  private var upcomingHours: [HourlyForecast] {
    let hours = Array(weather.hourly.prefix(48))
    let now = Date()
    let nowIndex =
      hours.firstIndex(where: {
        Calendar.current.isDate($0.time, equalTo: now, toGranularity: .hour)
      }) ?? 0
    return Array(hours[nowIndex...].prefix(12))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      Text(summaryText)
        .font(.subheadline)
        .foregroundStyle(TodayBright.textSecondary)
        .fixedSize(horizontal: false, vertical: true)

      if !upcomingHours.isEmpty {
        Rectangle()
          .fill(TodayBright.divider)
          .frame(height: 1)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: DesignTokens.Spacing.space20) {
            ForEach(Array(upcomingHours.enumerated()), id: \.element.time) { index, hour in
              TodayHourColumn(forecast: hour, isNow: index == 0)
            }
          }
          .padding(.vertical, DesignTokens.Spacing.space4)
        }
      }
    }
    .padding(DesignTokens.Spacing.space16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .todayGlassCard()
  }

  private var summaryText: String {
    let condition = weather.conditionText
    let high = Int(round(weather.high))
    let feels = Int(round(weather.feelsLike))
    let precip = weather.precipitationChance

    if precip >= 40 {
      return
        "\(condition) with a \(precip)% chance of precipitation. Highs near \(high)°, feels like \(feels)° right now."
    }
    return "\(condition) conditions continuing. Highs near \(high)°, feels like \(feels)° right now."
  }
}

/// A single hour: time, multicolor glyph, temperature — floats transparently in its card.
private struct TodayHourColumn: View {
  @Environment(WeatherStore.self) private var store
  let forecast: HourlyForecast
  var isNow: Bool = false

  var body: some View {
    VStack(spacing: DesignTokens.Spacing.space8) {
      Text(isNow ? "Now" : Self.timeFormatter.string(from: forecast.time))
        .font(.footnote.weight(.semibold))
        .foregroundStyle(isNow ? TodayBright.textPrimary : TodayBright.textSecondary)

      Image(systemName: forecast.symbolName)
        .font(.system(size: 22))
        .symbolRenderingMode(.multicolor)
        .frame(height: 26)

      Text(store.formatTemperatureShort(forecast.temp))
        .font(.callout.weight(.semibold))
        .foregroundStyle(TodayBright.textPrimary)
        .monospacedDigit()
    }
    .frame(minWidth: 34)
  }

  private static let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "ha"
    return f
  }()
}

// MARK: - 10-day forecast

/// Apple-style daily list: day · glyph · low · proportional range bar · high.
struct TodayTenDayCard: View {
  let daily: [DailyForecast]
  let currentTemp: Double

  private var rows: [DailyForecast] { Array(daily.prefix(10)) }
  private var overallLow: Double { rows.map(\.low).min() ?? 0 }
  private var overallHigh: Double { rows.map(\.high).max() ?? 1 }

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      TodaySectionHeader(title: "10-DAY FORECAST", systemImage: "calendar")

      VStack(spacing: 0) {
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, day in
          TodayTenDayRow(
            forecast: day,
            isToday: index == 0,
            overallLow: overallLow,
            overallHigh: overallHigh,
            currentTemp: index == 0 ? currentTemp : nil
          )
          if index < rows.count - 1 {
            Rectangle()
              .fill(TodayBright.divider)
              .frame(height: 1)
          }
        }
      }
    }
    .padding(DesignTokens.Spacing.space16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .todayGlassCard()
  }
}

private struct TodayTenDayRow: View {
  @Environment(WeatherStore.self) private var store
  let forecast: DailyForecast
  let isToday: Bool
  let overallLow: Double
  let overallHigh: Double
  var currentTemp: Double?

  private var condition: WeatherCondition { WeatherCondition(fromWMO: forecast.weatherCode) }
  private var rowSymbol: String {
    condition.rowSymbolName(precipChance: forecast.precipChance, isDay: true)
  }

  var body: some View {
    HStack(spacing: DesignTokens.Spacing.space12) {
      Text(isToday ? "Today" : forecast.date.formatted(.dateTime.weekday(.abbreviated)))
        .font(.body.weight(isToday ? .semibold : .regular))
        .foregroundStyle(TodayBright.textPrimary)
        .frame(width: 52, alignment: .leading)

      Image(systemName: rowSymbol)
        .font(.system(size: 20))
        .symbolRenderingMode(.multicolor)
        .frame(width: 28)

      Text(store.formatTemperatureShort(forecast.low))
        .font(.body)
        .foregroundStyle(TodayBright.textTertiary)
        .monospacedDigit()
        .frame(width: 34, alignment: .trailing)

      TodayRangeBar(
        low: forecast.low,
        high: forecast.high,
        overallLow: overallLow,
        overallHigh: overallHigh,
        currentTemp: currentTemp
      )

      Text(store.formatTemperatureShort(forecast.high))
        .font(.body.weight(.semibold))
        .foregroundStyle(TodayBright.textPrimary)
        .monospacedDigit()
        .frame(width: 34, alignment: .trailing)
    }
    .padding(.vertical, DesignTokens.Spacing.space12)
  }
}

/// Proportional low–high span positioned against the full 10-day range, with an optional
/// "now" dot on today's row (Apple Weather behavior).
private struct TodayRangeBar: View {
  let low: Double
  let high: Double
  let overallLow: Double
  let overallHigh: Double
  var currentTemp: Double?

  var body: some View {
    GeometryReader { geo in
      let span = max(overallHigh - overallLow, 1)
      let w = geo.size.width
      let x1 = CGFloat((low - overallLow) / span) * w
      let x2 = CGFloat((high - overallLow) / span) * w
      let segWidth = max(x2 - x1, 8)

      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.white.opacity(0.16))
          .frame(height: 4)

        Capsule()
          .fill(
            LinearGradient(
              colors: [DesignTokens.Palette.accentCool, DesignTokens.Palette.accentWarm],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(width: segWidth, height: 4)
          .offset(x: x1)

        if let t = currentTemp {
          let cx = CGFloat((t - overallLow) / span) * w
          Circle()
            .fill(.white)
            .frame(width: 7, height: 7)
            .overlay(Circle().stroke(Color.black.opacity(0.25), lineWidth: 0.5))
            .offset(x: min(max(cx - 3.5, x1), x1 + segWidth - 3.5))
        }
      }
      .frame(maxHeight: .infinity, alignment: .center)
    }
    .frame(height: 12)
  }
}

// MARK: - Detail chip

/// Small frosted metric tile (humidity, wind, UV, precip, AQI…) for the Today grid.
struct TodayDetailChip: View {
  let label: String
  let value: String
  let icon: String
  var tint: Color = DesignTokens.Palette.accent

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      Label {
        Text(label)
          .font(.caption.weight(.semibold))
          .tracking(0.5)
      } icon: {
        Image(systemName: icon)
          .font(.caption)
      }
      .foregroundStyle(tint)

      Text(value)
        .font(.title2.weight(.semibold))
        .foregroundStyle(TodayBright.textPrimary)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(DesignTokens.Spacing.space16)
    .todayGlassCard(cornerRadius: DesignTokens.Radius.medium)
  }
}
