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
  /// 10-day period bounds for positioning the temp range segment (presentation only).
  var periodLow: Double? = nil
  var periodHigh: Double? = nil
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

  private var isToday: Bool {
    Calendar.current.isDateInToday(forecast.date)
  }

  private var dayLabel: String {
    if isToday { return "Today" }
    return forecast.date.formatted(.dateTime.weekday(.abbreviated))
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
      Text(dayLabel)
        .font(DesignTokens.Figma.Typography.rowTitle)
        .fontWeight(isToday ? .bold : .semibold)
        .foregroundStyle(
          isToday ? DesignTokens.Palette.textPrimary : DesignTokens.Palette.textSecondary
        )
        .lineLimit(1)
        .frame(width: 52, alignment: .leading)

      Image(systemName: rowSymbol)
        .font(.system(size: 22))
        .symbolRenderingMode(.multicolor)
        .frame(width: 28, alignment: .center)

      DailyTempRangeBar(
        low: forecast.low,
        high: forecast.high,
        periodLow: periodLow,
        periodHigh: periodHigh
      )
      .frame(maxWidth: .infinity)

      VStack(alignment: .trailing, spacing: DesignTokens.Spacing.space2) {
        if forecast.precipChance > 0 {
          Text("\(forecast.precipChance)%")
            .font(.caption.weight(.semibold))
            .foregroundStyle(DesignTokens.Palette.accentCool)
            .monospacedDigit()
            .lineLimit(1)
          Text(precipLabel)
            .font(.caption2)
            .foregroundStyle(DesignTokens.Palette.textTertiary)
            .lineLimit(1)
        } else {
          Text("—")
            .font(.caption)
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
        let liq = (forecast.rainSum ?? 0) + (forecast.showersSum ?? 0)
        let sn = forecast.snowfallSum ?? 0
        if let amt = precipAmountText(liquid: liq, snow: sn) {
          Text(amt)
            .font(.caption2)
            .foregroundStyle(DesignTokens.Palette.textSecondary)
            .lineLimit(1)
        }
      }
      .frame(width: 56, alignment: .trailing)
    }
    .padding(.leading, DesignTokens.Spacing.space16)
    .padding(.trailing, DesignTokens.Spacing.space16)
    .padding(.vertical, DesignTokens.Spacing.space16)
    .background {
      RoundedRectangle(cornerRadius: DesignTokens.Figma.Metrics.chipRadius)
        .fill(
          isToday
            ? DesignTokens.Palette.cardElevated.opacity(0.95)
            : DesignTokens.Palette.cardBackground.opacity(0.55)
        )
        .background {
          if !isToday {
            RoundedRectangle(cornerRadius: DesignTokens.Figma.Metrics.chipRadius)
              .fill(.ultraThinMaterial)
          }
        }
    }
    .overlay(alignment: .leading) {
      if isToday {
        UnevenRoundedRectangle(
          topLeadingRadius: DesignTokens.Figma.Metrics.chipRadius,
          bottomLeadingRadius: DesignTokens.Figma.Metrics.chipRadius,
          bottomTrailingRadius: 0,
          topTrailingRadius: 0
        )
        .fill(DesignTokens.Palette.accent)
        .frame(width: 3)
        .padding(.vertical, DesignTokens.Spacing.space8)
      }
    }
    .overlay {
      RoundedRectangle(cornerRadius: DesignTokens.Figma.Metrics.chipRadius)
        .stroke(
          isToday
            ? DesignTokens.Palette.accent.opacity(0.4)
            : DesignTokens.Palette.cardStroke,
          lineWidth: DesignTokens.Card.strokeWidth
        )
    }
    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Figma.Metrics.chipRadius))
  }

  private var standardLayout: some View {
    HStack(alignment: .center, spacing: DesignTokens.Spacing.space16) {
      Text(dayLabel)
        .font(.system(size: 17, weight: isToday ? .bold : .medium))
        .foregroundStyle(
          isToday ? DesignTokens.Palette.textPrimary : DesignTokens.Palette.textSecondary
        )
        .frame(width: 56, alignment: .leading)
        .lineLimit(1)

      Image(systemName: rowSymbol)
        .font(.system(size: 28))
        .symbolRenderingMode(.multicolor)
        .frame(width: 32, alignment: .center)

      DailyTempRangeBar(
        low: forecast.low,
        high: forecast.high,
        periodLow: periodLow,
        periodHigh: periodHigh
      )
      .frame(maxWidth: .infinity)

      VStack(alignment: .trailing, spacing: DesignTokens.Spacing.space2) {
        if forecast.precipChance > 0 {
          Text("\(forecast.precipChance)% \(precipLabel)")
            .font(.caption2.weight(.medium))
            .foregroundStyle(DesignTokens.Palette.accentCool)
            .lineLimit(1)
        }
        let liq = (forecast.rainSum ?? 0) + (forecast.showersSum ?? 0)
        let sn = forecast.snowfallSum ?? 0
        if let amt = precipAmountText(liquid: liq, snow: sn) {
          Text(amt)
            .font(.caption2)
            .foregroundStyle(DesignTokens.Palette.textSecondary)
            .lineLimit(1)
        }
      }
      .frame(minWidth: 52, alignment: .trailing)
    }
    .padding(.vertical, DesignTokens.Spacing.space20)
    .padding(.horizontal, DesignTokens.Spacing.space20)
    .cardStyle(
      background: isToday
        ? DesignTokens.Palette.cardElevated : DesignTokens.Palette.cardBackground,
      stroke: isToday
        ? DesignTokens.Palette.accent.opacity(0.45) : DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadius
    )
    .overlay(alignment: .leading) {
      if isToday {
        UnevenRoundedRectangle(
          topLeadingRadius: DesignTokens.Card.cornerRadius,
          bottomLeadingRadius: DesignTokens.Card.cornerRadius,
          bottomTrailingRadius: 0,
          topTrailingRadius: 0
        )
        .fill(DesignTokens.Palette.accent)
        .frame(width: 4)
        .padding(.vertical, DesignTokens.Spacing.space12)
      }
    }
    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
  }
}
