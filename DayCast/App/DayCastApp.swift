import SwiftUI

@main
struct DayCastApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var subscriptionManager = SubscriptionManager.shared

  var body: some Scene {
    WindowGroup {
      #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("-MarketingScreenshot") {
        MarketingScreenshotLauncher()
      } else {
        MainTabView()
          .environment(WeatherStore.shared)
          .environment(SevereWeatherStore.shared)
          .environment(ShortTermPrecipStore.shared)
          .environment(FireStore.shared)
          .environment(LightningStore.shared)
          .environment(GrokBriefSafety.shared)
          .environment(subscriptionManager)
          .paywallSheet()
          .tint(.accentColor)
          .task { await subscriptionManager.start() }
      }
      #else
      MainTabView()
        .environment(WeatherStore.shared)
        .environment(SevereWeatherStore.shared)
        .environment(ShortTermPrecipStore.shared)
        .environment(FireStore.shared)
        .environment(LightningStore.shared)
        .environment(GrokBriefSafety.shared)
        .environment(subscriptionManager)
        .paywallSheet()
        .tint(.accentColor)
        .task { await subscriptionManager.start() }
      #endif
    }
  }
}
