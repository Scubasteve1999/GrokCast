import BackgroundTasks
import Foundation
import os

/// Registers and handles BGAppRefreshTask for periodic NWS alert polling.
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

  /// Cancels any pending BGAppRefreshTask for NWS alert polling.
  static func cancelAlertRefreshTask() {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
    logSchedule("bg-alerts schedule cancelled")
  }

  /// Submits the next BGAppRefreshTask for NWS alert polling (earliest begin ~15 minutes).
  /// No-ops when alert notifications are disabled (see `WeatherStore.persistedAlertNotificationsEnabled`).
  static func scheduleAlertRefreshTask() {
    guard WeatherStore.persistedAlertNotificationsEnabled else {
      cancelAlertRefreshTask()
      logSchedule("bg-alerts schedule skipped (notifications disabled)")
      return
    }

    // Replace any pending request before submitting (Apple-recommended reschedule pattern).
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)

    let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
    // Earliest allowed refresh ~15 minutes (system may defer to 30+ minutes).
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    do {
      try BGTaskScheduler.shared.submit(request)
      logSchedule("bg-alerts schedule submitted (earliest +15m)")
    } catch let error as BGTaskScheduler.Error {
      switch error {
      case _ where error.code == .unavailable:
        // Expected on Simulator at launch, or when Background App Refresh is disabled system-wide.
        logSchedule(
          "bg-alerts schedule unavailable (normal on Simulator until app backgrounds; enable Background App Refresh on device)"
        )
      case _ where error.code == .tooManyPendingTaskRequests:
        logSchedule("bg-alerts schedule failed: too many pending requests")
      case _ where error.code == .notPermitted:
        logSchedule(
          "bg-alerts schedule failed: not permitted — verify BGTaskSchedulerPermittedIdentifiers in Info.plist"
        )
      default:
        logSchedule("bg-alerts schedule failed: \(error.localizedDescription)")
      }
    } catch {
      logSchedule("bg-alerts schedule failed: \(error.localizedDescription)")
    }
  }

  private static func logSchedule(_ msg: String) {
    // schedule log removed
  }

  private static func handle(_ task: BGAppRefreshTask) {
    scheduleAlertRefreshTask()

    // bg-alerts task started (diag removed for release)
    let start = CFAbsoluteTimeGetCurrent()

    let completed = OSAllocatedUnfairLock(initialState: false)

    let work = Task { @MainActor in
      await WeatherStore.shared.performBackgroundAlertCheck(taskStart: start)
    }

    task.expirationHandler = {
      work.cancel()
      let shouldComplete = completed.withLock { state -> Bool in
        guard !state else { return false }
        state = true
        return true
      }
      if shouldComplete {
        // bg-alerts task expired (diag removed)
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
        // bg-alerts task completed (diag removed)
        task.setTaskCompleted(success: success)
      }
    }
  }
}
