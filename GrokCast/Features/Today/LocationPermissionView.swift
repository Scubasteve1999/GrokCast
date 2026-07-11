import SwiftUI

struct LocationPermissionView: View {
  @Environment(WeatherStore.self) private var store

  var body: some View {
    VStack(spacing: 24) {
      Image(systemName: "location.fill")
        .font(.system(size: 64))
        .foregroundStyle(.white)
        .symbolEffect(.pulse, options: .repeating)

      Text("LOCATION ACCESS")
        .font(.title2.weight(.black))
        .tracking(2)

      switch store.locationService.authorizationStatus {
      case .notDetermined:
        Text(
          "SpotterCast uses your location to show accurate local weather forecasts and AI-powered insights."
        )
        .font(.body)
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)

        Button {
          Haptic.impact(.medium)
          store.markLocationPermissionRequested()
          store.locationService.requestLocationPermission()
        } label: {
          Label("ENABLE LOCATION", systemImage: "location.fill")
            .font(.footnote.weight(.semibold))
            .tracking(1.5)
        }
        .buttonStyle(.borderedProminent)
        .tint(.indigo.opacity(0.7))
        .padding(.top, 8)

      case .denied:
        Text(
          "Location access was denied. Enable it in Settings to use your current position for weather and insights."
        )
        .font(.body)
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)

        Button {
          Haptic.impact(.medium)
          store.locationService.openSettings()
        } label: {
          Label("OPEN SETTINGS", systemImage: "gearshape")
            .font(.footnote.weight(.semibold))
            .tracking(1.5)
        }
        .buttonStyle(.borderedProminent)
        .tint(.indigo.opacity(0.7))
        .padding(.top, 8)

      case .restricted:
        Text(
          "Location access is restricted on this device. Check Settings > Screen Time or parental controls."
        )
        .font(.body)
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)

      case .authorized, .authorizedWhenInUse, .authorizedAlways:
        EmptyView()

      default:
        EmptyView()
      }
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    .foregroundStyle(.white)
  }
}

#Preview {
  LocationPermissionView()
    .environment(WeatherStore())
    .preferredColorScheme(.dark)
}
