import SwiftUI

enum HourlyRowLayout {
  /// Full row with precip bar and OWM hybrid line.
  case standard
  /// Figma Forecast screen: compact elevated chip.
  case figma
}

struct HourlyRow: View {
  let forecast: HourlyForecast
  var isNow: Bool = false
  var layout: HourlyRowLayout = .standard
  var openWeatherMapTempF: Int? = nil
  var openWeatherMapPrecipChance: Int? = nil
  /// Location timezone for hour labels (defaults to device).
  var timeZone: TimeZone = .current
  private var condition: WeatherCondition {
    WeatherCondition(fromWMO: forecast.weatherCode)
  }

  private var rowSymbol: String {
    condition.rowSymbolName(precipChance: forecast.precipChance, isDay: forecast.isDay ?? true)
  }

  private var precipLabel: String {
    condition.rowPrecipTypeLabel(precipChance: forecast.precipChance)
  }

  var body: some View {
    Group {
      switch layout {
      case .standard:
        standardLayout
      case .figma:
        figmaLayout
      }
    }
  }

  private var figmaLayout: some View {
    VStack(spacing: DesignTokens.Spacing.space8) {
      Text(isNow ? "Now" : formattedTime)
        .font(DesignTokens.Typography.caption())
        .fontWeight(isNow ? .bold : .semibold)
        .foregroundStyle(
          isNow ? DesignTokens.Palette.accent : DesignTokens.Palette.textTertiary
        )
        .lineLimit(1)

      Image(systemName: rowSymbol)
        .font(DesignTokens.Typography.symbol(24))
        .symbolRenderingMode(.multicolor)
        .accessibilityLabel(condition.displayText)

      Text("\(Int(round(forecast.temp)))°")
        .font(DesignTokens.Typography.metric())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .monospacedDigit()
        .lineLimit(1)

      VStack(spacing: 2) {
        if forecast.precipChance > 0 {
          HStack(spacing: DesignTokens.Spacing.space4) {
            Circle()
              .fill(DesignTokens.Palette.accentCool)
              .frame(width: 4, height: 4)
            Text("\(forecast.precipChance)%")
              .font(DesignTokens.Typography.micro())
              .foregroundStyle(DesignTokens.Palette.accentCool)
              .monospacedDigit()
          }
          .accessibilityLabel("\(forecast.precipChance) percent chance of \(precipLabel)")
        } else {
          Color.clear
            .frame(height: 14)
        }

        let liq = (forecast.rain ?? 0) + (forecast.showers ?? 0)
        let sn = forecast.snowfall ?? 0
        if let amt = precipAmountText(liquid: liq, snow: sn) {
          Text(amt)
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
      }
    }
    .frame(width: DesignTokens.Layout.hourlyChipWidth)
    .padding(.horizontal, DesignTokens.Spacing.space12)
    .padding(.vertical, DesignTokens.Spacing.space12)
    .cardStyle(
      background: isNow
        ? DesignTokens.Palette.cardElevated
        : DesignTokens.Palette.cardBackground,
      stroke: isNow
        ? DesignTokens.Palette.accent.opacity(0.55)
        : DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Layout.chipRadius,
      elevated: isNow
    )
  }

  private var standardLayout: some View {
    VStack(spacing: DesignTokens.Spacing.space8) {
      Text(isNow ? "Now" : formattedTime)
        .font(DesignTokens.Typography.caption())
        .tracking(DesignTokens.Typography.tightTracking)
        .foregroundStyle(
          isNow ? DesignTokens.Palette.accent : DesignTokens.Palette.textSecondary
        )
        .lineLimit(1)

      Image(systemName: rowSymbol)
        .font(DesignTokens.Typography.widgetTemp(32))
        .symbolRenderingMode(.multicolor)
        .accessibilityLabel(condition.displayText)

      Text("\(Int(round(forecast.temp)))°")
        .font(DesignTokens.Typography.metric())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .monospacedDigit()
        .lineLimit(1)

      if forecast.precipChance > 0 {
        HStack(spacing: DesignTokens.Spacing.space4) {
          Circle()
            .fill(DesignTokens.Palette.accentCool)
            .frame(width: 4, height: 4)
          Text("\(forecast.precipChance)% \(precipLabel)")
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(DesignTokens.Palette.accentCool)
            .lineLimit(1)
        }
      }

      VStack(spacing: DesignTokens.Spacing.space4) {
        let liq = (forecast.rain ?? 0) + (forecast.showers ?? 0)
        let sn = forecast.snowfall ?? 0
        if let amt = precipAmountText(liquid: liq, snow: sn) {
          Text(amt)
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
            .lineLimit(1)
        }

        if let owmTemp = openWeatherMapTempF {
          let precipSuffix =
            openWeatherMapPrecipChance.map { " · \($0)%" } ?? ""
          Text("OWM \(owmTemp)°\(precipSuffix)")
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
            .lineLimit(1)
        }

        if forecast.precipChance > 0 {
          ZStack(alignment: .leading) {
            Capsule()
              .fill(
                LinearGradient(
                  colors: [
                    DesignTokens.Palette.accentCool.opacity(0.25),
                    DesignTokens.Palette.accent.opacity(0.25),
                  ],
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
              .frame(width: 46, height: 5)
            Capsule()
              .fill(
                LinearGradient(
                  colors: [DesignTokens.Palette.accentCool, DesignTokens.Palette.accent],
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
              .frame(width: 46 * CGFloat(forecast.precipChance) / 100.0, height: 5)
          }
        }
      }
    }
    .frame(width: 88)
    .padding(.vertical, DesignTokens.Spacing.space20)
    .cardStyle(
      background: isNow
        ? DesignTokens.Palette.cardElevated : DesignTokens.Palette.cardBackground,
      stroke: isNow
        ? DesignTokens.Palette.accent.opacity(0.5) : DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadius,
      strokeWidth: isNow ? 1.5 : DesignTokens.Card.strokeWidth
    )
    .shadow(
      color: isNow ? DesignTokens.Palette.accent.opacity(0.2) : .black.opacity(0.18),
      radius: isNow ? 12 : 10,
      x: 0,
      y: 6
    )
  }

  private var formattedTime: String {
    LocationTimezone.formatter(dateFormat: "ha", timeZone: timeZone)
      .string(from: forecast.time)
  }
}
