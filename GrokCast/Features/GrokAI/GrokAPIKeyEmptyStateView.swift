import SwiftUI

/// Shown when Grok AI requires SpotterCast Pro or a developer key.
struct GrokAPIKeyEmptyStateView: View {
  @Bindable var store: WeatherStore
  @Bindable var subscription: SubscriptionManager

  init(store: WeatherStore, subscription: SubscriptionManager) {
    self.store = store
    self.subscription = subscription
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("SpotterCast Pro", systemImage: "sparkles")
        .font(.headline)
        .foregroundStyle(DesignTokens.Palette.textPrimary)

      Text(
        "Weather, live radar, and alerts are free. Grok chat needs an xAI developer key in Settings. Pro unlocks forecast radar, Live Activity, and unlimited locations."
      )
      .font(.subheadline)
      .foregroundStyle(DesignTokens.Palette.textSecondary)
      .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 12) {
        Button("Add Key in Settings") {
          Haptic.impact(.light)
          store.selectedTab = .settings
        }
        .buttonStyle(.borderedProminent)
        .tint(DesignTokens.Palette.accent)

        if !subscription.isPro {
          Button("View Pro") {
            Haptic.impact(.light)
            PaywallCoordinator.shared.present(.locations)
          }
          .buttonStyle(.bordered)
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
