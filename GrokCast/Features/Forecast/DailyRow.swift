import SwiftUI

enum DailyRowLayout {
  /// Full row with temp range bar and precip details.
  case standard
  /// Figma Forecast screen: day, icon, high/low temps.
  case figma
}

struct DailyRow: View {
  let forecast: DailyForecast
  var layout: DailyRowLayout = .standard
  @State private var appeared = false

  private var condition: WeatherCondition {
    WeatherCondition(fromWMO: forecast.weatherCode)
  }

  private var rowSymbol: String {
    condition.rowSymbolName(precipChance: forecast.precipChance)
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
    HStack(spacing: DesignTokens.Spacing.space12) {
      Text(forecast.date, format: .dateTime.weekday(.abbreviated))
        .font(DesignTokens.Figma.Typography.rowTitle)
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .lineLimit(1)

      Image(systemName: rowSymbol)
        .font(.system(size: 22))
        .symbolRenderingMode(.multicolor)

      Text("\(Int(round(forecast.high)))°")
        .font(DesignTokens.Figma.Typography.chipTemp)
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .monospacedDigit()

      Text("\(Int(round(forecast.low)))°")
        .font(DesignTokens.Figma.Typography.body)
        .foregroundStyle(DesignTokens.Palette.textSecondary)
        .monospacedDigit()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, DesignTokens.Figma.Metrics.cardPadding)
    .padding(.vertical, DesignTokens.Spacing.space12)
    .cardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Figma.Metrics.chipRadius
    )
  }

  private var standardLayout: some View {
    HStack(alignment: .center, spacing: 18) {
      Text(forecast.date, format: .dateTime.weekday(.abbreviated))
        .font(.system(size: 17, weight: .medium))
        .frame(width: 56, alignment: .leading)
        .lineLimit(1)

      Image(systemName: rowSymbol)
        .font(.system(size: 28))
        .symbolRenderingMode(.multicolor)
        .frame(width: 32, alignment: .center)

      Spacer()

      DailyTempRangeBar(low: forecast.low, high: forecast.high)

      HStack(spacing: 16) {
        VStack(alignment: .trailing, spacing: 2) {
          Text("\(forecast.precipChance)% \(precipLabel)")
            .font(.caption2.weight(.medium))
            .foregroundStyle(DesignTokens.Palette.accent)
            .lineLimit(1)
          let liq = (forecast.rainSum ?? 0) + (forecast.showersSum ?? 0)
          let sn = forecast.snowfallSum ?? 0
          if let amt = precipAmountText(liquid: liq, snow: sn) {
            Text(amt)
              .font(.caption2)
              .foregroundStyle(DesignTokens.Palette.textSecondary)
              .lineLimit(1)
          }
        }
      }
    }
    .padding(.vertical, DesignTokens.Spacing.space20)
    .padding(.horizontal, DesignTokens.Spacing.space20)
    .cardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadius
    )
    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
  }
}
