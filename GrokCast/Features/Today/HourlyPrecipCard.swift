import SwiftUI

struct HourlyPrecipCard: View {
  let hourly: [HourlyForecast]

  private var next12Hours: [HourlyForecast] {
    Array(hourly.prefix(12))
  }

  private var maxChance: Int {
    next12Hours.map(\.precipChance).max() ?? 0
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      HStack {
        Text("PRECIPITATION")
          .font(.caption.weight(.bold))
          .tracking(DesignTokens.Typography.cardLabelTracking)
          .foregroundStyle(DesignTokens.Palette.textTertiary)
        Spacer()
        if maxChance > 0 {
          Text("Next 12h")
            .font(.caption2)
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
      }

      if maxChance == 0 {
        HStack(spacing: DesignTokens.Spacing.space8) {
          Image(systemName: "sun.max.fill")
            .font(.title3)
            .foregroundStyle(DesignTokens.Palette.accentWarm)
          Text("No precipitation expected")
            .font(.subheadline)
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
        .padding(.vertical, DesignTokens.Spacing.space4)
      } else {
        precipChart
      }
    }
    .padding(DesignTokens.Spacing.space16)
    .glassCardStyle()
  }

  private var precipChart: some View {
    VStack(spacing: DesignTokens.Spacing.space4) {
      GeometryReader { geo in
        let barWidth = (geo.size.width - CGFloat(next12Hours.count - 1) * 3) / CGFloat(next12Hours.count)
        HStack(alignment: .bottom, spacing: 3) {
          ForEach(Array(next12Hours.enumerated()), id: \.offset) { _, hour in
            let fraction = Double(hour.precipChance) / 100.0
            VStack(spacing: 2) {
              if hour.precipChance > 30 {
                Text("\(hour.precipChance)")
                  .font(.system(size: 8, weight: .bold))
                  .foregroundStyle(.cyan)
              }
              RoundedRectangle(cornerRadius: 2)
                .fill(barColor(for: hour.precipChance))
                .frame(width: barWidth, height: max(2, geo.size.height * 0.8 * fraction))
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
          }
        }
      }
      .frame(height: 50)

      HStack {
        Text(formatHour(next12Hours.first?.time))
          .font(.system(size: 9))
          .foregroundStyle(DesignTokens.Palette.textTertiary)
        Spacer()
        Text(formatHour(next12Hours.last?.time))
          .font(.system(size: 9))
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }
    }
  }

  private func barColor(for chance: Int) -> Color {
    if chance >= 70 { return .cyan }
    if chance >= 40 { return .cyan.opacity(0.7) }
    if chance > 0 { return .cyan.opacity(0.4) }
    return DesignTokens.Palette.textTertiary.opacity(0.2)
  }

  private func formatHour(_ date: Date?) -> String {
    guard let date else { return "" }
    let f = DateFormatter()
    f.dateFormat = "ha"
    return f.string(from: date).lowercased()
  }
}
