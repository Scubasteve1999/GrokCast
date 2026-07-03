import SwiftUI

enum RadarTimelineScrubberLayout {
  case standard
  /// Figma Radar HUD: thin 4pt progress track without tick labels.
  case figma
}

struct RadarTimelineScrubber: View {
  @Bindable var radarState: RadarState
  var layout: RadarTimelineScrubberLayout = .standard

  @State private var isScrubbing = false
  @State private var wasAnimatingBeforeScrub = false

  var body: some View {
    if radarState.activeFrameCount > 1 {
      switch layout {
      case .standard:
        standardScrubber
      case .figma:
        figmaScrubber
      }
    }
  }

  private var figmaScrubber: some View {
    GeometryReader { geo in
      let progress =
        radarState.activeFrameCount > 1
        ? CGFloat(clampedIndex) / CGFloat(radarState.activeFrameCount - 1)
        : 0

      ZStack(alignment: .leading) {
        Capsule()
          .fill(DesignTokens.Palette.radarTrack)
          .frame(height: 4)
        Capsule()
          .fill(DesignTokens.Palette.radarProgress)
          .frame(width: max(4, geo.size.width * progress), height: 4)
      }
      .frame(maxHeight: .infinity, alignment: .center)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            if !isScrubbing {
              handleScrubEditing(true)
            }
            let fraction = min(max(0, value.location.x / max(geo.size.width, 1)), 1)
            let index = Int((fraction * CGFloat(radarState.activeFrameCount - 1)).rounded())
            radarState.currentIndex = index
          }
          .onEnded { _ in
            handleScrubEditing(false)
          }
      )
    }
    .frame(height: 24)
  }

  private var standardScrubber: some View {
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
    .onChange(of: radarState.currentIndex) { _, _ in
      if isScrubbing {
        Haptic.selection()
      }
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
            .lineLimit(1)
            .minimumScaleFactor(0.7)
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
