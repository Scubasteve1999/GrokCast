import Foundation

/// Reads the cached daily Grok brief for widget / watch one-liners.
enum GrokBriefSnapshot {
  static func cacheKey(locationID: UUID, day: Date = Date()) -> String {
    let start = Calendar.current.startOfDay(for: day).timeIntervalSince1970
    return "grok_brief_\(locationID.uuidString)_\(Int(start))"
  }

  static func fullBrief(for locationID: UUID) -> String? {
    let key = cacheKey(locationID: locationID)
    let text = UserDefaults.standard.string(forKey: key)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let text, !text.isEmpty else { return nil }
    return text
  }

  /// First sentence or ~90 characters for widgets and complications.
  static func oneLiner(for locationID: UUID) -> String? {
    guard let full = fullBrief(for: locationID) else { return nil }
    let firstSentence =
      full
      .components(separatedBy: CharacterSet(charactersIn: ".!?"))
      .first?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? full
    if firstSentence.count <= 96 { return firstSentence }
    let idx = firstSentence.index(firstSentence.startIndex, offsetBy: 93)
    return String(firstSentence[..<idx]).trimmingCharacters(in: .whitespaces) + "…"
  }
}
