import SwiftUI

struct GrokCastScoreCard: View {
  let score: GrokCastScore
  let locationName: String

  private var ringColor: Color {
    switch score.accentTier {
    case .great: DesignTokens.Palette.success
    case .okay: DesignTokens.Palette.accentWarm
    case .poor: DesignTokens.Palette.danger
    }
  }

  var body: some View {
    HStack(spacing: DesignTokens.Spacing.space16) {
      ZStack {
        Circle()
          .stroke(DesignTokens.Palette.cardStroke, lineWidth: 6)
          .frame(width: 72, height: 72)
        Circle()
          .trim(from: 0, to: CGFloat(score.value) / 100)
          .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
          .rotationEffect(.degrees(-90))
          .frame(width: 72, height: 72)
        VStack(spacing: 0) {
          Text("\(score.value)")
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(DesignTokens.Palette.textPrimary)
          Text("SCORE")
            .font(.system(size: 8, weight: .heavy))
            .tracking(1)
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
      }

      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
        HStack(spacing: 6) {
          Image(systemName: score.icon)
            .foregroundStyle(ringColor)
          Text(score.label.uppercased())
            .font(.caption.weight(.heavy))
            .tracking(DesignTokens.Typography.headerTracking)
            .foregroundStyle(DesignTokens.Palette.textPrimary)
        }
        Text(score.subtitle)
          .font(.caption)
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
        Text(locationName.uppercased())
          .font(.caption2.weight(.semibold))
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }

      Spacer(minLength: 0)
    }
    .padding(DesignTokens.Spacing.space16)
    .glassCardStyle()
    .accessibilityElement(children: .combine)
    .accessibilityLabel("GrokCast score \(score.value). \(score.label). \(score.subtitle)")
  }
}

#if DEBUG
#Preview {
  GrokCastScoreCard(
    score: GrokCastScore(value: 82, label: "Go Outside", subtitle: "Great conditions", icon: "figure.walk"),
    locationName: "Olive Branch"
  )
  .padding()
  .background(DesignTokens.Palette.bgPrimary)
}
#endif
