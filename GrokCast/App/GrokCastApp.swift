import SwiftUI

@main
struct GrokCastApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("-MarketingScreenshot") {
        MarketingScreenshotLauncher()
      } else {
        MainTabView()
          .environment(WeatherStore.shared)
          .tint(.accentColor)
      }
      #else
      MainTabView()
        .environment(WeatherStore.shared)
        .tint(.accentColor)
      #endif
    }
  }
}
