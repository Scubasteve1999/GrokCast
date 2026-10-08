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

  /// Yearly only. A personal xAI key never unlocks Future radar.
  static func canUseRadarFuture(subscription: SubscriptionManager) -> Bool {
    DayCastEntitlements.canUseYearlyExtras(isYearly: subscription.isYearly)
  }

  /// Any Pro plan, Monthly or Yearly. A personal xAI key never unlocks Live Activity.
  static func canUseLiveActivity(subscription: SubscriptionManager) -> Bool {
    DayCastEntitlements.canUseProSurfaces(isPro: subscription.isPro)
  }

  /// Widget AI one-liner needs Pro. A personal key can only power the AI text.
  static func canUseWidgetGrokBrief(
    subscription: SubscriptionManager,
    hasDeveloperKey: Bool
  ) -> Bool {
    GrokAccessRules.canUseWidgetGrokBrief(
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

/// Purchase-only surfaces: a personal xAI key powers AI requests, never these.
enum DayCastEntitlements {
  /// Home Screen / Lock Screen widgets and Live Activity. Monthly and Yearly.
  static func canUseProSurfaces(isPro: Bool) -> Bool {
    isPro
  }

  /// 12-hr Future radar. Yearly only.
  static func canUseYearlyExtras(isYearly: Bool) -> Bool {
    isYearly
  }
}

enum GrokAccessTier: Equatable {
  case free
  case pro
  case developerKey
}
