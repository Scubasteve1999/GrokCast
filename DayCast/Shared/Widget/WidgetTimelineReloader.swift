#if !APPLICATION_EXTENSION_API_ONLY
  import Foundation
  import WidgetKit

  extension NSLocking {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
      lock()
      defer { unlock() }
      return try body()
    }
  }

  /// Coalesces rapid `WidgetCenter.reloadAllTimelines()` calls (e.g. weather + alerts in one refresh).
  /// Main-app only — widget extension reads App Group data; it does not trigger reloads.
  enum WidgetTimelineReloader {
    private static let lock = NSLock()
    private static var scheduled = false
    private static let debounceNanoseconds: UInt64 = 150_000_000

    static func requestReload() {
      lock.withLock {
        if scheduled {
          return
        }
        scheduled = true
      }

      Task { @MainActor in
        try? await Task.sleep(nanoseconds: debounceNanoseconds)
        WidgetCenter.shared.reloadAllTimelines()
        lock.withLock {
          scheduled = false
        }
      }
    }
  }
#endif
