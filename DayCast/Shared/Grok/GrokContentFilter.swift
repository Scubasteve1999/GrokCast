import Foundation

/// Client-side screen for Grok output (App Review Guideline 4.7).
/// Today's Take / Explain Radar / Alerts / trip travel tips use `maxCharacterCount`.
/// Sky Check chat and vision use `skyCheckMaxCharacterCount` — weather answers are longer.
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
  /// Sky Check chat / vision. ~3× a 1024-token vision body. Empty still blocks.
  static let skyCheckMaxCharacterCount = 12_000

  static func screen(_ text: String, maxCharacterCount: Int = Self.maxCharacterCount) -> Verdict {
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

  static func acceptedText(
    _ text: String, maxCharacterCount: Int = Self.maxCharacterCount
  ) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard case .allowed = screen(trimmed, maxCharacterCount: maxCharacterCount) else { return nil }
    return trimmed
  }

  static func acceptedSkyCheckText(_ text: String) -> String? {
    acceptedText(text, maxCharacterCount: skyCheckMaxCharacterCount)
  }

  struct StreamScreen: Equatable {
    /// Text safe to show now: everything up to the last finished word.
    let visible: String
    /// Characters of `visible` that have been screened (pass back on the next token).
    let screenedCount: Int
    let blocked: Bool
  }

  /// Longest blocklist phrase is well under this; re-screen this much before the
  /// new text so a phrase split across tokens is still caught.
  static let streamScreenOverlap = 120

  /// Screens a Sky Check reply while it streams, so a blocked word is never drawn.
  /// The trailing unfinished word is held back: `\b` would otherwise match a
  /// fragment ("ass" of "assessment") and flash it before it's complete.
  static func screenSkyCheckStream(_ raw: String, alreadyScreenedCount: Int) -> StreamScreen {
    let settled: String
    if let boundary = raw.lastIndex(where: isStreamWordBoundary) {
      settled = String(raw[...boundary])
    } else {
      settled = ""
    }
    if settled.count > skyCheckMaxCharacterCount {
      return StreamScreen(visible: "", screenedCount: 0, blocked: true)
    }
    guard settled.count > alreadyScreenedCount else {
      return StreamScreen(visible: settled, screenedCount: settled.count, blocked: false)
    }

    // Start the window on a word boundary so a cut-off fragment can't match.
    var start = settled.index(
      settled.startIndex, offsetBy: max(0, alreadyScreenedCount - streamScreenOverlap))
    if start != settled.startIndex,
      let nextBoundary = settled[start...].firstIndex(where: isStreamWordBoundary)
    {
      start = nextBoundary
    }
    let window = String(settled[start...])
    if case .blocked(let reason) = screen(window, maxCharacterCount: .max), reason != .empty {
      return StreamScreen(visible: "", screenedCount: 0, blocked: true)
    }
    return StreamScreen(visible: settled, screenedCount: settled.count, blocked: false)
  }

  private static func isStreamWordBoundary(_ character: Character) -> Bool {
    if character == "'" || character == "’" { return false }
    return character.isWhitespace || character.isPunctuation
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
    if let accepted = GrokContentFilter.acceptedText(visible(raw)) {
      return accepted
    }
    return GrokContentFilter.acceptedText(
      visible(
        LocalWeatherBrief.make(
          weather: weather,
          unit: unit,
          locationName: locationName,
          activeAlerts: activeAlerts
        )
      )
    )
  }

  /// User-facing brief/summary: drop pipeline tags, keep weather meaning.
  static func visible(_ text: String) -> String {
    var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let prefixes = ["Forecast-only take:", "Official take:"]
    for prefix in prefixes {
      if let range = result.range(of: prefix, options: [.caseInsensitive, .anchored]) {
        result = String(result[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        break
      }
    }
    result = result.replacingOccurrences(
      of: "SEVERE CONTEXT", with: "Severe weather", options: .caseInsensitive)
    result = result.replacingOccurrences(
      of: #"\bMD\s*#?\s*\d+\b"#,
      with: "storm discussion",
      options: [.regularExpression, .caseInsensitive]
    )
    while result.contains("  ") {
      result = result.replacingOccurrences(of: "  ", with: " ")
    }
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
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
