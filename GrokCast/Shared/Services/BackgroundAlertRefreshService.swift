import BackgroundTasks
import Foundation
import os

/// Registers and handles BGAppRefreshTask for NWS alerts + Live Activity weather sync.
///
/// Scheduling uses a 15-minute minimum `earliestBeginDate`; iOS may defer execution to 30+ minutes
/// depending on battery, usage patterns, and Background App Refresh settings.
enum BackgroundAlertRefreshService {
  static let taskIdentifier = "com.grokcast.alerts.refresh"

  static func register() {
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: taskIdentifier,
      using: nil
    ) { task in
      guard let refreshTask = task as? BGAppRefreshTask else {
        task.setTaskCompleted(success: false)
        return
      }
      handle(refreshTask)
    }
  }

  /// Cancels any pending BGAppRefreshTask.
  static func cancelAlertRefreshTask() {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
  }

  /// Submits the next BGAppRefresh when alert notifications and/or Live Activity need background sync.
  static func scheduleAlertRefreshTask() {
    let needsAlerts = WeatherStore.persistedAlertNotificationsEnabled
    let needsLiveActivity = WeatherStore.persistedLiveActivityEnabled
    guard needsAlerts || needsLiveActivity else {
      cancelAlertRefreshTask()
      return
    }

    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)

    let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      // Expected on Simulator / when Background App Refresh is disabled.
    }
  }

  private static func handle(_ task: BGAppRefreshTask) {
    scheduleAlertRefreshTask()

    let start = CFAbsoluteTimeGetCurrent()
    let completed = OSAllocatedUnfairLock(initialState: false)

    let work = Task { @MainActor in
      await WeatherStore.shared.performBackgroundRefresh(taskStart: start)
    }

    task.expirationHandler = {
      work.cancel()
      let shouldComplete = completed.withLock { state -> Bool in
        guard !state else { return false }
        state = true
        return true
      }
      if shouldComplete {
        task.setTaskCompleted(success: false)
      }
    }

    Task {
      let success = await work.value
      let shouldComplete = completed.withLock { state -> Bool in
        guard !state else { return false }
        state = true
        return true
      }
      if shouldComplete {
        task.setTaskCompleted(success: success)
      }
    }
  }
}
