import Foundation

/// Client-side screen for Grok Today's Take text (App Review Guideline 4.7 filter).
enum GrokContentFilter {
  enum Verdict: Equatable, Sendable {
    case allowed
    case blocked(Reason)
  }

  enum Reason: String, Equatable, Sendable {
    case empty
    case tooLong
    case sexual
    case hate
    case selfHarm
    case graphicViolence
    case promptLeak
    case harmfulAdvice
  }

  static let maxCharacterCount = 1_600

  static func screen(_ text: String) -> Verdict {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return .blocked(.empty) }
    if trimmed.count > maxCharacterCount { return .blocked(.tooLong) }
    if containsAnyPhrase(trimmed, phrases: promptLeakPhrases) { return .blocked(.promptLeak) }
    if containsAnyPhrase(trimmed, phrases: harmfulAdvicePhrases) {
      return .blocked(.harmfulAdvice)
    }
    if containsAnyWord(trimmed, words: sexualWords) { return .blocked(.sexual) }
    if containsAnyWord(trimmed, words: hateWords) { return .blocked(.hate) }
    if containsAnyPhrase(trimmed, phrases: selfHarmPhrases)
      || containsAnyWord(trimmed, words: selfHarmWords)
    {
      return .blocked(.selfHarm)
    }
    if containsAnyWord(trimmed, words: graphicViolenceWords) {
      return .blocked(.graphicViolence)
    }
    return .allowed
  }

  static func acceptedText(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard case .allowed = screen(trimmed) else { return nil }
    return trimmed
  }
}

/// Screens a Grok brief and falls back to the deterministic local take when needed.
enum GrokBriefText {
  static func finalize(
    raw: String,
    weather: DayCastWeather,
    unit: TemperatureUnit,
    locationName: String,
    activeAlerts: [String]
  ) -> String? {
    if let accepted = GrokContentFilter.acceptedText(raw) {
      return accepted
    }
    return GrokContentFilter.acceptedText(
      LocalWeatherBrief.make(
        weather: weather,
        unit: unit,
        locationName: locationName,
        activeAlerts: activeAlerts
      )
    )
  }
}

extension GrokContentFilter {
  private static let promptLeakPhrases = [
    "ignore previous instructions",
    "ignore prior instructions",
    "ignore all previous",
    "system prompt",
    "developer mode",
    "you are no longer",
  ]

  private static let harmfulAdvicePhrases = [
    "ignore the warning",
    "ignore the watch",
    "ignore the alert",
    "ignore official",
    "ignore nws",
    "don't evacuate",
    "do not evacuate",
    "don't take cover",
    "do not take cover",
    "don't shelter",
    "do not shelter",
    "alerts are fake",
    "alert is fake",
    "warnings are fake",
    "warning is a hoax",
  ]

  private static let selfHarmPhrases = [
    "kill myself",
    "killing myself",
    "end my life",
    "self-harm",
    "self harm",
  ]

  private static let selfHarmWords = [
    "suicide", "suicidal",
  ]

  private static let sexualWords = [
    "porn", "pornography", "xxx", "nude", "nudes", "nsfw",
    "fellatio", "cunnilingus",
  ]

  private static let hateWords = [
    "nigger", "niggers", "faggot", "faggots", "kike", "spic", "retard", "retards",
  ]

  private static let graphicViolenceWords = [
    "behead", "beheaded", "decapitate", "gore", "dismember",
  ]

  private static func containsAnyWord(_ text: String, words: [String]) -> Bool {
    let lowered = text.lowercased()
    for word in words {
      let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
      if lowered.range(of: pattern, options: .regularExpression) != nil {
        return true
      }
    }
    return false
  }

  private static func containsAnyPhrase(_ text: String, phrases: [String]) -> Bool {
    let lowered = text.lowercased()
    return phrases.contains { lowered.contains($0) }
  }
}
