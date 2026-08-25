import CoreLocation
import SwiftUI

struct RadarView: View {
  @Environment(WeatherStore.self) private var store
  @Environment(FireStore.self) private var fireStore
  @Environment(LightningStore.self) private var lightningStore
  @Environment(ShortTermPrecipStore.self) private var shortTermStore
  @Environment(\.scenePhase) private var scenePhase

  @State private var radarOpacity: Double = RadarPreferences.radarOpacity
  @State private var radarState = RadarState()
  @State private var recenterDefaultTrigger: UUID?
  @State private var recenterUserCoordinate: CLLocationCoordinate2D?
  @State private var chaseDecluttered = RadarPreferences.chaseDecluttered
  @State private var showDisplayOptions = false

  /// Camera / tile center follows the selected weather location (not device GPS).
  private var selectedMapCenter: CLLocationCoordinate2D {
    store.currentLocation?.coordinate ?? SavedLocation.oliveBranch.coordinate
  }

  /// On-map dBZ key follows the paint: National floors at 15 green; Site N0B at 25.
  private var showsReflectivityColorbar: Bool {
    radarState.showRadarOverlay && !radarState.selectedProduct.isVelocityProduct
  }

  private var colorbarKeysClearAir: Bool {
    radarState.selectedProduct.isSiteProduct && !radarState.showsFuture
  }

  /// Lightning is Live-only observed CG. Hidden in 24-hr.
  private var showsLightningOverlay: Bool {
    radarState.showLightningLayer && !radarState.showsFuture
  }

  private var radarDataUnavailable: Bool {
    store.selectedTab == .radar
      && RadarChromeCopy.showsUnavailableOverlay(
        hasContent: radarState.showContent,
        isLoading: radarState.isLoading,
        hasCompletedLoadAttempt: radarState.hasCompletedLoadAttempt
      )
  }

  private var radarControlsInteractive: Bool {
    RadarChromeCopy.controlsInteractive(
      hasContent: radarState.showContent,
      isLoading: radarState.isLoading,
      hasCompletedLoadAttempt: radarState.hasCompletedLoadAttempt
    )
  }

  private var radarTakeaway: String? {
    ChaseRadarHUDLogic.takeaway(
      showsFuture: radarState.showsFuture,
      minutecastMessage: radarMinutecastMessage,
      conditionCode: store.displayedWeather?.conditionCode
    )
  }

  private var radarMinutecastMessage: String? {
    guard let weather = store.displayedWeather else { return nil }
    let locID = store.currentLocation?.id.uuidString
    let summary: MinutecastSummary
    if let locID, shortTermStore.context.locationID == locID,
      shortTermStore.context.isUsableHRRR()
    {
      summary =
        shortTermStore.context.summary
        ?? MinutecastEngine.summary(
          from: shortTermStore.context.slots, units: store.temperatureUnit)
    } else {
      summary = MinutecastEngine.summary(
        from: weather.minutely15, units: store.temperatureUnit)
    }
    return summary.message
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
          radarState.presentLiveNow()
        }
      }
      .task(id: store.displayedWeather?.timezoneIdentifier) {
        radarState.displayTimeZone =
          store.displayedWeather?.locationTimeZone ?? .current
      }
      .task(id: store.currentLocation?.id) {
        fireStore.refresh(around: selectedMapCenter)
      }
      .task(id: lightningPollKey) {
        if store.selectedTab == .radar, showsLightningOverlay {
          lightningStore.startPolling(around: selectedMapCenter)
        } else {
          lightningStore.stopPolling()
        }
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
          await radarState.handleLiveOpen(for: center)
          if radarState.showContent {
            radarState.presentLiveNow()
          }
        }
      }
      // Site products (Super-Res/SRV) follow the selected weather location, and the
      // composite timeline rebuilds when the location moved (provider is per-coordinate).
      .task(id: store.currentLocation?.id) {
        let center = selectedMapCenter
        await radarState.updateNearestSite(for: center)
        if store.selectedTab == .radar {
          await radarState.handleLiveOpen(for: center)
        } else {
          await radarState.reloadIfStale(for: center)
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
          lightningStore.stopPolling()
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
          if showsLightningOverlay {
            lightningStore.startPolling(around: selectedMapCenter)
          }
          Task {
            // reloadIfStale carries its own thresholds, so a brief trip to the app
            // switcher costs nothing while a long absence rebuilds.
            await radarState.reloadIfStale(for: selectedMapCenter)
            if radarState.showContent {
              radarState.presentLiveNow()
            }
          }
        case .background:
          // A non-repeating Timer whose fire date passed during suspension fires
          // immediately on resume; stopping first keeps playback from advancing
          // through stale frames and fetching their tiles before the reload lands.
          radarState.stop()
          lightningStore.stopPolling()
        default:
          break
        }
      }
      .onDisappear {
        radarState.stop()
        radarState.cancelModeSwitch()
        recenterDefaultTrigger = nil
        recenterUserCoordinate = nil
        lightningStore.stopPolling()
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
                fireSnapshot: fireStore.snapshot,
                lightningSnapshot: lightningStore.snapshot,
                alerts: store.displayableActiveAlerts
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
      .allowsHitTesting(radarControlsInteractive)
      .opacity(radarDataUnavailable ? 0.45 : 1)
    }
    .overlay(alignment: .topLeading) {
      if store.selectedTab == .radar {
        VStack(alignment: .leading, spacing: 8) {
          // Keep offline cue even when decluttered — it's safety-critical chrome.
          if store.isOffline {
            Text("Offline — showing last loaded tiles if available")
              .font(DesignTokens.Typography.micro())
              .foregroundStyle(DesignTokens.Palette.warning)
              .padding(.horizontal, DesignTokens.Spacing.space12)
              .padding(.vertical, 6)
              .background(DesignTokens.Palette.cardBackground.opacity(0.92), in: Capsule())
          }
          radarLocationChip
        }
        .safeAreaPadding(.top)
        .padding(.top, 4)
        .padding(.leading, DesignTokens.Spacing.space16)
      }
    }
    .overlay(alignment: .topLeading) {
      if store.selectedTab == .radar {
        warningPolygonVoiceOver
      }
    }
    .overlay(alignment: .topTrailing) {
      if store.selectedTab == .radar {
        ChaseRadarHUD(
          radarState: radarState,
          mapCenter: selectedMapCenter,
          cityName: store.currentLocation?.name,
          alerts: store.displayableActiveAlerts,
          takeaway: radarTakeaway,
          isDecluttered: $chaseDecluttered
        )
        .safeAreaPadding(.top)
        .padding(.top, 4)
        .padding(.trailing, DesignTokens.Spacing.space16)
        .opacity(radarDataUnavailable ? 0.4 : 1)
        .allowsHitTesting(radarControlsInteractive)
        .accessibilityHidden(radarDataUnavailable)
      }
    }
    .overlay(alignment: .trailing) {
      if store.selectedTab == .radar {
        RadarLayerRail(radarState: radarState) {
          showDisplayOptions = true
        }
        .padding(.trailing, DesignTokens.Spacing.space12)
        .padding(.bottom, 72)
        .opacity(radarDataUnavailable ? 0.4 : 1)
        .allowsHitTesting(radarControlsInteractive)
        .accessibilityHidden(radarDataUnavailable)
      }
    }
    .overlay(alignment: .bottomLeading) {
      if store.selectedTab == .radar {
        VStack(alignment: .leading, spacing: 6) {
          if showsLightningOverlay, lightningStore.showsQuietAttribution {
            Text(lightningStore.attributionLabel)
              .font(DesignTokens.Typography.micro())
              .foregroundStyle(DesignTokens.Palette.radarTextSecondary)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(
                DesignTokens.Palette.cardBackground.opacity(0.94),
                in: Capsule()
              )
              .accessibilityLabel(lightningStore.attributionLabel)
          }
          if showsReflectivityColorbar {
            RadarMapColorbar(keysClearAir: colorbarKeysClearAir)
          }
        }
        .padding(.leading, DesignTokens.Spacing.space12)
        .padding(.bottom, WeatherStageSheet.tabBarClearance + 156)
        .allowsHitTesting(false)
      }
    }
    .overlay(alignment: .bottom) {
      WeatherStageSheet.fill
        .frame(height: WeatherStageSheet.tabBarClearance)
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    .overlay(alignment: .bottom) {
      // Keep the panel mounted so collapse/sheet @State survives declutter.
      RadarControlPanel(
        radarState: radarState,
        opacity: $radarOpacity,
        isDecluttered: $chaseDecluttered,
        showDisplayOptions: $showDisplayOptions
      )
      .padding(.bottom, WeatherStageSheet.tabBarClearance)
      .opacity(
        RadarChromeVisibility.showsControlSheet(mapOnly: chaseDecluttered) && radarControlsInteractive
          ? 1 : (radarDataUnavailable ? 0.35 : 0)
      )
      .allowsHitTesting(
        RadarChromeVisibility.showsControlSheet(mapOnly: chaseDecluttered)
          && radarControlsInteractive
      )
      .accessibilityHidden(
        !RadarChromeVisibility.showsControlSheet(mapOnly: chaseDecluttered)
          || radarDataUnavailable
      )
    }
    .overlay {
      if radarDataUnavailable {
        ZStack {
          Color.black.opacity(0.42)
            .ignoresSafeArea()
            .allowsHitTesting(true)
          radarUnavailableCard
        }
      }
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

  private var radarLocationChip: some View {
    Button {
      Haptic.impact(.light)
      recenterUserCoordinate = nil
      recenterDefaultTrigger = UUID()
    } label: {
      HStack(spacing: DesignTokens.Spacing.space8) {
        if let weather = store.displayedWeather {
          Image(systemName: weather.symbolName)
            .font(DesignTokens.Typography.callout())
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Color.white)
        }
        Text(store.currentLocation?.name ?? weatherNameFallback)
          .font(DesignTokens.Typography.subsection())
          .foregroundStyle(Color.white)
          .lineLimit(1)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .frame(maxWidth: 220)
      .background(Color.black.opacity(0.46), in: Capsule())
      .overlay(Capsule().stroke(DesignTokens.Palette.cardHairline, lineWidth: 1))
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Recenter to \(store.currentLocation?.name ?? weatherNameFallback)")
  }

  private var weatherNameFallback: String {
    store.displayedWeather?.location.name ?? "Radar"
  }

  private var radarUnavailableCard: some View {
    VStack(spacing: DesignTokens.Spacing.space12) {
      Text(RadarChromeCopy.unavailableTitle)
        .font(DesignTokens.Typography.headline())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .multilineTextAlignment(.center)
      Text(RadarChromeCopy.unavailableHint)
        .font(DesignTokens.Typography.callout())
        .foregroundStyle(DesignTokens.Palette.textSecondary)
        .multilineTextAlignment(.center)
      Button {
        Haptic.impact(.medium)
        Task { await radarState.handleLiveOpen(for: selectedMapCenter) }
      } label: {
        Text(RadarChromeCopy.unavailableRetry)
          .font(DesignTokens.Typography.body().weight(.semibold))
          .frame(maxWidth: .infinity)
          .padding(.vertical, DesignTokens.Spacing.space12)
      }
      .buttonStyle(.borderedProminent)
      .tint(DesignTokens.Palette.accent)
      .accessibilityIdentifier(DayCastAccessibility.Radar.unavailableRetry)
      .accessibilityLabel("Retry loading radar")
    }
    .padding(DesignTokens.Spacing.space24)
    .frame(maxWidth: 320)
    .cardStyle()
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(DayCastAccessibility.Radar.unavailableCard)
  }

  /// VoiceOver names for painted boxes. GeoJSON layers don't eat pan; this overlay doesn't either.
  private var warningPolygonVoiceOver: some View {
    let boxes = RadarWarningPolygon.drawn(from: store.displayableActiveAlerts)
    return Color.clear
      .frame(width: 1, height: 1)
      .allowsHitTesting(false)
      .accessibilityElement(children: .contain)
      .accessibilityChildren {
        ForEach(boxes) { box in
          Text(box.accessibilityLabel)
            .accessibilityLabel(box.accessibilityLabel)
        }
      }
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

  /// Restart lightning polls when tab, toggle, Live/24-hr, or city changes.
  private var lightningPollKey: String {
    let locationID = store.currentLocation?.id.uuidString ?? "olive"
    return "\(store.selectedTab == .radar)|\(showsLightningOverlay)|\(locationID)"
  }
}

#Preview {
  RadarView()
    .environment(WeatherStore())
    .environment(FireStore.shared)
    .environment(LightningStore.shared)
    .environment(ShortTermPrecipStore.shared)
}
