import AppIntents
import Foundation

struct GrokCastScoreIntent: AppIntent {
  static var title: LocalizedStringResource = "DayCast Score"
  static var description = IntentDescription("Get your Go Outside score from DayCast.")

  func perform() async throws -> some IntentResult & ReturnsValue<String> {
    guard let snapshot = WidgetDataStore.loadSnapshot(for: nil) else {
      return .result(value: "Open DayCast and refresh weather to get your score.")
    }
    if let score = snapshot.grokCastScore {
      let label = snapshot.grokCastScoreLabel ?? "Score"
      return .result(value: "\(snapshot.location.name): DayCast score \(score) — \(label).")
    }
    return .result(
      value:
        "\(snapshot.location.name): \(Int(snapshot.currentTemp.rounded()))° — \(snapshot.conditionText)."
    )
  }
}

struct GrokCastMinutecastIntent: AppIntent {
  static var title: LocalizedStringResource = "Minutecast"
  static var description = IntentDescription("Get the next-hour precipitation outlook from DayCast.")

  func perform() async throws -> some IntentResult & ReturnsValue<String> {
    guard let snapshot = WidgetDataStore.loadSnapshot(for: nil) else {
      return .result(value: "Open DayCast to load Minutecast.")
    }
    if let message = snapshot.minutecastMessage {
      return .result(value: "\(snapshot.location.name): \(message)")
    }
    return .result(value: "\(snapshot.location.name): No Minutecast data yet. Refresh in DayCast.")
  }
}

struct GrokCastShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: GrokCastScoreIntent(),
      phrases: [
        "What's my DayCast score in \(.applicationName)?",
        "Go outside score in \(.applicationName)",
        "DayCast score in \(.applicationName)",
      ],
      shortTitle: "DayCast Score",
      systemImageName: "figure.walk"
    )
    AppShortcut(
      intent: GrokCastMinutecastIntent(),
      phrases: [
        "When is rain in \(.applicationName)?",
        "Minutecast in \(.applicationName)",
        "Will it rain soon in \(.applicationName)?",
      ],
      shortTitle: "Minutecast",
      systemImageName: "cloud.rain.fill"
    )
  }
}
