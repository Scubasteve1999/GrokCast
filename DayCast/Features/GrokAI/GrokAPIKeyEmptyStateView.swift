import SwiftUI

/// Shown when Grok AI is locked — Pro is the way in. Developer BYOK lives in
/// Settings only; this card never advertises adding a key.
struct GrokAPIKeyEmptyStateView: View {
  static let lockTitle = "Sky Check"
  static let lockGlyph = "cloud.sun"
  static let unlockCTATitle = "Unlock with Pro"
  static let bodyCopy =
    "Weather, live radar, and alerts are free. DayCast Pro unlocks AI chat, Today's Take, Explain Radar, and Sky Check."

  @Bindable var subscription: SubscriptionManager

  init(subscription: SubscriptionManager) {
    self.subscription = subscription
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label(Self.lockTitle, systemImage: Self.lockGlyph)
        .font(DesignTokens.Typography.headline())
        .foregroundStyle(DesignTokens.Palette.textPrimary)

      Text(Self.bodyCopy)
        .font(DesignTokens.Typography.callout())
        .foregroundStyle(DesignTokens.Palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)

      if !subscription.isPro {
        Button(Self.unlockCTATitle) {
          Haptic.impact(.light)
          PaywallCoordinator.shared.present(.grokAI)
        }
        .buttonStyle(.borderedProminent)
        .tint(DesignTokens.Palette.accent)
      }
    }
    .padding(DesignTokens.Spacing.space16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.accent.opacity(0.35),
      cornerRadius: DesignTokens.Card.cornerRadiusMedium
    )
  }
}

#Preview {
  GrokAPIKeyEmptyStateView(subscription: SubscriptionManager.shared)
    .padding()
    .preferredColorScheme(.dark)
}
