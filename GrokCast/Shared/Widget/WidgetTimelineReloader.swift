#if !APPLICATION_EXTENSION_API_ONLY
  import Foundation
  import WidgetKit

  /// Coalesces rapid `WidgetCenter.reloadAllTimelines()` calls (e.g. weather + alerts in one refresh).
  /// Main-app only — widget extension reads App Group data; it does not trigger reloads.
  enum WidgetTimelineReloader {
    private static let lock = NSLock()
    private static var scheduled = false
    private static let debounceNanoseconds: UInt64 = 150_000_000

    static func requestReload() {
      lock.lock()
      if scheduled {
        lock.unlock()
        return
      }
      scheduled = true
      lock.unlock()

      Task { @MainActor in
        try? await Task.sleep(nanoseconds: debounceNanoseconds)
        WidgetCenter.shared.reloadAllTimelines()
        lock.lock()
        scheduled = false
        lock.unlock()
      }
    }
  }
#endif
