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

  @ViewBuilder
  private var figmaScrubber: some View {
    let count = radarState.activeFrameCount
    let labels = radarState.activeFrameLabels

    VStack(spacing: DesignTokens.Spacing.space4) {
      GeometryReader { geo in
        let progress =
          count > 1
          ? CGFloat(clampedIndex) / CGFloat(count - 1)
          : 0
        let thumbX = geo.size.width * progress

        ZStack(alignment: .leading) {
          Capsule()
            .fill(DesignTokens.Palette.radarTrack)
            .frame(height: 4)
          Capsule()
            .fill(DesignTokens.Palette.radarProgress)
            .frame(width: max(4, thumbX), height: 4)

          if isScrubbing {
            let tooltipWidth: CGFloat = 60
            let clampedX = min(max(thumbX - tooltipWidth / 2, 0), geo.size.width - tooltipWidth)
            Text(radarState.currentFrameDisplayTime)
              .font(.caption2.weight(.semibold).monospacedDigit())
              .foregroundStyle(DesignTokens.Palette.radarTextPrimary)
              .padding(.horizontal, 6)
              .padding(.vertical, 3)
              .background(
                Capsule().fill(DesignTokens.Palette.radarTrack)
              )
              .fixedSize()
              .offset(x: clampedX, y: -22)
              .transition(.opacity)
              .animation(.easeOut(duration: 0.12), value: clampedIndex)
          }
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
              let index = Int((fraction * CGFloat(count - 1)).rounded())
              radarState.currentIndex = index
            }
            .onEnded { _ in
              handleScrubEditing(false)
            }
        )
      }
      .frame(height: 24)

      if !labels.isEmpty, count > 1 {
        figmaTickLabels(labels: labels, count: count)
      }
    }
  }

  private func figmaTickLabels(labels: [String], count: Int) -> some View {
    let stride = max(1, count / 4)
    let indices = (0..<count).filter { $0 % stride == 0 || $0 == count - 1 }

    return HStack(spacing: 0) {
      ForEach(indices, id: \.self) { i in
        let label = i < labels.count ? labels[i] : "?"
        Text(label)
          .font(.system(size: 9).monospacedDigit())
          .foregroundStyle(
            clampedIndex == i
              ? DesignTokens.Palette.radarTextPrimary
              : DesignTokens.Palette.radarTextSecondary
          )
          .frame(
            maxWidth: .infinity,
            alignment: i == indices.first ? .leading : (i == indices.last ? .trailing : .center)
          )
      }
    }
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
