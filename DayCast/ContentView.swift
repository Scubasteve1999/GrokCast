import SwiftUI

struct MainTabView: View {
  @Environment(WeatherStore.self) private var store
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Namespace private var tabBarNamespace
  @State private var suppressTabBar = false
  @State private var showMoreHub = false
  @State private var moreHubDetent: PresentationDetent = .large
  @State private var lastMoreDestination: WeatherStore.Tab = .grok

  var body: some View {
    tabRoot
      .onPreferenceChange(TabBarSuppressionPreferenceKey.self) { suppressTabBar = $0 }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        Group {
          if horizontalSizeClass == .compact && !suppressTabBar {
            CompactTabBar(
              selection: Bindable(store).selectedTab,
              showMoreHub: $showMoreHub,
              namespace: tabBarNamespace
            )
          } else {
            EmptyView().frame(height: 0)
          }
        }
      }
      .sheet(isPresented: $showMoreHub) {
        MoreHubSheet()
          .presentationDetents([.medium, .large], selection: $moreHubDetent)
      }
      .onChange(of: showMoreHub) { _, isOpen in
        if isOpen { moreHubDetent = .large }
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
      .onChange(of: store.locationService.authorizationStatus) { _, _ in
        store.noteAuthorizationMayNeedDeviceLocation()
        Task { await store.handleLocationAuthorizationChange() }
      }
      .appReviewPrompting()
      .onAppear {
        Analytics.trackFirstOpenIfNeeded()
        Analytics.track(.appOpen)
        Analytics.track(AnalyticsEvent.tabEvent(for: store.selectedTab))
      }
      .onChange(of: store.selectedTab) { _, tab in
        Analytics.track(AnalyticsEvent.tabEvent(for: tab))
        if WeatherStore.Tab.moreHub.contains(tab) {
          lastMoreDestination = tab
        }
      }
  }

  @ViewBuilder
  private var tabRoot: some View {
    // sidebarAdaptable is iPad-only. On iPhone it still draws the system tab
    // bar, which stacks under CompactTabBar (ghost labels + map showing through).
    // Compact also cannot register 7 tabItems: UIKit then wraps the overflow
    // in its own More stack, which leaked a "More" back button onto Locations.
    if horizontalSizeClass == .regular {
      regularTabView.tabViewStyle(.sidebarAdaptable)
    } else {
      compactTabView
        .background { SystemTabBarHider() }
    }
  }

  private var compactTabSelection: Binding<CompactTab> {
    Binding(
      get: { CompactTab.primary(for: store.selectedTab) },
      set: { primary in
        if let tab = primary.weatherTab {
          store.selectedTab = tab
        }
      }
    )
  }

  private var compactTabView: some View {
    TabView(selection: compactTabSelection) {
      TodayView()
        .hidesSystemTabBar()
        .tabItem { Label("Today", systemImage: "sun.max.fill") }
        .tag(CompactTab.today)

      ForecastView()
        .hidesSystemTabBar()
        .tabItem { Label("Forecast", systemImage: "calendar") }
        .tag(CompactTab.forecast)

      RadarView()
        .hidesSystemTabBar()
        .tabItem { Label("Radar", systemImage: "map.fill") }
        .tag(CompactTab.radar)

      AlertsView()
        .hidesSystemTabBar()
        .tabItem {
          Label(
            "Alerts",
            systemImage: AlertsHonesty.tabSymbolName(
              nwsAlertCount: store.displayableActiveAlerts.count)
          )
        }
        .tag(CompactTab.alerts)

      moreHubPage
        .hidesSystemTabBar()
        .tabItem { Label("More", systemImage: "ellipsis") }
        .tag(CompactTab.more)
    }
  }

  private var regularTabView: some View {
    TabView(selection: Bindable(store).selectedTab) {
      TodayView()
        .hidesSystemTabBar()
        .tabItem { Label("Today", systemImage: "sun.max.fill") }
        .tag(WeatherStore.Tab.today)

      ForecastView()
        .hidesSystemTabBar()
        .tabItem { Label("Forecast", systemImage: "calendar") }
        .tag(WeatherStore.Tab.forecast)

      RadarView()
        .hidesSystemTabBar()
        .tabItem { Label("Radar", systemImage: "map.fill") }
        .tag(WeatherStore.Tab.radar)

      AlertsView()
        .hidesSystemTabBar()
        .tabItem {
          Label(
            "Alerts",
            systemImage: AlertsHonesty.tabSymbolName(
              nwsAlertCount: store.displayableActiveAlerts.count)
          )
        }
        .tag(WeatherStore.Tab.alerts)

      GrokAIView()
        .hidesSystemTabBar()
        .tabItem { Label("Storm Spotter", systemImage: "sparkles") }
        .tag(WeatherStore.Tab.grok)

      LocationsView()
        .hidesSystemTabBar()
        .tabItem { Label("Locations", systemImage: "mappin.and.ellipse") }
        .tag(WeatherStore.Tab.locations)

      SettingsView()
        .hidesSystemTabBar()
        .tabItem { Label("Settings", systemImage: "gearshape") }
        .tag(WeatherStore.Tab.settings)
    }
  }

  private var morePageTab: WeatherStore.Tab {
    if WeatherStore.Tab.moreHub.contains(store.selectedTab) {
      return store.selectedTab
    }
    return lastMoreDestination
  }

  @ViewBuilder
  private var moreHubPage: some View {
    switch morePageTab {
    case .locations:
      LocationsView()
    case .settings:
      SettingsView()
    default:
      GrokAIView()
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
    .environment(LocalBriefingStore.shared)
    .environment(ShortTermPrecipStore.shared)
    .environment(FireStore.shared)
    .environment(LightningStore.shared)
    .environment(GrokBriefSafety.shared)
}
