import CoreLocation
import SwiftUI

struct RadarView: View {
  @Environment(WeatherStore.self) private var store

  @State private var radarOpacity: Double = 0.75
  @State private var radarState = RadarState()
  @State private var recenterDefaultTrigger: UUID?
  @State private var recenterUserCoordinate: CLLocationCoordinate2D?
  @State private var autoCenterTask: Task<Void, Never>?

  private var defaultMapCenter: CLLocationCoordinate2D {
    SavedLocation.oliveBranch.coordinate
  }

  private var radarIsDay: Bool {
    store.currentWeather.map {
      WeatherBackgroundView.isDay(from: $0.symbolName)
    } ?? WeatherBackgroundView.inferredIsDay
  }

  var body: some View {
    NavigationStack {
      ZStack {
        radarMapContent
      }
      .navigationTitle("Radar")
      .navigationBarTitleDisplayMode(.inline)
      .preferredColorScheme(.dark)
      .task {
        await store.refreshAlerts()
        let center = store.currentLocation?.coordinate ?? defaultMapCenter
        await radarState.loadDefaultRadar(for: center)
        if store.selectedTab == .radar, radarState.showContent {
          radarState.start()
        }
      }
      .task(id: store.selectedTab) {
        if store.selectedTab == .radar {
          autoCenterIfAuthorized()
          if radarState.showContent {
            radarState.start()
          }
        }
      }
      // Site products (Super-Res/SRV) follow the selected weather location.
      .task(id: store.currentLocation?.id) {
        let center = store.currentLocation?.coordinate ?? defaultMapCenter
        await radarState.updateNearestSite(for: center)
      }
      .task(id: radarState.transition?.id) {
        await runModeTransitionIfNeeded()
      }
      .onChange(of: store.selectedTab) { _, newTab in
        if newTab != .radar {
          radarState.stop()
          radarState.cancelModeSwitch()
          autoCenterTask?.cancel()
          autoCenterTask = nil
          recenterDefaultTrigger = nil
          recenterUserCoordinate = nil
        }
      }
      .onChange(of: radarState.committedIsFuture) { _, _ in
        if radarState.isAnimating {
          radarState.start()
        }
      }
      .onDisappear {
        radarState.stop()
        radarState.cancelModeSwitch()
        autoCenterTask?.cancel()
        autoCenterTask = nil
        recenterDefaultTrigger = nil
        recenterUserCoordinate = nil
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
                defaultMapCenter: defaultMapCenter,
                recenterDefaultTrigger: recenterDefaultTrigger,
                recenterUserCoordinate: recenterUserCoordinate
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
    .overlay(alignment: .bottom) {
      RadarControlPanel(
        radarState: radarState,
        opacity: $radarOpacity,
        recenterDefaultTrigger: $recenterDefaultTrigger,
        recenterUserCoordinate: $recenterUserCoordinate
      )
      .padding(.horizontal)
      .padding(.bottom, 24)
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

  private func runModeTransitionIfNeeded() async {
    guard let activeTransition = radarState.transition else { return }

    try? await Task.sleep(for: RadarTimelineConfig.modeSwitchDelay)
    guard !Task.isCancelled, radarState.transition?.id == activeTransition.id else {
      radarState.abortTransition()
      return
    }

    if activeTransition.targetIsFuture {
      _ = await radarState.refreshForecastTileAvailability()
      guard !Task.isCancelled, radarState.transition?.id == activeTransition.id else {
        radarState.abortTransition()
        return
      }
    }

    radarState.completeTransition()
  }

  private func autoCenterIfAuthorized() {
    let status = store.locationService.authorizationStatus
    guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
    autoCenterTask?.cancel()
    autoCenterTask = Task { @MainActor in
      let coordinate: CLLocationCoordinate2D
      if let last = store.locationService.currentLocation {
        coordinate = last.coordinate
      } else {
        do {
          let loc = try await store.locationService.requestLocation()
          coordinate = loc.coordinate
        } catch {
          return
        }
      }
      guard !Task.isCancelled, store.selectedTab == .radar else { return }
      recenterUserCoordinate = coordinate
    }
  }
}

#Preview {
  RadarView()
    .environment(WeatherStore())
}
