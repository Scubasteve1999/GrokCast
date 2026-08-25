import SwiftUI

struct MinutecastStrip: View {
  let summary: MinutecastSummary
  /// Optional source cue (e.g. `"HRRR"`) when short-term slots are not Open-Meteo default.
  var sourceLabel: String? = nil
  /// Quiet cue when HRRR and Open-Meteo minutecast disagree.
  var disagreementCaption: String? = nil

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
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(accent)
        Text(summary.message)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        Spacer(minLength: 0)
        if let sourceLabel, !sourceLabel.isEmpty {
          Text(sourceLabel)
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
      }

      if !summary.strip.isEmpty {
        HStack(alignment: .bottom, spacing: 4) {
          ForEach(summary.strip) { slot in
            RoundedRectangle(cornerRadius: 2, style: .continuous)
              .fill(barColor(for: slot))
              .frame(maxWidth: .infinity)
              .frame(height: barHeight(for: slot))
          }
        }
        .frame(height: 32, alignment: .bottom)
      }

      if let disagreementCaption, !disagreementCaption.isEmpty {
        Text(disagreementCaption)
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }
    }
    .padding(.vertical, DesignTokens.Spacing.space12)
    .padding(.horizontal, DesignTokens.Spacing.space16)
    .cardStyle(cornerRadius: DesignTokens.Radius.small)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Self.accessibilityLabel(
      message: summary.message,
      disagreementCaption: disagreementCaption
    ))
  }

  /// VoiceOver for the strip. Product name is “Next 2 Hours”, not Minutecast.
  static func accessibilityLabel(
    message: String,
    disagreementCaption: String? = nil
  ) -> String {
    let caption = disagreementCaption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if caption.isEmpty {
      return "\(PrecipOutlookCopy.title). \(message)"
    }
    return "\(PrecipOutlookCopy.title). \(message). \(caption)"
  }

  private func barColor(for slot: MinutelyForecast) -> Color {
    let wet = slot.precipitation >= 0.008 || slot.precipChance >= 45
    if wet {
      return DesignTokens.Palette.accentCool.opacity(0.45 + Double(min(slot.precipChance, 100)) / 200)
    }
    return DesignTokens.Palette.cardStroke.opacity(0.7)
  }

  private func barHeight(for slot: MinutelyForecast) -> CGFloat {
    let wet = slot.precipitation >= 0.008 || slot.precipChance >= 45
    guard wet else { return 8 }
    return 8 + CGFloat(min(slot.precipChance, 100)) / 100 * 24
  }
}

#if DEBUG
#Preview {
  MinutecastStrip(
    summary: MinutecastSummary(
      kind: .startsSoon,
      message: "Rain likely in ~30 min",
      icon: "cloud.rain.fill",
      strip: []
    )
  )
  .padding()
  .background(DesignTokens.Palette.bgPrimary)
}
#endif
