import Foundation

/// Glance-shaped Sky Check chat reply. Prompt asks for this; parser is tolerant
/// when the model dumps prose anyway.
enum SkyCheckGlance {
  struct Result: Equatable {
    var shortAnswer: String
    var changes: [String]
    var details: String?

    var showsDetails: Bool {
      guard let details else { return false }
      return !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  }

  static let maxChanges = 3
  static let detailsTitle = "Details"
  static let forecastAction = "Forecast"
  static let radarAction = "Radar"

  static func parse(_ raw: String) -> Result {
    let text = raw.replacingOccurrences(of: "\r\n", with: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else {
      return Result(shortAnswer: "", changes: [], details: nil)
    }
    if let sectioned = parseHeadings(text) {
      return cleaned(sectioned)
    }
    return cleaned(parseFallback(text))
  }

  // MARK: - Headed replies

  private enum Heading: Equatable {
    case shortAnswer
    case whatChanges
    case details
  }

  private static func parseHeadings(_ text: String) -> Result? {
    let lines = text.components(separatedBy: "\n")
    var buckets: [Heading: [String]] = [:]
    var order: [Heading] = []
    var preamble: [String] = []
    var current: Heading?

    for line in lines {
      if let heading = heading(from: line) {
        current = heading
        if buckets[heading] == nil {
          order.append(heading)
          buckets[heading] = []
        }
        continue
      }
      guard let current else {
        preamble.append(line)
        continue
      }
      buckets[current, default: []].append(line)
    }

    guard !order.isEmpty else { return nil }

    let headedAnswer = joinedParagraph(buckets[.shortAnswer] ?? [])
    let answer = headedAnswer.isEmpty ? joinedParagraph(preamble) : headedAnswer
    let changes = bullets(from: buckets[.whatChanges] ?? [])
    let details = joinedParagraph(buckets[.details] ?? [])

    var result = Result(
      shortAnswer: answer,
      changes: Array(changes.prefix(maxChanges)),
      details: details.isEmpty ? nil : details
    )
    if result.shortAnswer.isEmpty, !changes.isEmpty {
      result.shortAnswer = changes[0]
      result.changes = Array(changes.dropFirst().prefix(maxChanges))
    }
    if result.shortAnswer.isEmpty, !details.isEmpty {
      result.shortAnswer = firstSentence(details)
    }
    return result.shortAnswer.isEmpty ? nil : result
  }

  private static func heading(from line: String) -> Heading? {
    var stripped = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !stripped.isEmpty else { return nil }
    stripped = stripped.replacingOccurrences(of: "*", with: "")
    while stripped.hasPrefix("#") {
      stripped.removeFirst()
    }
    stripped = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    if stripped.hasSuffix(":") {
      stripped.removeLast()
    }
    stripped = stripped.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch stripped {
    case "short answer", "answer":
      return .shortAnswer
    case "what changes", "changes":
      return .whatChanges
    case "details", "sources", "source", "forecast details":
      return .details
    default:
      return nil
    }
  }

  // MARK: - Unheaded replies

  private static func parseFallback(_ text: String) -> Result {
    let lines = text.components(separatedBy: "\n")
    var preface: [String] = []
    var bulletLines: [String] = []
    var rest: [String] = []
    var seenBlankAfterPreface = false
    var inBullets = false
    var pastBullets = false

    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if pastBullets {
        rest.append(line)
        continue
      }
      if inBullets {
        if trimmed.isEmpty {
          pastBullets = true
          continue
        }
        if isBullet(trimmed) {
          bulletLines.append(trimmed)
          continue
        }
        pastBullets = true
        rest.append(line)
        continue
      }
      if isBullet(trimmed), !preface.isEmpty || seenBlankAfterPreface {
        inBullets = true
        bulletLines.append(trimmed)
        continue
      }
      if trimmed.isEmpty {
        if !preface.isEmpty { seenBlankAfterPreface = true }
        continue
      }
      if seenBlankAfterPreface {
        rest.append(line)
        continue
      }
      preface.append(line)
    }

    let answer = joinedParagraph(preface)
    let changes = bullets(from: bulletLines)
    let leftover = joinedParagraph(rest)
    let details: String? = leftover.isEmpty ? nil : leftover
    return Result(
      shortAnswer: answer.isEmpty ? firstSentence(text) : answer,
      changes: Array(changes.prefix(maxChanges)),
      details: details
    )
  }

  // MARK: - Line helpers

  private static func isBullet(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("•") || trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
      return true
    }
    return trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil
  }

  private static func bullets(from lines: [String]) -> [String] {
    var items: [String] = []
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { continue }
      if isBullet(trimmed) {
        var item = trimmed
        if item.hasPrefix("•") { item.removeFirst() }
        else if item.hasPrefix("- ") { item.removeFirst(2) }
        else if item.hasPrefix("* ") { item.removeFirst(2) }
        else if let range = item.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
          item.removeSubrange(range)
        }
        item = item.trimmingCharacters(in: .whitespacesAndNewlines)
        if !item.isEmpty { items.append(stripWrappingQuotes(item)) }
      } else if !trimmed.hasPrefix("#") {
        items.append(stripWrappingQuotes(trimmed))
      }
    }
    return items
  }

  private static func joinedParagraph(_ lines: [String]) -> String {
    lines
      .joined(separator: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func firstSentence(_ text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let end = trimmed.range(of: #"[.!?]"#, options: .regularExpression) else {
      return stripWrappingQuotes(trimmed)
    }
    return stripWrappingQuotes(String(trimmed[...end.lowerBound]))
  }

  private static func stripWrappingQuotes(_ text: String) -> String {
    var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let marks = CharacterSet(charactersIn: "\"“”")
    while let first = value.unicodeScalars.first, marks.contains(first) {
      value.removeFirst()
    }
    while let last = value.unicodeScalars.last, marks.contains(last) {
      value.removeLast()
    }
    return value.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func cleaned(_ result: Result) -> Result {
    var copy = result
    copy.shortAnswer = displayText(copy.shortAnswer)
    copy.changes = copy.changes.map(displayText).filter { !$0.isEmpty }
    if let details = copy.details {
      let trimmed = displayText(details)
      copy.details = trimmed.isEmpty ? nil : trimmed
    }
    return copy
  }

  private static func displayText(_ text: String) -> String {
    stripWrappingQuotes(
      SkyCheckMessageDisplay.markdown(text)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    )
  }
}
