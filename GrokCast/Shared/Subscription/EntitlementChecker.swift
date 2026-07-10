import Foundation

/// Unified access rules for GrokCast Free vs Pro.
@MainActor
enum EntitlementChecker {
  static let freeSavedLocationLimit = 1

  static func access(
    subscription: SubscriptionManager,
    hasDeveloperKey: Bool
  ) -> GrokAccessTier {
    // Keep aligned with canUseGrokAI: Pro alone is not enough for Grok until the
    // hosted proxy is configured.
    if hasDeveloperKey { return .developerKey }
    if subscription.isPro, GrokProxyConfiguration.isConfigured { return .pro }
    return .free
  }

  static func canUseGrokAI(
    subscription: SubscriptionManager,
    hasDeveloperKey: Bool
  ) -> Bool {
    // BYOK / embedded key always works against api.x.ai.
    if hasDeveloperKey { return true }
    // Pro-only (no local key) requires a live hosted proxy; otherwise the app would
    // claim access and then fail every request against an undeployed host.
    if subscription.isPro, GrokProxyConfiguration.isConfigured { return true }
    return false
  }

  static func canUseRadarFuture(
    subscription: SubscriptionManager
  ) -> Bool {
    subscription.isPro
  }

  static func canUseLiveActivity(
    subscription: SubscriptionManager
  ) -> Bool {
    subscription.isPro
  }

  static func canUseWidgetGrokBrief(
    subscription: SubscriptionManager
  ) -> Bool {
    subscription.isPro
  }

  static func maxSavedLocations(
    subscription: SubscriptionManager
  ) -> Int? {
    subscription.isPro ? nil : freeSavedLocationLimit
  }

  static func canAddLocation(
    currentCount: Int,
    subscription: SubscriptionManager
  ) -> Bool {
    guard let limit = maxSavedLocations(subscription: subscription) else { return true }
    return currentCount < limit
  }
}

enum GrokAccessTier: Equatable {
  case free
  case pro
  case developerKey
}
