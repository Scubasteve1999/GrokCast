import Foundation

/// Who may call Grok, expressed as pure functions over plain flags.
///
/// `EntitlementChecker` delegates here so the rules can be unit tested without
/// StoreKit — `SubscriptionManager` is a singleton whose state only StoreKit can
/// set, which is why the logic doesn't live there.
enum GrokAccessRules {

  /// AI runs on our xAI key, so it requires Pro *and* a deployed proxy to meter it.
  /// A user-supplied Keychain key always works: they pay for it, not us.
  static func canUseGrokAI(isPro: Bool, proxyConfigured: Bool, hasDeveloperKey: Bool) -> Bool {
    if hasDeveloperKey { return true }
    return isPro && proxyConfigured
  }

  /// Same rule as chat — the widget's one-liner is a Grok call like any other.
  static func canUseWidgetGrokBrief(
    isPro: Bool,
    proxyConfigured: Bool,
    hasDeveloperKey: Bool
  ) -> Bool {
    // The widget surface itself is a Pro feature, so Pro is required even when the
    // user brought their own key.
    guard isPro else { return false }
    return canUseGrokAI(
      isPro: isPro, proxyConfigured: proxyConfigured, hasDeveloperKey: hasDeveloperKey)
  }

  /// The morning brief is a scheduled Grok call, so it follows the chat rule.
  static func canUseMorningBrief(
    isPro: Bool,
    proxyConfigured: Bool,
    hasDeveloperKey: Bool
  ) -> Bool {
    canUseGrokAI(isPro: isPro, proxyConfigured: proxyConfigured, hasDeveloperKey: hasDeveloperKey)
  }

  /// Which credential a call should travel on. `nil` means "no access".
  static func tier(isPro: Bool, proxyConfigured: Bool, hasDeveloperKey: Bool) -> GrokAccessTier? {
    // Pro goes through the proxy even when a Keychain key exists, so the daily
    // counter stays meaningful for the people we're metering.
    if isPro, proxyConfigured { return .pro }
    if hasDeveloperKey { return .developerKey }
    return nil
  }

  /// More hub subtitle. Pro + proxy (or a user key) is enough — do not send
  /// people to Settings for a key they no longer need.
  static func moreHubGrokSubtitle(canUseAI: Bool) -> String {
    canUseAI
      ? "Ask about your weather. Photo check when you want."
      : "Included with DayCast Pro"
  }

  /// Locked Alerts summary line. Mentions Pro hosted AI and the BYOK path.
  static let lockedAlertsSummaryCopy =
    "DayCast Pro includes AI alert summaries — or add an xAI key in Settings."
}
