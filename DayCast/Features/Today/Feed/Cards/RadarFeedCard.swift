import SwiftUI

struct RadarFeedCard: View {
  @Environment(WeatherStore.self) private var store
  var onTap: (() -> Void)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      Text("Radar")
        .font(DesignTokens.Figma.Typography.subsectionLabel)
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .tracking(DesignTokens.Typography.cardLabelTracking)

      RadarPreviewCard()
        .allowsHitTesting(false)
    }
    .contentShape(Rectangle())
    .onTapGesture {
      Haptic.impact(.medium)
      onTap?()
      store.selectedTab = .radar
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.accessibilityLabel)
    .accessibilityAddTraits(.isButton)
  }

  /// One VoiceOver string for the whole card. Children stay visual-only.
  static let accessibilityLabel = "Live radar preview. Opens the Radar tab."
}
