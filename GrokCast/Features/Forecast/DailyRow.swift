import SwiftUI

struct DailyRow: View {
  let forecast: DailyForecast
  @State private var appeared = false

  var body: some View {
    HStack(alignment: .center, spacing: 18) {
      Text(forecast.date, format: .dateTime.weekday(.abbreviated))
        .font(.system(size: 17, weight: .medium))
        .frame(width: 56, alignment: .leading)
        .lineLimit(1)

      Image(systemName: forecast.symbolName)
        .font(.system(size: 28))
        .symbolRenderingMode(.multicolor)
        .frame(width: 32, alignment: .center)

      Spacer()

      HStack(spacing: 16) {
        // High / low
        HStack(spacing: 12) {
          Text("\(Int(round(forecast.high)))°")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(DesignTokens.Palette.textPrimary)
            .lineLimit(1)

          Text("\(Int(round(forecast.low)))°")
            .font(.system(size: 18, weight: .regular, design: .rounded))
            .foregroundStyle(DesignTokens.Palette.textSecondary)
            .lineLimit(1)
        }
        .monospacedDigit()

        // Precip always shown (use textSecondary + accent for % per DS)
        let type = WeatherCondition(fromWMO: forecast.weatherCode).shortPrecipType
        VStack(alignment: .trailing, spacing: 2) {
          Text("\(forecast.precipChance)% \(type)")
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
    .opacity(appeared ? 1 : 0)
    .animation(.easeInOut(duration: 0.25), value: appeared)
    .onAppear { appeared = true }
  }
}
