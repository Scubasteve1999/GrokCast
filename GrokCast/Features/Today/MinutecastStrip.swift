import SwiftUI

struct MinutecastStrip: View {
  let summary: MinutecastSummary

  private var accent: Color {
    switch summary.kind {
    case .clear: DesignTokens.Palette.success
    case .startsSoon, .ongoing: DesignTokens.Palette.accentCool
    case .stoppingSoon: DesignTokens.Palette.accentWarm
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      HStack(spacing: DesignTokens.Spacing.space8) {
        Image(systemName: summary.icon)
          .font(.caption.weight(.semibold))
          .foregroundStyle(accent)
        Text(summary.message)
          .font(.caption.weight(.semibold))
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        Spacer(minLength: 0)
        Text("MINUTECAST")
          .font(.system(size: 9, weight: .heavy))
          .tracking(1.2)
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }

      if !summary.strip.isEmpty {
        HStack(spacing: 3) {
          ForEach(summary.strip) { slot in
            RoundedRectangle(cornerRadius: 2)
              .fill(barColor(for: slot))
              .frame(maxWidth: .infinity)
              .frame(height: barHeight(for: slot))
          }
        }
        .frame(height: 28, alignment: .bottom)
      }
    }
    .padding(.vertical, DesignTokens.Spacing.space12)
    .padding(.horizontal, DesignTokens.Spacing.space12)
    .glassCardStyle(cornerRadius: DesignTokens.Radius.small)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Minutecast. \(summary.message)")
  }

  private func barColor(for slot: MinutelyForecast) -> Color {
    let wet = slot.precipitation >= 0.008 || slot.precipChance >= 45
    if wet {
      return DesignTokens.Palette.accentCool.opacity(0.35 + Double(min(slot.precipChance, 100)) / 200)
    }
    return DesignTokens.Palette.cardStroke.opacity(0.6)
  }

  private func barHeight(for slot: MinutelyForecast) -> CGFloat {
    let wet = slot.precipitation >= 0.008 || slot.precipChance >= 45
    guard wet else { return 6 }
    return 6 + CGFloat(min(slot.precipChance, 100)) / 100 * 22
  }
}

#if DEBUG
#Preview {
  MinutecastStrip(
    summary: MinutecastSummary(
      kind: .startsSoon,
      message: "Precipitation likely in ~30 min",
      icon: "cloud.rain.fill",
      strip: []
    )
  )
  .padding()
  .background(DesignTokens.Palette.bgPrimary)
}
#endif
