import AppIntents
import Foundation

struct GrokCastScoreIntent: AppIntent {
  static var title: LocalizedStringResource = "SpotterCast Score"
  static var description = IntentDescription("Get your Go Outside score from SpotterCast.")

  func perform() async throws -> some IntentResult & ReturnsValue<String> {
    guard let snapshot = WidgetDataStore.loadSnapshot(for: nil) else {
      return .result(value: "Open SpotterCast and refresh weather to get your score.")
    }
    if let score = snapshot.grokCastScore {
      let label = snapshot.grokCastScoreLabel ?? "Score"
      return .result(value: "\(snapshot.location.name): SpotterCast score \(score) — \(label).")
    }
    return .result(
      value:
        "\(snapshot.location.name): \(Int(snapshot.currentTemp.rounded()))° — \(snapshot.conditionText)."
    )
  }
}

struct GrokCastMinutecastIntent: AppIntent {
  static var title: LocalizedStringResource = "Minutecast"
  static var description = IntentDescription("Get the next-hour precipitation outlook from SpotterCast.")

  func perform() async throws -> some IntentResult & ReturnsValue<String> {
    guard let snapshot = WidgetDataStore.loadSnapshot(for: nil) else {
      return .result(value: "Open SpotterCast to load Minutecast.")
    }
    if let message = snapshot.minutecastMessage {
      return .result(value: "\(snapshot.location.name): \(message)")
    }
    return .result(value: "\(snapshot.location.name): No Minutecast data yet. Refresh in SpotterCast.")
  }
}

struct GrokCastShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: GrokCastScoreIntent(),
      phrases: [
        "What's my SpotterCast score in \(.applicationName)?",
        "Go outside score in \(.applicationName)",
        "SpotterCast score in \(.applicationName)",
      ],
      shortTitle: "SpotterCast Score",
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
