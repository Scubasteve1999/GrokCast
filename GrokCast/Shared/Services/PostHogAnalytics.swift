import Foundation
import PostHog

/// Product analytics via PostHog. Project API key is public (client-side),
/// injected from `Config/Secrets.xcconfig` → Info.plist so it never has to
/// live in source. Empty key = analytics disabled (local counters still work).
enum PostHogAnalytics {
  static let host = "https://us.i.posthog.com"
  static let optOutKey = "spottercast_analytics_opt_out"
  static let uiTestLaunchArgument = "-UITesting"

  static var apiKey: String {
    (Bundle.main.object(forInfoDictionaryKey: "POSTHOG_API_KEY") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  static var isConfigured: Bool {
    !apiKey.isEmpty && !apiKey.hasPrefix("$(")
  }

  /// UserDefaults opt-out. Default is false (analytics on when configured).
  static var isOptedOut: Bool {
    UserDefaults.standard.bool(forKey: optOutKey)
  }

  static func setOptedOut(_ optedOut: Bool) {
    UserDefaults.standard.set(optedOut, forKey: optOutKey)
    guard isConfigured else { return }
    if optedOut {
      PostHogSDK.shared.optOut()
    } else {
      PostHogSDK.shared.optIn()
    }
  }

  /// Call once at launch. No-ops when the key is missing (DEBUG builds without
  /// Secrets.xcconfig, UI tests). Session replay stays off.
  static func configure() {
    guard isConfigured else {
      #if DEBUG
      print("[DayCast] PostHog skipped — set POSTHOG_API_KEY in Config/Secrets.xcconfig")
      #endif
      return
    }
    guard !ProcessInfo.processInfo.arguments.contains(uiTestLaunchArgument) else { return }

    let config = PostHogConfig(projectToken: apiKey, host: host)
    config.sessionReplay = false
    config.captureScreenViews = false
    config.captureElementInteractions = false
    // Keep lifecycle open/background signals; custom funnel events come from Analytics.track.
    config.captureApplicationLifecycleEvents = true
    PostHogSDK.shared.setup(config)
    if isOptedOut {
      PostHogSDK.shared.optOut()
    }
  }

  static func capture(_ event: String, properties: [String: String] = [:]) {
    guard isConfigured, !isOptedOut else { return }
    guard !ProcessInfo.processInfo.arguments.contains(uiTestLaunchArgument) else { return }
    if properties.isEmpty {
      PostHogSDK.shared.capture(event)
    } else {
      PostHogSDK.shared.capture(event, properties: properties)
    }
  }
}
