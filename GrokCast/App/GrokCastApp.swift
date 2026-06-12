import SwiftUI

@main
struct GrokCastApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      MainTabView()
        .environment(WeatherStore.shared)
        .tint(.accentColor)
    }
  }
}
