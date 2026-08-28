import Foundation

/// Unified access rules for DayCast Free vs Pro.
@MainActor
enum EntitlementChecker {
  static let freeSavedLocationLimit = 1

  static func access(
    subscription: SubscriptionManager,
    hasDeveloperKey: Bool
  ) -> GrokAccessTier {
    GrokAccessRules.tier(
      isPro: subscription.isPro,
      proxyConfigured: GrokProxyConfiguration.isConfigured,
      hasDeveloperKey: hasDeveloperKey
    ) ?? .free
  }

  static func canUseGrokAI(
    subscription: SubscriptionManager,
    hasDeveloperKey: Bool
  ) -> Bool {
    GrokAccessRules.canUseGrokAI(
      isPro: subscription.isPro,
      proxyConfigured: GrokProxyConfiguration.isConfigured,
      hasDeveloperKey: hasDeveloperKey
    )
  }

  /// The morning brief is a scheduled Grok call, so it needs the same access.
  static func canUseMorningBrief(
    subscription: SubscriptionManager,
    hasDeveloperKey: Bool
  ) -> Bool {
    GrokAccessRules.canUseMorningBrief(
      isPro: subscription.isPro,
      proxyConfigured: GrokProxyConfiguration.isConfigured,
      hasDeveloperKey: hasDeveloperKey
    )
  }

  static func canUseRadarFuture(
    subscription: SubscriptionManager,
    hasDeveloperKey: Bool = GrokAPIConfiguration().hasValidDeveloperKey
  ) -> Bool {
    DayCastEntitlements.canUseYearlyExtras(
      isYearly: subscription.isYearly, hasDeveloperKey: hasDeveloperKey)
  }

  static func canUseLiveActivity(
    subscription: SubscriptionManager,
    hasDeveloperKey: Bool = GrokAPIConfiguration().hasValidDeveloperKey
  ) -> Bool {
    DayCastEntitlements.canUseYearlyExtras(
      isYearly: subscription.isYearly, hasDeveloperKey: hasDeveloperKey)
  }

  /// Widget AI one-liner is a yearly extra. Developer key is full access.
  static func canUseWidgetGrokBrief(
    subscription: SubscriptionManager,
    hasDeveloperKey: Bool
  ) -> Bool {
    GrokAccessRules.canUseWidgetGrokBrief(
      isYearly: subscription.isYearly,
      isPro: subscription.isPro,
      proxyConfigured: GrokProxyConfiguration.isConfigured,
      hasDeveloperKey: hasDeveloperKey
    )
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

/// Future radar, Live Activity, and Pro widgets. Not monthly.
enum DayCastEntitlements {
  static func canUseYearlyExtras(isYearly: Bool, hasDeveloperKey: Bool) -> Bool {
    isYearly || hasDeveloperKey
  }

  /// Home Screen / Lock Screen weather widgets. App Group `daycast_is_yearly` only.
  static func canRenderHomeScreenWidgets(isYearlySubscriber: Bool) -> Bool {
    WidgetDataStore.canRenderWeather(isYearlySubscriber: isYearlySubscriber)
  }
}

enum GrokAccessTier: Equatable {
  case free
  case pro
  case developerKey
}
