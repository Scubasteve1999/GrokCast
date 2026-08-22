import Foundation
import OSLog

/// Funnel events for growth measurement.
/// Counts stay on-device in UserDefaults and forward to PostHog when configured.
enum AnalyticsEvent: String, CaseIterable, Sendable {
  case appOpen = "app_open"
  case tabToday = "tab_today"
  case tabForecast = "tab_forecast"
  case tabRadar = "tab_radar"
  case tabAlerts = "tab_alerts"
  case tabGrok = "tab_grok"
  case tabLocations = "tab_locations"
  case tabSettings = "tab_settings"
  case shareStarted = "share_started"
  /// Fired only when the user actually completed a share. `share_started` counts
  /// intent; without this pair there is no way to tell a real share from an
  /// opened-and-dismissed sheet, which is the difference the loop turns on.
  case shareCompleted = "share_completed"
  case paywallView = "paywall_view"
  case subscribeTap = "subscribe_tap"
  case subscribeSuccess = "subscribe_success"
  case restoreSuccess = "restore_success"
  case feedCardTap = "feed_card_tap"
  case fireLayerToggle = "fire_layer_toggle"
  case fireProximityNotify = "fire_proximity_notify"
  case lightningLayerToggle = "lightning_layer_toggle"
  /// One per outbound Grok call, tagged by feature and tier. This is the number
  /// that says whether Pro is priced right.
  case aiRequest = "ai_request"
  case aiLimitReached = "ai_limit_reached"
  case firstOpen = "first_open"

  static func tabEvent(for tab: WeatherStore.Tab) -> AnalyticsEvent {
    switch tab {
    case .today: return .tabToday
    case .forecast: return .tabForecast
    case .radar: return .tabRadar
    case .alerts: return .tabAlerts
    case .grok: return .tabGrok
    case .locations: return .tabLocations
    case .settings: return .tabSettings
    }
  }
}

enum Analytics {
  private static let prefix = "daycast_analytics_"
  private static let logger = Logger(subsystem: "com.scubasteve1999.DayCast", category: "Analytics")

  static func track(_ event: AnalyticsEvent, parameters: [String: String] = [:]) {
    guard !ProcessInfo.processInfo.arguments.contains(PostHogAnalytics.uiTestLaunchArgument) else {
      return
    }

    let defaults = UserDefaults.standard
    let key = countKey(for: event)
    defaults.set(defaults.integer(forKey: key) + 1, forKey: key)

    PostHogAnalytics.capture(event.rawValue, properties: parameters)

    #if DEBUG
    if parameters.isEmpty {
      logger.debug("event=\(event.rawValue, privacy: .public) count=\(defaults.integer(forKey: key))")
    } else {
      let joined = parameters
        .map { "\($0.key)=\($0.value)" }
        .sorted()
        .joined(separator: " ")
      logger.debug(
        "event=\(event.rawValue, privacy: .public) \(joined, privacy: .public) count=\(defaults.integer(forKey: key))"
      )
    }
    #endif
  }

  static func count(for event: AnalyticsEvent) -> Int {
    UserDefaults.standard.integer(forKey: countKey(for: event))
  }

  private static let firstOpenKey = prefix + "first_open_recorded"

  /// Fires `first_open` once per install, with the version it landed on.
  ///
  /// Install *source* is deliberately not collected here — that lives in App
  /// Store Connect → Analytics → Acquisition, which already breaks installs down
  /// by search, browse, referrer, and campaign token without an SDK. This event
  /// exists to date the cohort, not to identify anyone.
  static func trackFirstOpenIfNeeded() {
    let defaults = UserDefaults.standard
    guard !defaults.bool(forKey: firstOpenKey) else { return }
    defaults.set(true, forKey: firstOpenKey)

    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    track(.firstOpen, parameters: ["version": version ?? "unknown"])
  }

  static func resetAllCounts() {
    let defaults = UserDefaults.standard
    for event in AnalyticsEvent.allCases {
      defaults.removeObject(forKey: countKey(for: event))
    }
  }

  private static func countKey(for event: AnalyticsEvent) -> String {
    prefix + event.rawValue
  }
}
