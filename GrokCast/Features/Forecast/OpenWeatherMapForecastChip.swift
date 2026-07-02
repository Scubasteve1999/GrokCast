import SwiftUI

struct OpenWeatherMapForecastChip: View {
  let entry: OpenWeatherMapForecastEntry

  var body: some View {
    VStack(spacing: DesignTokens.Spacing.space8) {
      Text(formattedTime)
        .font(.system(size: 13, weight: .semibold))
        .tracking(DesignTokens.Typography.tightTracking)
        .foregroundStyle(DesignTokens.Palette.textSecondary)
        .lineLimit(1)

      Image(systemName: "cloud.sun.fill")
        .font(.system(size: 28))
        .foregroundStyle(DesignTokens.Palette.accentCool)

      Text("\(Int(round(entry.temperatureF)))°")
        .font(.system(size: 20, weight: .bold, design: .rounded))
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .monospacedDigit()

      Text("\(entry.precipitationChance)%")
        .font(.caption2.weight(.medium))
        .foregroundStyle(DesignTokens.Palette.accent)
        .lineLimit(1)

      Text(entry.condition)
        .font(.caption2)
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .lineLimit(2)
        .multilineTextAlignment(.center)
    }
    .frame(width: 88)
    .padding(.vertical, DesignTokens.Spacing.space16)
    .cardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadius
    )
    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
  }

  private var formattedTime: String {
    Self.timeFormatter.string(from: entry.time)
  }

  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "ha"
    return formatter
  }()
}