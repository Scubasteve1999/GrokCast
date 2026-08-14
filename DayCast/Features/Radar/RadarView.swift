import CoreLocation
import SwiftUI

struct RadarView: View {
  @Environment(WeatherStore.self) private var store
  @Environment(FireStore.self) private var fireStore
  @Environment(\.scenePhase) private var scenePhase

  @State private var radarOpacity: Double = RadarPreferences.radarOpacity
  @State private var radarState = RadarState()
  @State private var recenterDefaultTrigger: UUID?
  @State private var recenterUserCoordinate: CLLocationCoordinate2D?
  @State private var chaseDecluttered = RadarPreferences.chaseDecluttered

  /// Camera / tile center follows the selected weather location (not device GPS).
  private var selectedMapCenter: CLLocationCoordinate2D {
    store.currentLocation?.coordinate ?? SavedLocation.oliveBranch.coordinate
  }

  private var radarIsDay: Bool {
    store.currentWeather.map {
      WeatherBackgroundView.isDay(from: $0.symbolName)
    } ?? WeatherBackgroundView.inferredIsDay
  }

  /// Day-1 line only when severe context is for the selected location (avoids stale city bleed).
  private var matchingDay1Summary: String? {
    guard let locationID = store.currentLocation?.id.uuidString else { return nil }
    let context = SevereWeatherStore.shared.context
    guard context.locationID == locationID, context.day1Outlook.isMeaningful else { return nil }
    return context.day1Outlook.summaryLine
  }

  var body: some View {
    NavigationStack {
      ZStack {
        radarMapContent
      }
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
      .preferredColorScheme(.dark)
      .task {
        await store.refreshAlerts()
        fireStore.refresh(around: selectedMapCenter)
        if store.selectedTab == .radar, radarState.showContent {
          radarState.start()
        }
      }
      .task(id: store.currentLocation?.id) {
        fireStore.refresh(around: selectedMapCenter)
      }
      .onChange(of: radarState.showFireLayer) { _, isOn in
        if isOn {
          fireStore.refresh(around: selectedMapCenter, force: false)
        }
      }
      .task(id: store.selectedTab) {
        if store.selectedTab == .radar {
          // Re-entering Radar after a long idle rebuilds stale frames so FUTURE
          // reflects the provider's newest run; a quick switch is a no-op.
          let center = selectedMapCenter
          await radarState.reloadIfStale(for: center)
          recenterOnSelectedLocation()
          if radarState.showContent {
            radarState.start()
          }
        }
      }
      // Site products (Super-Res/SRV) follow the selected weather location, and the
      // composite timeline rebuilds when the location moved (provider is per-coordinate).
      .task(id: store.currentLocation?.id) {
        let center = selectedMapCenter
        await radarState.updateNearestSite(for: center)
        await radarState.reloadIfStale(for: center)
        if store.selectedTab == .radar {
          recenterOnSelectedLocation()
        }
      }
      .task(id: radarState.transition?.id) {
        await runModeTransitionIfNeeded()
      }
      .onChange(of: store.selectedTab) { _, newTab in
        if newTab != .radar {
          radarState.stop()
          radarState.cancelModeSwitch()
          recenterDefaultTrigger = nil
          recenterUserCoordinate = nil
        }
      }
      .onChange(of: radarState.committedIsFuture) { _, _ in
        if radarState.isAnimating {
          radarState.start()
        }
      }
      // Returning from the background is the one way onto Radar that no `.task(id:)`
      // covers — neither the tab nor the location changed — so without this the app
      // resumes animating however old the frames were when it was suspended.
      .onChange(of: scenePhase) { _, newPhase in
        switch newPhase {
        case .active:
          guard store.selectedTab == .radar else { return }
          Task {
            // reloadIfStale carries its own thresholds, so a brief trip to the app
            // switcher costs nothing while a long absence rebuilds.
            await radarState.reloadIfStale(for: selectedMapCenter)
            if radarState.showContent {
              radarState.start()
            }
          }
        case .background:
          // A non-repeating Timer whose fire date passed during suspension fires
          // immediately on resume; stopping first keeps playback from advancing
          // through stale frames and fetching their tiles before the reload lands.
          radarState.stop()
        default:
          break
        }
      }
      .onDisappear {
        radarState.stop()
        radarState.cancelModeSwitch()
        recenterDefaultTrigger = nil
        recenterUserCoordinate = nil
      }
      // Opacity is @State so Mapbox updates live; mirror to prefs so the next
      // launch restores the last slider position (speed/overlay already do this).
      .onChange(of: radarOpacity) { _, newValue in
        RadarPreferences.radarOpacity = newValue
      }
      .onChange(of: chaseDecluttered) { _, newValue in
        RadarPreferences.chaseDecluttered = newValue
      }
    }
  }

  @ViewBuilder
  private var radarMapContent: some View {
    ZStack {
      Group {
        if store.selectedTab == .radar {
          GeometryReader { geo in
            if geo.size.width > 50 && geo.size.height > 50 {
              RadarMapboxRepresentable(
                radarState: radarState,
                opacity: radarOpacity,
                defaultMapCenter: selectedMapCenter,
                recenterDefaultTrigger: recenterDefaultTrigger,
                recenterUserCoordinate: recenterUserCoordinate,
                fireSnapshot: fireStore.snapshot
              )
              .frame(width: geo.size.width, height: geo.size.height)
              .frame(minWidth: 400, minHeight: 400)
              .ignoresSafeArea(edges: [.top, .bottom])
            } else {
              Color.clear
                .frame(width: geo.size.width, height: geo.size.height)
                .ignoresSafeArea(edges: [.top, .bottom])
            }
          }
          .frame(minWidth: 400, minHeight: 400)
        } else {
          Color.clear.ignoresSafeArea(edges: [.top, .bottom])
        }
      }
      .ignoresSafeArea(edges: .bottom)
      .overlay {
        WeatherBackgroundView(
          conditionCode: store.currentWeather?.conditionCode,
          isDay: radarIsDay,
          intensity: .subtle
        )
        .opacity(0.18)
        .allowsHitTesting(false)
      }
    }
    .overlay(alignment: .topLeading) {
      if store.selectedTab == .radar {
        VStack(alignment: .leading, spacing: 8) {
          if !chaseDecluttered {
            radarModeBadge
          }
          // Keep offline cue even when decluttered — it's safety-critical chrome.
          if store.isOffline {
            Text("Offline — showing last loaded tiles if available")
              .font(DesignTokens.Typography.micro())
              .foregroundStyle(DesignTokens.Palette.warning)
              .padding(.horizontal, DesignTokens.Spacing.space12)
              .padding(.vertical, 6)
              .background(DesignTokens.Palette.cardBackground.opacity(0.92), in: Capsule())
          }
        }
        .padding(.top, 8)
        .padding(.leading, DesignTokens.Spacing.space20)
      }
    }
    .overlay(alignment: .topTrailing) {
      if store.selectedTab == .radar {
        ChaseRadarHUD(
          radarState: radarState,
          mapCenter: selectedMapCenter,
          alerts: store.displayableActiveAlerts,
          day1Summary: matchingDay1Summary,
          isDecluttered: $chaseDecluttered
        )
        .padding(.top, 8)
        .padding(.trailing, DesignTokens.Spacing.space16)
      }
    }
    .overlay(alignment: .bottom) {
      // Keep the panel mounted so collapse/sheet @State survives declutter.
      RadarControlPanel(
        radarState: radarState,
        opacity: $radarOpacity,
        recenterDefaultTrigger: $recenterDefaultTrigger,
        recenterUserCoordinate: $recenterUserCoordinate
      )
      .padding(.horizontal)
      .padding(.bottom, DesignTokens.Layout.tabBarScrollClearance)
      .opacity(chaseDecluttered ? 0 : 1)
      .allowsHitTesting(!chaseDecluttered)
      .accessibilityHidden(chaseDecluttered)
    }
    .overlay {
      if radarState.showModeSwitchOverlay {
        ZStack {
          Color.black.opacity(0.15)
            .ignoresSafeArea()
          ProgressView()
        }
        .allowsHitTesting(false)
      }
    }
  }

  private var radarModeBadge: some View {
    Text(radarState.showsFuture ? "FUTURE" : "LIVE")
      .font(DesignTokens.Typography.micro())
      .foregroundStyle(DesignTokens.Palette.accent)
      .padding(.horizontal, DesignTokens.Spacing.space12)
      .padding(.vertical, 6)
      .background(DesignTokens.Palette.accent.opacity(0.25), in: Capsule())
      .accessibilityIdentifier(DayCastAccessibility.Radar.liveBadge)
  }

  private func runModeTransitionIfNeeded() async {
    guard let activeTransition = radarState.transition else { return }

    try? await Task.sleep(for: RadarTimelineConfig.modeSwitchDelay)
    guard !Task.isCancelled, radarState.transition?.id == activeTransition.id else {
      // Only roll back if OUR transition is still active — a newer transition from a
      // rapid FUTURE↔LIVE tap must not be torn down here.
      radarState.abortTransition(expectedID: activeTransition.id)
      return
    }

    if activeTransition.targetIsFuture {
      _ = await radarState.refreshForecastTileAvailability()
      guard !Task.isCancelled, radarState.transition?.id == activeTransition.id else {
        radarState.abortTransition(expectedID: activeTransition.id)
        return
      }
    }

    radarState.completeTransition()
  }

  /// Centers the map on the selected weather location. Clears any prior GPS recenter
  /// so device location cannot override the selected place on the next update pass.
  private func recenterOnSelectedLocation() {
    recenterUserCoordinate = nil
    recenterDefaultTrigger = UUID()
  }
}

#Preview {
  RadarView()
    .environment(WeatherStore())
    .environment(FireStore.shared)
}
