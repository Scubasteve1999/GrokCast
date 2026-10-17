import SwiftUI

struct LocationPermissionView: View {
  @Environment(WeatherStore.self) private var store

  @State private var showCitySearch = false
  @State private var pendingLocationsPaywall = false

  /// Denied/restricted users can still pick a city — location is never required.
  private var offersCitySearch: Bool {
    switch store.locationService.authorizationStatus {
    case .denied, .restricted: true
    default: false
    }
  }

  var body: some View {
    TodayFirstRunStage {
      TodayFirstRunCard {
        TodayWeatherGlyph(kind: .location)

        Text(title)
          .font(DesignTokens.Typography.title())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .multilineTextAlignment(.center)

        Text(bodyText)
          .font(DesignTokens.Typography.callout())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)

        if let action {
          TodayPrimaryCTA(
            title: action.title,
            systemImage: action.systemImage,
            action: action.handler
          )
          .accessibilityIdentifier(action.identifier)
        }

        if offersCitySearch {
          citySearchButton
        }
      }
    }
    .sheet(isPresented: $showCitySearch, onDismiss: presentPendingLocationsPaywall) {
      AddCitySearchSheet {
        pendingLocationsPaywall = true
        showCitySearch = false
      }
      .presentationDetents([.medium, .large])
      .presentationDragIndicator(.visible)
    }
  }

  @ViewBuilder
  private var citySearchButton: some View {
    // Restricted has no Settings fix, so city search is the primary action there.
    if action == nil {
      TodayPrimaryCTA(title: TodayCopy.searchCity, systemImage: "magnifyingglass") {
        openCitySearch()
      }
      .accessibilityIdentifier(DayCastAccessibility.Today.searchCity)
    } else {
      Button(action: openCitySearch) {
        Label(TodayCopy.searchCity, systemImage: "magnifyingglass")
          .font(DesignTokens.Typography.headline())
          .foregroundStyle(DesignTokens.Palette.accent)
          .frame(maxWidth: .infinity, minHeight: DesignTokens.Layout.minHitTarget)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier(DayCastAccessibility.Today.searchCity)
    }
  }

  private func openCitySearch() {
    Haptic.impact(.light)
    showCitySearch = true
  }

  private func presentPendingLocationsPaywall() {
    guard pendingLocationsPaywall else { return }
    pendingLocationsPaywall = false
    PaywallCoordinator.shared.present(.locations, source: .locations)
  }

  private var title: String {
    switch store.locationService.authorizationStatus {
    case .denied: TodayCopy.deniedTitle
    case .restricted: TodayCopy.restrictedTitle
    default: TodayCopy.permissionTitle
    }
  }

  private var bodyText: String {
    switch store.locationService.authorizationStatus {
    case .denied: TodayCopy.deniedBody
    case .restricted: TodayCopy.restrictedBody
    default: TodayCopy.permissionBody
    }
  }

  private var action: (title: String, systemImage: String, identifier: String, handler: () -> Void)?
  {
    switch store.locationService.authorizationStatus {
    case .notDetermined:
      return (
        TodayCopy.enableLocation,
        "location.fill",
        DayCastAccessibility.Today.enableLocation,
        {
          Haptic.impact(.medium)
          store.markLocationPermissionRequested()
          store.locationService.requestLocationPermission()
        }
      )
    case .denied:
      return (
        TodayCopy.openSettings,
        "gearshape",
        DayCastAccessibility.Today.openSettings,
        {
          Haptic.impact(.medium)
          store.locationService.openSettings()
        }
      )
    default:
      return nil
    }
  }
}

#Preview {
  LocationPermissionView()
    .environment(WeatherStore())
    .preferredColorScheme(.dark)
}
