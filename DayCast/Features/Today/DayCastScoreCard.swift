import SwiftUI

enum DayCastScoreCardLayout {
  /// Ring progress + location subtitle (legacy Today layout).
  case ring
  /// Figma Today screen: uppercase label + icon row with score headline.
  case figma
}

struct DayCastScoreCard: View {
  let score: DayCastScore
  let locationName: String
  var layout: DayCastScoreCardLayout = .ring

  private var ringColor: Color {
    switch score.accentTier {
    case .great: DesignTokens.Palette.success
    case .okay: DesignTokens.Palette.accentWarm
    case .poor: DesignTokens.Palette.danger
    }
  }

  var body: some View {
    switch layout {
    case .ring:
      ringLayout
    case .figma:
      figmaLayout
    }
  }

  private var figmaLayout: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      Text("DayCast score")
        .font(DesignTokens.Typography.caption())
        .tracking(DesignTokens.Typography.cardLabelTracking)
        .foregroundStyle(DesignTokens.Palette.textTertiary)

      HStack(spacing: DesignTokens.Spacing.space12) {
        Image(systemName: score.icon)
          .font(DesignTokens.Typography.title())
          .foregroundStyle(ringColor)
          .symbolRenderingMode(.hierarchical)

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
          Text("\(score.value) · \(score.label)")
            .font(DesignTokens.Typography.headline())
            .foregroundStyle(DesignTokens.Palette.textPrimary)
          Text(score.subtitle)
            .font(DesignTokens.Typography.callout())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 0)
      }
    }
    .padding(DesignTokens.Spacing.space16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardStyle()
    .accessibilityElement(children: .combine)
    .accessibilityLabel("DayCast score \(score.value). \(score.label). \(score.subtitle)")
  }

  private var ringLayout: some View {
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
            .font(DesignTokens.Typography.studioTitle())
            .foregroundStyle(DesignTokens.Palette.textPrimary)
          Text("Score")
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
      }

      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
        HStack(spacing: 6) {
          Image(systemName: score.icon)
            .foregroundStyle(ringColor)
          Text(score.label)
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textPrimary)
        }
        Text(score.subtitle)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
        Text(locationName)
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      }

      Spacer(minLength: 0)
    }
    .padding(DesignTokens.Spacing.space16)
    .cardStyle()
    .accessibilityElement(children: .combine)
    .accessibilityLabel("DayCast score \(score.value). \(score.label). \(score.subtitle)")
  }
}

#if DEBUG
#Preview("Figma layout") {
  DayCastScoreCard(
    score: DayCastScore(value: 84, label: "Go Outside", subtitle: "Great conditions this afternoon", icon: "figure.walk"),
    locationName: "Olive Branch",
    layout: .figma
  )
  .padding()
  .background(DesignTokens.Palette.bgPrimary)
}

#Preview {
  DayCastScoreCard(
    score: DayCastScore(value: 82, label: "Go Outside", subtitle: "Great conditions", icon: "figure.walk"),
    locationName: "Olive Branch"
  )
  .padding()
  .background(DesignTokens.Palette.bgPrimary)
}
#endif
