import SwiftUI

struct MainTabView: View {
  @Environment(WeatherStore.self) private var store

  var body: some View {
    TabView(selection: Bindable(store).selectedTab) {
      TodayView()
        .tabItem {
          Label("Today", systemImage: "sun.max.fill")
        }
        .tag(WeatherStore.Tab.today)

      ForecastView()
        .tabItem {
          Label("Forecast", systemImage: "calendar")
        }
        .tag(WeatherStore.Tab.forecast)

      RadarView()
        .tabItem {
          Label("Radar", systemImage: "map.fill")
        }
        .tag(WeatherStore.Tab.radar)

      AlertsView()
        .tabItem {
          Label("Alerts", systemImage: WeatherStore.Tab.alerts.icon)
        }
        .tag(WeatherStore.Tab.alerts)

      GrokAIView()
        .environmentObject(store)
        .tabItem {
          Label("AI", systemImage: "sparkles")
        }
        .tag(WeatherStore.Tab.grok)

      LocationsView()
        .tabItem {
          Label("Locations", systemImage: "mappin.and.ellipse")
        }
        .tag(WeatherStore.Tab.locations)

      SettingsView()
        .tabItem {
          Label("Settings", systemImage: "gearshape")
        }
        .tag(WeatherStore.Tab.settings)
    }
    // Intentionally TabView + sidebarAdaptable (not NavigationSplitView): split navigation
    // would duplicate chrome and risk regressing the tab-based model on iPad.
    .tabViewStyle(.sidebarAdaptable)
    .onOpenURL { url in
      handleDeepLink(url)
    }
    .onReceive(NotificationCenter.default.publisher(for: .grokCastOpenAlertsTab)) { notification in
      if let url = notification.userInfo?["url"] as? URL {
        handleDeepLink(url)
      } else {
        store.selectedTab = .alerts
      }
    }
    .task {
      await store.performInitialLoadIfNeeded()
      // Fallback schedule after initial load — didFinishLaunching often gets .unavailable while foregrounded.
      await store.scheduleBackgroundAlertRefreshIfEnabled()
    }
  }

  private func handleDeepLink(_ url: URL) {
    guard url.scheme == GrokCastDeepLinks.scheme else { return }
    switch url.host {
    case GrokCastDeepLinks.todayHost:
      store.selectedTab = .today
    case GrokCastDeepLinks.alertsHost:
      store.selectedTab = .alerts
    default:
      break
    }
  }
}

#Preview {
  MainTabView()
    .environment(WeatherStore.shared)
    .environmentObject(WeatherStore.shared)
}
