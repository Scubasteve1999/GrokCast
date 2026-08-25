import Foundation

/// Call-site copy for the Alerts screen. Does not mutate `AlertsHonesty`.
enum AlertsActiveCopy {
  /// Official NWS rows come first. Grok summarize is a trailing action.
  static let grokFollowsOfficialAlerts = true

  static func stateLine(
    locationName: String?,
    nwsCount: Int,
    checkedAt: Date?,
    now: Date = Date()
  ) -> String? {
    let place = locationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !place.isEmpty else { return nil }
    var parts = [place]
    if nwsCount > 0 {
      parts.append(nwsCount == 1 ? "1 active" : "\(nwsCount) active")
    }
    if let checkedAt {
      parts.append(checkedPhrase(checkedAt, now: now))
    }
    return parts.joined(separator: " · ")
  }

  static func checkedPhrase(_ checkedAt: Date, now: Date = Date()) -> String {
    let interval = max(0, now.timeIntervalSince(checkedAt))
    if interval < 60 { return "checked just now" }
    let minutes = Int(interval / 60)
    if minutes < 180 { return "checked \(minutes)m ago" }
    let hours = Int(interval / 3600)
    return "checked \(hours)h ago"
  }

  static func firstArea(_ areaDesc: String?) -> String? {
    guard let areaDesc else { return nil }
    let first =
      areaDesc.split(
        separator: ";", maxSplits: 1, omittingEmptySubsequences: true
      )
      .first?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return first.isEmpty ? nil : first
  }

  static func untilLine(
    expires: Date?,
    areaDesc: String?,
    now: Date = Date(),
    calendar: Calendar = .current,
    timeZone: TimeZone = .current
  ) -> String {
    var calendar = calendar
    calendar.timeZone = timeZone
    let until: String
    if let expires {
      let time = LocationTimezone.formatter(dateFormat: "h:mm a", timeZone: timeZone)
        .string(from: expires)
      if calendar.isDate(expires, inSameDayAs: now) {
        until = "Until \(time)"
      } else {
        let weekday = LocationTimezone.formatter(dateFormat: "EEE", timeZone: timeZone)
          .string(from: expires)
        until = "Until \(weekday) \(time)"
      }
    } else {
      until = "Active"
    }
    if let area = firstArea(areaDesc) {
      return "\(until) · \(area)"
    }
    return until
  }

  /// Instruction first. Drop NWS headlines that only restate "{event} issued … by …".
  static func cardBody(
    event: String,
    headline: String?,
    instruction: String?,
    description: String?
  ) -> String? {
    if let instruction = firstParagraph(instruction) { return instruction }
    if let headline = trimmed(headline), !headline.isEmpty {
      if isIssuedByHeadline(headline, event: event) {
        return firstParagraph(description)
      }
      return headline
    }
    return firstParagraph(description)
  }

  static func isIssuedByHeadline(_ headline: String, event: String) -> Bool {
    let trimmedHeadline = headline.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedHeadline.lowercased().hasPrefix(event.lowercased()) else { return false }
    let rest = trimmedHeadline.dropFirst(event.count).trimmingCharacters(in: .whitespaces)
    return rest.lowercased().hasPrefix("issued")
  }

  static func firstParagraph(_ text: String?) -> String? {
    guard let text = trimmed(text) else { return nil }
    let paragraph =
      text.components(separatedBy: "\n").first(where: {
        !$0.trimmingCharacters(in: .whitespaces).isEmpty
      }) ?? text
    return trimmed(paragraph)
  }

  private static func trimmed(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
