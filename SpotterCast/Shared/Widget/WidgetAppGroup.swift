import Foundation

/// Shared App Group identifier for main app ↔ widget extension data exchange.
enum WidgetAppGroup {
  static let identifier = "group.com.grokcast.GrokCast"

  private static let lock = NSLock()
  private static var cachedDefaults: UserDefaults?
  private static var availabilityResolved = false
  private static var isContainerAvailable = false

  /// Whether the App Group container is available (entitlements + signing).
  static var isAvailable: Bool {
    _ = userDefaults
    return isContainerAvailable
  }

  /// App Group `UserDefaults`, or `nil` when the container is unavailable.
  /// Resolves once and caches to avoid repeated cfprefsd detach noise on Simulator.
  static var userDefaults: UserDefaults? {
    lock.lock()
    defer { lock.unlock() }

    if availabilityResolved {
      return isContainerAvailable ? cachedDefaults : nil
    }
    availabilityResolved = true

    // Verify container exists before opening the suite (reduces CoreFoundation prefs errors).
    guard
      FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
    else {
      isContainerAvailable = false
      #if DEBUG
        print(
          "⚠️ [WidgetAppGroup] container unavailable for \(identifier) — using standard UserDefaults fallback"
        )
      #endif
      return nil
    }

    guard let defaults = UserDefaults(suiteName: identifier) else {
      isContainerAvailable = false
      return nil
    }

    cachedDefaults = defaults
    isContainerAvailable = true
    return defaults
  }
}
