import SwiftUI

/// Large tactile action tile for the Grok briefing studio grid.
struct GrokActionTile: View {
  let title: String
  let subtitle: String
  let icon: String
  var tint: Color = DesignTokens.Palette.accent
  var disabled: Bool = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
        Image(systemName: icon)
          .font(.title2)
          .foregroundStyle(tint)
        Text(title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .multilineTextAlignment(.leading)
          .lineLimit(2)
        Text(subtitle)
          .font(.caption2)
          .foregroundStyle(DesignTokens.Palette.textTertiary)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
      }
      .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
      .padding(DesignTokens.Spacing.space16)
      .glassCardStyle(strokeTint: tint.opacity(0.35))
      .opacity(disabled ? 0.45 : 1)
    }
    .buttonStyle(.plain)
    .disabled(disabled)
  }
}
