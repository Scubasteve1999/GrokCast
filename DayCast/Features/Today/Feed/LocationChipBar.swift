import SwiftUI

/// TWC-style horizontal location switcher pinned above the feed.
struct LocationChipBar: View {
  @Environment(WeatherStore.self) private var store

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: DesignTokens.Spacing.space8) {
        ForEach(store.savedLocations) { location in
          Button {
            Haptic.selection()
            store.selectLocation(location)
            Analytics.track(.feedCardTap, parameters: ["card": "location_chip"])
          } label: {
            Text(chipTitle(for: location))
              .font(
                isSelected(location)
                  ? DesignTokens.Typography.subsection() : DesignTokens.Typography.callout()
              )
              .foregroundStyle(
                isSelected(location)
                  ? DesignTokens.Palette.textPrimary
                  : DesignTokens.Palette.textSecondary
              )
              .padding(.horizontal, DesignTokens.Spacing.space12)
              .padding(.vertical, DesignTokens.Spacing.space8)
              .background(
                Capsule()
                  .fill(
                    isSelected(location)
                      ? DesignTokens.Palette.accent.opacity(0.35)
                      : DesignTokens.Palette.cardBackground
                  )
              )
              .overlay(
                Capsule()
                  .stroke(
                    isSelected(location)
                      ? DesignTokens.Palette.accent.opacity(0.7)
                      : DesignTokens.Palette.cardStroke,
                    lineWidth: DesignTokens.Card.strokeWidth
                  )
              )
          }
          .buttonStyle(.plain)
          .accessibilityLabel(chipTitle(for: location))
          .accessibilityAddTraits(isSelected(location) ? .isSelected : [])
        }
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  private func isSelected(_ location: SavedLocation) -> Bool {
    store.currentLocation?.id == location.id
  }

  private func chipTitle(for location: SavedLocation) -> String {
    if location.isCurrent { return "Near Me" }
    return location.name
  }
}
