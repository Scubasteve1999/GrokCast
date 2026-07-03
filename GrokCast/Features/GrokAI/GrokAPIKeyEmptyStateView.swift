import SwiftUI

/// Shown when Grok AI requires GrokCast Pro or a developer key.
struct GrokAPIKeyEmptyStateView: View {
  @Environment(WeatherStore.self) private var store
  @Environment(SubscriptionManager.self) private var subscription

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("GrokCast Pro", systemImage: "sparkles")
        .font(.headline)
        .foregroundStyle(DesignTokens.Palette.textPrimary)

      Text(
        "Weather, live radar, and alerts are free. Pro unlocks Grok chat, daily briefs, Storm Spotter, forecast radar, Live Activity, and unlimited locations — no developer key needed."
      )
      .font(.subheadline)
      .foregroundStyle(DesignTokens.Palette.textSecondary)
      .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 12) {
        Button(subscription.isPro ? "Pro Active" : "Upgrade to Pro") {
          Haptic.impact(.light)
          if subscription.isPro {
            store.selectedTab = .settings
          } else {
            PaywallCoordinator.shared.present(.grokAI)
          }
        }
        .buttonStyle(.borderedProminent)
        .tint(DesignTokens.Palette.accent)
        .disabled(subscription.isPro)

        Button("Settings") {
          Haptic.impact(.light)
          store.selectedTab = .settings
        }
        .buttonStyle(.bordered)
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
  GrokAPIKeyEmptyStateView()
    .environment(WeatherStore())
    .environment(SubscriptionManager.shared)
    .padding()
    .preferredColorScheme(.dark)
}
