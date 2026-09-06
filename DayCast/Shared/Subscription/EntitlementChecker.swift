import Foundation

/// Unified access rules for DayCast Free vs Pro.
@MainActor
enum EntitlementChecker {
  /// Free: one named saved city. GPS Near Me (`isCurrent`) does not count.
  nonisolated static let freeSavedLocationLimit = 1

  /// Named saved cities only. GPS pins are Near Me, not a free slot.
  nonisolated static func namedSavedCount(in locations: [SavedLocation]) -> Int {
    locations.lazy.filter { !$0.isCurrent }.count
  }

  /// Same as `namedSavedCount` — the value `canAddLocation` compares to the free limit.
  nonisolated static func countTowardFreeLocationLimit(_ locations: [SavedLocation]) -> Int {
    namedSavedCount(in: locations)
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

  /// Free may add a named city when named count is below the limit.
  /// Pass `namedSavedCount` — never raw `savedLocations.count` (that counted GPS).
  nonisolated static func canAddLocation(namedCount: Int, isPro: Bool) -> Bool {
    isPro || namedCount < freeSavedLocationLimit
  }

  nonisolated static func canAddLocation(locations: [SavedLocation], isPro: Bool) -> Bool {
    canAddLocation(namedCount: namedSavedCount(in: locations), isPro: isPro)
  }

  static func canAddLocation(
    locations: [SavedLocation],
    subscription: SubscriptionManager
  ) -> Bool {
    canAddLocation(locations: locations, isPro: subscription.isPro)
  }
}

/// Future radar, Live Activity, and Pro widgets. Not monthly.
enum DayCastEntitlements {
  static func canUseYearlyExtras(isYearly: Bool, hasDeveloperKey: Bool) -> Bool {
    isYearly || hasDeveloperKey
  }
}

enum GrokAccessTier: Equatable {
  case free
  case pro
  case developerKey
}
