import SwiftUI

/// Solid `cardElevated` chip. Glance Forecast/Radar and in-thread
/// **Check this sky** — never `.borderedProminent` (iOS 26 glass).
struct SkyCheckSolidChip: View {
  let title: String
  var systemImage: String? = nil
  var identifier: String
  var isDisabled: Bool = false
  let action: () -> Void

  var body: some View {
    Button {
      Haptic.impact(.light)
      action()
    } label: {
      titleLabel
        .font(DesignTokens.Typography.caption().weight(.semibold))
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .padding(.horizontal, DesignTokens.Spacing.space12)
        .frame(minHeight: DesignTokens.Layout.minHitTarget)
        .background(DesignTokens.Palette.cardElevated)
        .overlay(
          RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
            .stroke(DesignTokens.Palette.cardHairline, lineWidth: DesignTokens.Card.strokeWidth)
        )
        .clipShape(
          RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
        )
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
    .accessibilityLabel(title)
    .accessibilityIdentifier(identifier)
    .accessibilityAddTraits(.isButton)
  }

  @ViewBuilder
  private var titleLabel: some View {
    if let systemImage {
      Label(title, systemImage: systemImage)
    } else {
      Text(title)
    }
  }
}
