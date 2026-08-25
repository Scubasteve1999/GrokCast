import SwiftUI

/// Label / value / support column. Not a card — sits inside an existing plate.
struct MetricTile: View {
  let label: String
  let value: String
  let support: String
  var valueColor: Color = DesignTokens.Palette.textPrimary
  var action: () -> Void
  var accessibilityLabel: String

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
        Text(label)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
        Text(value)
          .font(DesignTokens.Typography.metric())
          .foregroundStyle(valueColor)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .monospacedDigit()
        Text(support)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
  }
}
