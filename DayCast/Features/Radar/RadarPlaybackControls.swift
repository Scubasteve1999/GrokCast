import CoreLocation
import SwiftUI

struct RadarPlaybackControls: View {
  @Environment(WeatherStore.self) private var store

  @Bindable var radarState: RadarState
  @Binding var recenterDefaultTrigger: UUID?
  @Binding var recenterUserCoordinate: CLLocationCoordinate2D?

  var body: some View {
    HStack(spacing: DesignTokens.Spacing.space16) {
      Button {
        toggleAnimation()
      } label: {
        Image(systemName: radarState.isAnimating ? "pause.fill" : "play.fill")
          .font(DesignTokens.Typography.studioTitle())
          .foregroundStyle(DesignTokens.Palette.radarAccent)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(radarState.isAnimating ? "Pause" : "Play")

      frameCounter

      Spacer(minLength: 0)

      RadarPlaybackSpeedPicker(radarState: radarState)
      recenterButtons
    }
    .padding(.horizontal, DesignTokens.Spacing.space12)
    .padding(.vertical, DesignTokens.Spacing.space8)
    .background(DesignTokens.Palette.radarTrack)
    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
  }

  private var frameCounter: some View {
    Text(radarState.currentFrameDisplayTime)
      .font(DesignTokens.Typography.caption())
      .foregroundStyle(DesignTokens.Palette.radarTextSecondary)
      .monospacedDigit()
  }

  @ViewBuilder
  private var recenterButtons: some View {
    HStack(spacing: DesignTokens.Spacing.space8) {
      Button {
        Haptic.impact(.light)
        // Prefer selected weather location over a prior GPS recenter.
        recenterUserCoordinate = nil
        recenterDefaultTrigger = UUID()
      } label: {
        Image(systemName: "house.fill")
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.radarAccent)
          .frame(width: 32, height: 32)
          .background(DesignTokens.Palette.radarTrack)
          .clipShape(Capsule())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Recenter to selected location")

      Button {
        Haptic.impact(.light)
        Task { @MainActor in
          let status = store.locationService.authorizationStatus
          if status == .denied || status == .restricted {
            if let cl = store.locationService.currentLocation {
              recenterUserCoordinate = cl.coordinate
            }
            return
          }
          if status == .notDetermined {
            store.locationService.requestLocationPermission()
          }
          do {
            let clLoc = try await store.locationService.requestLocation()
            recenterUserCoordinate = clLoc.coordinate
          } catch {
            if let cl = store.locationService.currentLocation {
              recenterUserCoordinate = cl.coordinate
            }
          }
        }
      } label: {
        Image(systemName: "location.fill")
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.radarAccent)
          .frame(width: 32, height: 32)
          .background(DesignTokens.Palette.radarTrack)
          .clipShape(Capsule())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Center on my current location")
    }
  }

  private func toggleAnimation() {
    radarState.togglePlayback()
  }
}

/// Shared 1x / 2x / 3x chips for phone compact row and iPad playback bar.
struct RadarPlaybackSpeedPicker: View {
  @Bindable var radarState: RadarState

  var body: some View {
    HStack(spacing: 0) {
      ForEach([1.0, 2.0, 3.0], id: \.self) { speed in
        let label = speed == 3.0 ? "3x" : (speed == 2.0 ? "2x" : "1x")
        let isSelected = abs(radarState.playbackSpeed - speed) < 0.05
        Button {
          Haptic.impact(.light)
          radarState.setPlaybackSpeed(speed)
        } label: {
          Text(label)
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(
              isSelected
                ? DesignTokens.Palette.radarAccent : DesignTokens.Palette.radarTextSecondary
            )
            .padding(.horizontal, DesignTokens.Spacing.space8)
            .padding(.vertical, DesignTokens.Spacing.space4)
            .background(
              isSelected
                ? DesignTokens.Palette.radarAccent.opacity(0.25)
                : DesignTokens.Palette.radarTrack
            )
            .overlay(
              Capsule()
                .stroke(DesignTokens.Palette.radarAccent, lineWidth: 1)
                .opacity(isSelected ? 1 : 0)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Playback speed \(label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
      }
    }
    .background(DesignTokens.Palette.radarTrack)
    .clipShape(Capsule())
    .accessibilityElement(children: .contain)
  }
}
