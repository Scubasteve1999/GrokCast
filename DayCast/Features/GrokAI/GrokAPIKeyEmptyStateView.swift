import SwiftUI

/// Shown when Grok AI is locked — Pro is the way in, with BYOK as a secondary path.
struct GrokAPIKeyEmptyStateView: View {
  @Bindable var store: WeatherStore
  @Bindable var subscription: SubscriptionManager

  init(store: WeatherStore, subscription: SubscriptionManager) {
    self.store = store
    self.subscription = subscription
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("AI features", systemImage: "sparkles")
        .font(DesignTokens.Typography.headline())
        .foregroundStyle(DesignTokens.Palette.textPrimary)

      Text(
        "Weather, live radar, and alerts are free. DayCast Pro unlocks AI chat, Today's Take, Explain Radar, and Storm Spotter — or bring your own xAI key in Settings."
      )
      .font(DesignTokens.Typography.callout())
      .foregroundStyle(DesignTokens.Palette.textSecondary)
      .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 12) {
        if !subscription.isPro {
          Button("Unlock with Pro") {
            Haptic.impact(.light)
            PaywallCoordinator.shared.present(.grokAI)
          }
          .buttonStyle(.borderedProminent)
          .tint(DesignTokens.Palette.accent)
        }

        let useOwnKey = Button("Use my own key") {
          Haptic.impact(.light)
          store.selectedTab = .settings
        }

        // Pro subscribers seeing this card have no Pro button to press, so the
        // BYOK path becomes the primary action.
        if subscription.isPro {
          useOwnKey.buttonStyle(.borderedProminent).tint(DesignTokens.Palette.accent)
        } else {
          useOwnKey.buttonStyle(.bordered)
        }
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
  GrokAPIKeyEmptyStateView(store: WeatherStore(), subscription: SubscriptionManager.shared)
    .padding()
    .preferredColorScheme(.dark)
}
