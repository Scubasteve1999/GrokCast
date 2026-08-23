import SwiftUI

struct LocationPermissionView: View {
  @Environment(WeatherStore.self) private var store

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
      }
    }
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
