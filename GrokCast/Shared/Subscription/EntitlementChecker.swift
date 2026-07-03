import Foundation

/// Unified access rules for GrokCast Free vs Pro.
@MainActor
enum EntitlementChecker {
  static let freeSavedLocationLimit = 1

  static func access(
    subscription: SubscriptionManager,
    hasDeveloperKey: Bool
  ) -> GrokAccessTier {
    if subscription.isPro { return .pro }
    if hasDeveloperKey { return .developerKey }
    return .free
  }

  static func canUseGrokAI(
    subscription: SubscriptionManager,
    hasDeveloperKey: Bool
  ) -> Bool {
    switch access(subscription: subscription, hasDeveloperKey: hasDeveloperKey) {
    case .pro, .developerKey: true
    case .free: false
    }
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
