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
  case paywallView = "paywall_view"
  case subscribeTap = "subscribe_tap"
  case subscribeSuccess = "subscribe_success"
  case restoreSuccess = "restore_success"
  case feedCardTap = "feed_card_tap"
  case fireLayerToggle = "fire_layer_toggle"
  case fireProximityNotify = "fire_proximity_notify"

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
  private static let prefix = "spottercast_analytics_"
  private static let logger = Logger(subsystem: "com.scubasteve1999.GrokCast", category: "Analytics")

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
