import SwiftUI

struct MainTabView: View {
  @Environment(WeatherStore.self) private var store
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Namespace private var tabBarNamespace
  @State private var suppressTabBar = false

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
        .tabItem {
          Label("Storm Spotter", systemImage: "sparkles")
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
    .toolbar(.hidden, for: .tabBar)
    .onPreferenceChange(TabBarSuppressionPreferenceKey.self) { suppressTabBar = $0 }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      Group {
        if horizontalSizeClass == .compact && !suppressTabBar {
          CompactTabBar(selection: Bindable(store).selectedTab, namespace: tabBarNamespace)
        } else {
          EmptyView().frame(height: 0)
        }
      }
    }
    .onOpenURL { url in
      handleDeepLink(url)
    }
    .onReceive(NotificationCenter.default.publisher(for: .dayCastDeepLink)) { notification in
      if let url = notification.userInfo?["url"] as? URL {
        handleDeepLink(url)
      }
    }
    .task {
      await store.performInitialLoadIfNeeded()
      Task { await store.scheduleBackgroundAlertRefreshIfEnabled() }
    }
    .appReviewPrompting()
    .onAppear {
      Analytics.trackFirstOpenIfNeeded()
      Analytics.track(.appOpen)
      Analytics.track(AnalyticsEvent.tabEvent(for: store.selectedTab))
    }
    .onChange(of: store.selectedTab) { _, tab in
      Analytics.track(AnalyticsEvent.tabEvent(for: tab))
    }
  }

  private func handleDeepLink(_ url: URL) {
    let scheme = url.scheme?.lowercased()
    guard scheme == DayCastDeepLinks.scheme else { return }
    switch url.host {
    case DayCastDeepLinks.todayHost:
      store.selectedTab = .today
    case DayCastDeepLinks.alertsHost:
      store.selectedTab = .alerts
    case DayCastDeepLinks.forecastHost:
      store.selectedTab = .forecast
    case DayCastDeepLinks.radarHost:
      store.selectedTab = .radar
    case DayCastDeepLinks.grokHost:
      store.selectedTab = .grok
    default:
      break
    }
  }
}

#Preview {
  MainTabView()
    .environment(WeatherStore.shared)
    .environment(SevereWeatherStore.shared)
    .environment(ShortTermPrecipStore.shared)
    .environment(FireStore.shared)
}
