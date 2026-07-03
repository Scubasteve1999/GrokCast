import SwiftUI

struct HourlyRow: View {
  let forecast: HourlyForecast
  var isNow: Bool = false
  var openWeatherMapTempF: Int? = nil
  var openWeatherMapPrecipChance: Int? = nil
  @State private var appeared = false

  var body: some View {
    VStack(spacing: 8) {
      Text(isNow ? "Now" : formattedTime)
        .font(.system(size: 13, weight: isNow ? .bold : .semibold))
        .tracking(DesignTokens.Typography.tightTracking)
        .foregroundStyle(
          isNow ? DesignTokens.Palette.textPrimary : DesignTokens.Palette.textSecondary
        )
        .lineLimit(1)

      Image(systemName: forecast.symbolName)
        .font(.system(size: 32))
        .symbolRenderingMode(.multicolor)

      Text("\(Int(round(forecast.temp)))°")
        .font(.system(size: 20, weight: .bold, design: .rounded))
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .monospacedDigit()
        .lineLimit(1)

      // Always show precip + visual bar (DesignSystem: use accent for chance)
      let type = WeatherCondition(fromWMO: forecast.weatherCode).shortPrecipType
      VStack(spacing: 3) {
        Text("\(forecast.precipChance)% \(type)")
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
    .opacity(appeared ? 1 : 0)
    .animation(.easeInOut(duration: 0.25), value: appeared)
    .onAppear { appeared = true }
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
