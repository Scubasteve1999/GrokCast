import SwiftUI

/// TWC-style horizontal location switcher pinned above the feed.
struct LocationChipBar: View {
  @Environment(WeatherStore.self) private var store

  var body: some View {
    // No horizontal ScrollView: inset ScrollViews only publish the selected
    // chip to VoiceOver. A wrapping HStack keeps every visible city a button.
    HStack(spacing: DesignTokens.Spacing.space8) {
      ForEach(store.savedLocations) { location in
        let title = Self.chipTitle(for: location)
        let selected = isSelected(location)
        Button {
          Haptic.selection()
          store.selectLocation(location)
          Analytics.track(.feedCardTap, parameters: ["card": "location_chip"])
        } label: {
          Text(title)
            .font(
              selected
                ? DesignTokens.Typography.subsection() : DesignTokens.Typography.callout()
            )
            .foregroundStyle(
              selected
                ? DesignTokens.Palette.textPrimary
                : DesignTokens.Palette.textSecondary
            )
            .padding(.horizontal, DesignTokens.Spacing.space12)
            .padding(.vertical, DesignTokens.Spacing.space8)
            .background(
              Capsule()
                .fill(
                  selected
                    ? DesignTokens.Palette.accent.opacity(0.35)
                    : DesignTokens.Palette.cardBackground
                )
            )
            .overlay(
              Capsule()
                .stroke(
                  selected
                    ? DesignTokens.Palette.accent.opacity(0.7)
                    : DesignTokens.Palette.cardStroke,
                  lineWidth: DesignTokens.Card.strokeWidth
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(selected ? "Selected city" : "Shows weather for this city")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(DayCastAccessibility.Locations.chip(title))
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, DesignTokens.Spacing.space20)
    .fixedSize(horizontal: false, vertical: true)
  }

  private func isSelected(_ location: SavedLocation) -> Bool {
    store.currentLocation?.id == location.id
  }

  static func chipTitle(for location: SavedLocation) -> String {
    location.isCurrent ? "Near Me" : location.name
  }
}
