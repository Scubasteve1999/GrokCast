import BackgroundTasks
import Foundation

final class BackgroundAlertRefreshService {
  static let shared = BackgroundAlertRefreshService()
  
  private let taskIdentifier = "com.grokcast.alertRefresh"
  
  private init() {}
  
  func registerBackgroundTasks() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
      self.handleAlertRefresh(task: task as! BGAppRefreshTask)
    }
  }
  
  func scheduleNextRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
    
    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      print("Could not schedule alert refresh: \(error)")
    }
  }
  
  private func handleAlertRefresh(task: BGAppRefreshTask) {
    scheduleNextRefresh()
    
    Task {
      await WeatherStore.shared.refreshAlerts()
      task.setTaskCompleted(success: true)
    }
  }
}
