import Foundation

/// Punchy display titles for Your News cards. Office `title` stays the source of truth.
/// Deterministic — no Grok. Falls back to the office line if a punch-up is ungrounded.
enum YourNewsHeadline {
  static let maxCharacterCount = 72

  private static let apostrophe = "\u{2019}"

  static func displayTitle(for item: LocalBriefingItem) -> String {
    let office = collapse(item.title)
    guard !office.isEmpty else { return office }
    let punched = punchUp(office, officeID: item.officeID)
    let candidate = cap(collapse(punched))
    if candidate.isEmpty { return office }
    return isGrounded(candidate, in: office) ? candidate : office
  }

  /// Hazard / weather tokens in `display` must already appear in `officeTitle`
  /// (after light alias expansion). Structural words are ignored.
  static func isGrounded(_ display: String, in officeTitle: String) -> Bool {
    let source = expandedTokens(in: officeTitle)
    let restricted = restrictedTokens(in: display)
    return restricted.isSubset(of: source)
  }

  // MARK: - Punch-up

  private static func punchUp(_ office: String, officeID: String) -> String {
    let lower = office.lowercased()
    let voice = officeVoice(officeID)

    if lower.contains("late tonight"),
      lower.contains("thunderstorm") || lower.contains("shower")
    {
      return "Why tonight\(apostrophe)s storms still have a window after dark."
    }

    if lower.contains("isolated"),
      (lower.contains("thunderstorm") || lower.contains("shower")),
      lower.contains("tuesday")
    {
      return "Why Tuesday morning still has an isolated storm window."
    }

    if lower.contains("additional chances"),
      lower.contains("thunderstorm") || lower.contains("shower")
    {
      if lower.contains("midweek") {
        return "The midweek storm round \(voice) says isn\(apostrophe)t done yet."
      }
      if lower.contains("thursday") {
        return "The Thursday storm round \(voice) says isn\(apostrophe)t done yet."
      }
      return "The extra storm round \(voice) says isn\(apostrophe)t done yet."
    }

    if lower.contains("mid-south"), lower.contains("temperature"),
      lower.contains("extreme heat"), lower.contains("not expected")
    {
      return "The Mid-South stays warm. Extreme heat? \(voice) says no."
    }

    if lower.contains("damage survey")
      || (lower.contains("survey") && lower.contains("tornado"))
    {
      if lower.contains("tornado") {
        return "The tornado damage survey NWS just posted."
      }
      return "The damage survey NWS just posted."
    }

    if lower.contains("flash flood watch") {
      return "The Flash Flood Watch \(voice) just posted."
    }

    if lower.contains("heat continues"), lower.contains("overnight") {
      return "The overnight heat \(voice) says won\(apostrophe)t let up."
    }

    if lower.contains("flash flood risk"), lower.contains("monday") {
      return "The Monday flood risk \(voice) is flagging."
    }

    return fallback(office)
  }

  private static func fallback(_ office: String) -> String {
    var clause = office
    if let range = clause.range(of: ", with ", options: .caseInsensitive)
      ?? clause.range(of: ";")
    {
      clause = String(clause[..<range.lowerBound])
    } else if let comma = clause.range(of: ","),
      clause.distance(from: clause.startIndex, to: comma.lowerBound) > 24
    {
      clause = String(clause[..<comma.lowerBound])
    }
    var stripped = clause
    for phrase in [" are expected", " is expected", " are possible", " is possible"] {
      stripped = stripped.replacingOccurrences(
        of: phrase, with: "", options: .caseInsensitive)
    }
    let trimmed = collapse(stripped)
    guard !trimmed.isEmpty else { return office }
    if trimmed.hasSuffix(".") { return trimmed }
    return trimmed + "."
  }

  private static func officeVoice(_ officeID: String) -> String {
    let trimmed = officeID.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "NWS" : trimmed
  }

  private static func cap(_ text: String) -> String {
    guard text.count > maxCharacterCount else { return text }
    let prefix = String(text.prefix(maxCharacterCount))
    if let space = prefix.lastIndex(of: " "), space > prefix.startIndex {
      return collapse(String(prefix[..<space]))
    }
    return collapse(prefix)
  }

  private static func collapse(_ string: String) -> String {
    string.split { $0.isWhitespace || $0.isNewline }.joined(separator: " ")
  }

  // MARK: - Grounding

  private static let restricted: Set<String> = [
    "tornado", "tornadoes", "funnel", "warning", "watch", "advisory", "severe",
    "flood", "floods", "hail", "wind", "heat", "freeze", "snow", "ice",
    "hurricane", "blizzard", "damage", "survey",
    "storm", "storms", "thunderstorm", "thunderstorms", "shower", "showers",
    "rain", "fog", "lightning", "flash", "warm",
  ]

  private static func restrictedTokens(in text: String) -> Set<String> {
    wordTokens(in: text).intersection(restricted)
  }

  private static func expandedTokens(in text: String) -> Set<String> {
    var tokens = wordTokens(in: text)
    if tokens.contains("thunderstorm") || tokens.contains("thunderstorms")
      || tokens.contains("storm") || tokens.contains("storms")
    {
      tokens.formUnion(["storm", "storms", "thunderstorm", "thunderstorms"])
    }
    if tokens.contains("shower") || tokens.contains("showers") {
      tokens.formUnion(["shower", "showers"])
    }
    if tokens.contains("tornado") || tokens.contains("tornadoes") {
      tokens.formUnion(["tornado", "tornadoes"])
    }
    if tokens.contains("flood") || tokens.contains("floods") {
      tokens.formUnion(["flood", "floods"])
    }
    if tokens.contains("temperature") || tokens.contains("temperatures") {
      tokens.formUnion(["temperature", "temperatures", "warm"])
    }
    if text.lowercased().contains("flash flood") {
      tokens.formUnion(["flash", "flood", "floods"])
    }
    return tokens
  }

  private static func wordTokens(in text: String) -> Set<String> {
    let folded =
      text
      .lowercased()
      .replacingOccurrences(of: "\u{2019}", with: "")
      .replacingOccurrences(of: "'", with: "")
    return Set(
      folded.split { !$0.isLetter }
        .map(String.init)
        .filter { $0.count >= 3 }
    )
  }
}
