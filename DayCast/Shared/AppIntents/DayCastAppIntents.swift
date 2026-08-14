import AppIntents
import Foundation

/// Stash for Siri/Shortcuts → Grok tab. Survives cold launch via App Group
/// (standard defaults if the group is unavailable, e.g. unit tests).
enum AskGrokPendingPrompt {
  enum Action: Equatable {
    case submit(String)
    case focusInput
  }

  static let didChange = Notification.Name("daycast.askGrokPending")

  private static let kindKey = "daycast_ask_grok_kind"
  private static let questionKey = "daycast_ask_grok_question"

  private static var defaults: UserDefaults {
    WidgetAppGroup.userDefaults ?? .standard
  }

  static func set(_ action: Action) {
    switch action {
    case .submit(let question):
      defaults.set("submit", forKey: kindKey)
      defaults.set(question, forKey: questionKey)
    case .focusInput:
      defaults.set("focus", forKey: kindKey)
      defaults.removeObject(forKey: questionKey)
    }
  }

  /// Returns and clears the pending action, if any.
  static func take() -> Action? {
    guard let kind = defaults.string(forKey: kindKey) else { return nil }
    defaults.removeObject(forKey: kindKey)
    let question = defaults.string(forKey: questionKey)
    defaults.removeObject(forKey: questionKey)
    switch kind {
    case "submit":
      let trimmed = question?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      return trimmed.isEmpty ? .focusInput : .submit(trimmed)
    case "focus":
      return .focusInput
    default:
      return nil
    }
  }

  static func notify() {
    NotificationCenter.default.post(name: didChange, object: nil)
  }
}

struct AskGrokIntent: AppIntent {
  static var title: LocalizedStringResource = "Ask Grok"
  static var description = IntentDescription(
    "Open DayCast chat with Grok. Current weather is attached automatically.")
  static var openAppWhenRun = true

  @Parameter(title: "Question")
  var question: String?

  static var parameterSummary: some ParameterSummary {
    Summary("Ask Grok \(\.$question)")
  }

  func perform() async throws -> some IntentResult {
    let trimmed = question?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if trimmed.isEmpty {
      AskGrokPendingPrompt.set(.focusInput)
    } else {
      AskGrokPendingPrompt.set(.submit(trimmed))
    }
    await MainActor.run {
      WeatherStore.shared.selectedTab = .grok
    }
    AskGrokPendingPrompt.notify()
    return .result()
  }
}

struct DayCastScoreIntent: AppIntent {
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

struct DayCastMinutecastIntent: AppIntent {
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

struct DayCastShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AskGrokIntent(),
      phrases: [
        "Ask Grok in \(.applicationName)",
        "Ask \(.applicationName) about the weather",
        "Talk to Grok in \(.applicationName)",
      ],
      shortTitle: "Ask Grok",
      systemImageName: "sparkles"
    )
    AppShortcut(
      intent: DayCastScoreIntent(),
      phrases: [
        "What's my DayCast score in \(.applicationName)?",
        "Go outside score in \(.applicationName)",
        "DayCast score in \(.applicationName)",
      ],
      shortTitle: "DayCast Score",
      systemImageName: "figure.walk"
    )
    AppShortcut(
      intent: DayCastMinutecastIntent(),
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
