import SwiftUI

struct OpenWeatherMapForecastChip: View {
  let entry: OpenWeatherMapForecastEntry
  var timeZone: TimeZone = .current

  var body: some View {
    VStack(spacing: 6) {
      Text(formattedTime)
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .lineLimit(1)

      Image(systemName: entry.symbolName)
        .font(DesignTokens.Typography.metric())
        .symbolRenderingMode(.multicolor)
        .accessibilityLabel(entry.condition)

      Text("\(Int(round(entry.temperatureF)))°")
        .font(DesignTokens.Typography.metric())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .monospacedDigit()
        .lineLimit(1)

      Text(entry.precipitationChance > 0 ? "\(entry.precipitationChance)%" : " ")
        .font(DesignTokens.Typography.micro())
        .foregroundStyle(DesignTokens.Palette.accent)
        .lineLimit(1)
    }
    .frame(width: DesignTokens.Layout.hourlyChipWidth)
    .padding(.horizontal, 10)
    .padding(.vertical, DesignTokens.Spacing.space12)
    .glassCardStyle(cornerRadius: DesignTokens.Layout.chipRadius)
  }

  private var formattedTime: String {
    LocationTimezone.formatter(dateFormat: "ha", timeZone: timeZone)
      .string(from: entry.time)
  }
}
