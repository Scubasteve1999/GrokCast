import SwiftUI

struct RadarTimelineScrubber: View {
  @Bindable var radarState: RadarState

  @State private var isScrubbing = false
  @State private var wasAnimatingBeforeScrub = false

  var body: some View {
    if radarState.activeFrameCount > 1 {
      VStack(spacing: DesignTokens.Spacing.space4) {
        Slider(
          value: Binding(
            get: { Double(clampedIndex) },
            set: { radarState.currentIndex = Int($0.rounded()) }
          ),
          in: 0...Double(radarState.activeFrameCount - 1),
          step: 1
        ) { editing in
          handleScrubEditing(editing)
        }
        .tint(DesignTokens.Palette.radarProgress)
        .frame(height: 36)

        tickLabels
      }
      .padding(DesignTokens.Spacing.space8)
      .background(DesignTokens.Palette.radarTrack)
      .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
    }
  }

  private var clampedIndex: Int {
    max(0, min(radarState.currentIndex, max(0, radarState.activeFrameCount - 1)))
  }

  @ViewBuilder
  private var tickLabels: some View {
    let labels = frameLabels
    if !labels.isEmpty {
      let count = radarState.activeFrameCount
      let keys = (0..<count).filter { $0 % max(1, count / 5) == 0 || $0 == count - 1 }
      HStack(spacing: 0) {
        ForEach(Array(keys), id: \.self) { i in
          let label = i < labels.count ? labels[i] : "?"
          Text(label)
            .font(.caption2.weight(radarState.currentIndex == i ? .semibold : .regular))
            .foregroundStyle(
              radarState.currentIndex == i
                ? DesignTokens.Palette.radarTextPrimary : DesignTokens.Palette.radarTextSecondary
            )
            .padding(.vertical, DesignTokens.Spacing.space2)
            .frame(
              maxWidth: .infinity,
              alignment: i == 0 ? .leading : (i == count - 1 ? .trailing : .center))
        }
      }
    }
  }

  private var frameLabels: [String] {
    radarState.activeFrameLabels
  }

  private func handleScrubEditing(_ editing: Bool) {
    if editing {
      if !isScrubbing {
        isScrubbing = true
        wasAnimatingBeforeScrub = radarState.isAnimating
        if radarState.isAnimating {
          radarState.stop()
        }
      }
    } else if isScrubbing {
      isScrubbing = false
      if radarState.autoResumeAfterScrub && wasAnimatingBeforeScrub {
        radarState.start()
      }
      wasAnimatingBeforeScrub = false
    }
  }
}
