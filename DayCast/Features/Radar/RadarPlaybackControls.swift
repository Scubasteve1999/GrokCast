import SwiftUI

/// Shared 1x / 2x / 3x chips on the Live panel playback row.
struct RadarPlaybackSpeedPicker: View {
  @Bindable var radarState: RadarState

  var body: some View {
    HStack(spacing: DesignTokens.Spacing.space4) {
      ForEach([1.0, 2.0, 3.0], id: \.self) { speed in
        let label = speed == 3.0 ? "3x" : (speed == 2.0 ? "2x" : "1x")
        let isSelected = abs(radarState.playbackSpeed - speed) < 0.05
        Button {
          Haptic.impact(.light)
          radarState.setPlaybackSpeed(speed)
        } label: {
          Text(label)
            .font(DesignTokens.Typography.caption())
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundStyle(
              isSelected
                ? DesignTokens.Palette.bgPrimary
                : DesignTokens.Palette.textSecondary
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(
              minWidth: DesignTokens.Layout.minHitTarget,
              minHeight: DesignTokens.Layout.minHitTarget
            )
            .background(
              RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                  isSelected
                    ? DesignTokens.Palette.textPrimary
                    : Color.clear
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Playback speed \(label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
      }
    }
    .accessibilityElement(children: .contain)
  }
}
