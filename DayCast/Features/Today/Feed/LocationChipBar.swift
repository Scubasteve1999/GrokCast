import SwiftUI

/// TWC-style horizontal location switcher pinned above the feed.
struct LocationChipBar: View {
  @Environment(WeatherStore.self) private var store

  var body: some View {
    // Explicit fill (not `.background`) so the plate composites above the
    // scrolling feed. Overlay Color backgrounds lose that fight on iOS 26.
    ZStack(alignment: .bottom) {
      Color.black.opacity(0.22)

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
              .frame(minHeight: DesignTokens.Layout.minHitTarget)
              .background(
                Capsule()
                  .fill(selected ? Color.white.opacity(0.08) : Color.clear)
              )
              .overlay(
                Capsule()
                  .stroke(
                    selected ? DesignTokens.Palette.cardHairline : Color.clear,
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
          .accessibilityIdentifier(Self.accessibilityIdentifier(for: location, selected: selected))
          .contentShape(Capsule())
        }
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.vertical, DesignTokens.Spacing.space4)
      .frame(maxWidth: .infinity, alignment: .leading)

      Rectangle()
        .fill(DesignTokens.Palette.cardHairline)
        .frame(height: DesignTokens.Card.strokeWidth)
        .allowsHitTesting(false)
    }
    .frame(maxWidth: .infinity)
    .fixedSize(horizontal: false, vertical: true)
    .background(alignment: .top) {
      Color.black.opacity(0.22)
        .frame(height: Self.navOverlap)
        .offset(y: -Self.navOverlap)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    .contentShape(Rectangle())
  }

  private func isSelected(_ location: SavedLocation) -> Bool {
    store.currentLocation?.id == location.id
  }

  static func chipTitle(for location: SavedLocation) -> String {
    location.isCurrent ? "Near Me" : location.name
  }

  /// Selected city owns `Today.location` so Now does not need a second name capsule.
  static func accessibilityIdentifier(for location: SavedLocation, selected: Bool) -> String {
    selected
      ? DayCastAccessibility.Today.location
      : DayCastAccessibility.Locations.chip(chipTitle(for: location))
  }

  /// Overlay is only the plated strip. Hits below the plate still reach the
  /// feed (Live Radar). The plate itself is opaque chrome and catches taps.
  static let emptyStripPassesHitsThrough = true

  /// First-layout stand-in until the overlay reports its measured height.
  static let reservedHeight: CGFloat = 52

  /// Layout-neutral overlap into the inline nav. Not part of `reservedHeight`.
  static let navOverlap: CGFloat = 8
}

struct ChipBarHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = LocationChipBar.reservedHeight
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}
