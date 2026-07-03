import SwiftUI

/// Shown when Grok AI features are unavailable because no xAI developer key is configured.
struct GrokAPIKeyEmptyStateView: View {
  @Environment(WeatherStore.self) private var store

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("Grok AI is optional", systemImage: "sparkles")
        .font(.headline)
        .foregroundStyle(DesignTokens.Palette.textPrimary)

      Text(
        "Weather, radar, and alerts work without an API key. To unlock chat, image generation, and Storm Spotter, add your xAI developer key in Settings."
      )
      .font(.subheadline)
      .foregroundStyle(DesignTokens.Palette.textSecondary)
      .fixedSize(horizontal: false, vertical: true)

      Text(
        "When you use Grok, your weather context and questions are sent to xAI to generate responses. See our Privacy Policy for details."
      )
      .font(.caption)
      .foregroundStyle(DesignTokens.Palette.textTertiary)
      .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 12) {
        Button("Open Settings") {
          Haptic.impact(.light)
          store.selectedTab = .settings
        }
        .buttonStyle(.borderedProminent)
        .tint(DesignTokens.Palette.accent)

        Link(destination: AppLinks.xAIConsole) {
          Text("Get xAI Key")
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
    .padding()
    .preferredColorScheme(.dark)
}
