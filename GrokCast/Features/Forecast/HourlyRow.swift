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
  @State private var appeared = false

  private var condition: WeatherCondition {
    WeatherCondition(fromWMO: forecast.weatherCode)
  }

  private var rowSymbol: String {
    condition.rowSymbolName(precipChance: forecast.precipChance, isDay: true)
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
    .opacity(appeared ? 1 : 0)
    .animation(.easeInOut(duration: 0.25), value: appeared)
    .onAppear { appeared = true }
  }

  private var figmaLayout: some View {
    VStack(spacing: 6) {
      Text(isNow ? "Now" : formattedTime)
        .font(DesignTokens.Figma.Typography.chipTime)
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .lineLimit(1)

      Image(systemName: rowSymbol)
        .font(.system(size: 22))
        .symbolRenderingMode(.multicolor)

      Text("\(Int(round(forecast.temp)))°")
        .font(DesignTokens.Figma.Typography.chipTemp)
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .monospacedDigit()
        .lineLimit(1)

      Text(forecast.precipChance > 0 ? "\(forecast.precipChance)% \(precipLabel)" : " ")
        .font(.caption2.weight(.medium))
        .foregroundStyle(DesignTokens.Palette.accent)
        .lineLimit(1)
    }
    .frame(width: DesignTokens.Figma.Metrics.hourlyChipWidth)
    .padding(.horizontal, 10)
    .padding(.vertical, DesignTokens.Spacing.space12)
    .glassCardStyle(cornerRadius: DesignTokens.Figma.Metrics.chipRadius)
  }

  private var standardLayout: some View {
    VStack(spacing: 8) {
      Text(isNow ? "Now" : formattedTime)
        .font(.system(size: 13, weight: isNow ? .bold : .semibold))
        .tracking(DesignTokens.Typography.tightTracking)
        .foregroundStyle(
          isNow ? DesignTokens.Palette.textPrimary : DesignTokens.Palette.textSecondary
        )
        .lineLimit(1)

      Image(systemName: rowSymbol)
        .font(.system(size: 32))
        .symbolRenderingMode(.multicolor)

      Text("\(Int(round(forecast.temp)))°")
        .font(.system(size: 20, weight: .bold, design: .rounded))
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .monospacedDigit()
        .lineLimit(1)

      // Always show precip + visual bar (DesignSystem: use accent for chance)
      VStack(spacing: 3) {
        Text("\(forecast.precipChance)% \(precipLabel)")
          .font(.caption2.weight(.medium))
          .foregroundStyle(DesignTokens.Palette.accent)
          .lineLimit(1)
        let liq = (forecast.rain ?? 0) + (forecast.showers ?? 0)
        let sn = forecast.snowfall ?? 0
        if let amt = precipAmountText(liquid: liq, snow: sn) {
          Text(amt)
            .font(.caption2)
            .foregroundStyle(DesignTokens.Palette.textSecondary)
            .lineLimit(1)
        }

        if let owmTemp = openWeatherMapTempF {
          let precipSuffix =
            openWeatherMapPrecipChance.map { " · \($0)%" } ?? ""
          Text("OWM \(owmTemp)°\(precipSuffix)")
            .font(.caption2)
            .foregroundStyle(DesignTokens.Palette.textTertiary)
            .lineLimit(1)
        }

        // Gradient chance bar
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
    .frame(width: 88)
    .padding(.vertical, DesignTokens.Spacing.space20)
    .cardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadius
    )
    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
  }

  private var formattedTime: String {
    Self.timeFormatter.string(from: forecast.time)
  }

  private static let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "ha"
    return f
  }()
}
