import SwiftUI

/// One label, same as Hourly/Daily and the Radar tab. The preview used to
/// stack “Radar / Live Radar / Radar / Open” on top of Apple Maps Legal.
enum RadarFeedCopy {
  static let title = "Radar"
  static let accessibilityLabel = "Radar. Opens the Radar tab."
}

struct RadarFeedCard: View {
  @Environment(WeatherStore.self) private var store
  var onTap: (() -> Void)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      HStack {
        Text(RadarFeedCopy.title)
          .font(DesignTokens.Typography.subsection())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
          .tracking(DesignTokens.Typography.cardLabelTracking)
        Spacer()
        Image(systemName: "chevron.right")
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }

      RadarPreviewCard()
        .allowsHitTesting(false)
    }
    .padding(DesignTokens.Spacing.space16)
    .cardStyle()
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

  static let accessibilityLabel = RadarFeedCopy.accessibilityLabel
}
