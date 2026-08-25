import SwiftUI

/// Vertical map-edge layer toggles. Product / map options stay in Layers.
struct RadarLayerRail: View {
  @Bindable var radarState: RadarState
  var onOpenLayers: () -> Void

  var body: some View {
    VStack(spacing: DesignTokens.Spacing.space8) {
      railButton(
        systemImage: "bolt.fill",
        selected: radarState.showLightningLayer && !radarState.showsFuture,
        disabled: radarState.showsFuture,
        label: RadarChromeCopy.lightningLayerSwitch
      ) {
        radarState.showLightningLayer.toggle()
        Analytics.track(
          .lightningLayerToggle,
          parameters: ["on": radarState.showLightningLayer ? "1" : "0"]
        )
      }

      railButton(
        systemImage: "flame.fill",
        selected: radarState.showFireLayer,
        disabled: false,
        label: RadarChromeCopy.fireLayerSwitch
      ) {
        radarState.showFireLayer.toggle()
        Analytics.track(
          .fireLayerToggle, parameters: ["on": radarState.showFireLayer ? "1" : "0"])
      }

      railButton(
        systemImage: "slider.horizontal.3",
        selected: false,
        disabled: false,
        label: RadarChromeCopy.layers
      ) {
        onOpenLayers()
      }
    }
    .padding(DesignTokens.Spacing.space8)
    .background(
      RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
        .fill(DesignTokens.Palette.bgSecondary.opacity(0.94))
    )
    .overlay(
      RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
        .stroke(DesignTokens.Palette.cardHairline, lineWidth: DesignTokens.Card.strokeWidth)
    )
  }

  private func railButton(
    systemImage: String,
    selected: Bool,
    disabled: Bool,
    label: String,
    action: @escaping () -> Void
  ) -> some View {
    Button {
      Haptic.impact(.light)
      action()
    } label: {
      Image(systemName: systemImage)
        .font(DesignTokens.Typography.headline())
        .foregroundStyle(
          selected ? DesignTokens.Palette.bgPrimary : DesignTokens.Palette.textSecondary
        )
        .frame(
          width: DesignTokens.Layout.minHitTarget,
          height: DesignTokens.Layout.minHitTarget
        )
        .background(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(selected ? DesignTokens.Palette.textPrimary : Color.clear)
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(disabled)
    .opacity(disabled ? 0.4 : 1)
    .accessibilityLabel(label)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}
