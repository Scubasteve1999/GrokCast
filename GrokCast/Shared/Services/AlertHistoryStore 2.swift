import Foundation

@MainActor
final class AlertHistoryStore {
  static let shared = AlertHistoryStore()
  
  private let userDefaultsKey = "com.grokcast.alertHistory"
  private let maxHistoryDays = 30
  
  private init() {}
  
  func save(_ alerts: [NWSAlert]) {
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(alerts) {
      UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
    }
  }
  
  func load() -> [NWSAlert] {
    guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
      return []
    }
    let decoder = JSONDecoder()
    return (try? decoder.decode([NWSAlert].self, from: data)) ?? []
  }
  
  func add(_ alert: NWSAlert) {
    var history = load()
    if !history.contains(where: { $0.id == alert.id }) {
      history.append(alert)
      cleanupOldAlerts(&history)
      save(history)
    }
  }
  
  func addMultiple(_ alerts: [NWSAlert]) {
    var history = load()
    for alert in alerts {
      if !history.contains(where: { $0.id == alert.id }) {
        history.append(alert)
      }
    }
    cleanupOldAlerts(&history)
    save(history)
  }
  
  func clear() {
    UserDefaults.standard.removeObject(forKey: userDefaultsKey)
  }
  
  private func cleanupOldAlerts(_ history: inout [NWSAlert]) {
    let cutoff = Date().addingTimeInterval(-Double(maxHistoryDays) * 86400)
    history.removeAll { alert in
      if let firstSeen = alert.firstSeen, firstSeen < cutoff {
        return true
      }
      return false
    }
  }
}
