import Foundation

enum GrokBriefReportReason: String, CaseIterable, Identifiable, Sendable {
  case objectionable
  case falseOrMisleading
  case harmfulAdvice
  case other

  var id: String { rawValue }

  var title: String {
    switch self {
    case .objectionable: "Objectionable"
    case .falseOrMisleading: "False or misleading"
    case .harmfulAdvice: "Harmful advice"
    case .other: "Other"
    }
  }
}

enum GrokBriefReport {
  static let responsePromise = "We review reports within 24 hours."

  static func mailtoURL(
    reason: GrokBriefReportReason,
    brief: String,
    locationName: String,
    note: String,
    now: Date = Date()
  ) -> URL? {
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = supportAddress
    components.queryItems = [
      URLQueryItem(
        name: "subject",
        value: "DayCast Today's Take report — \(reason.title)"
      ),
      URLQueryItem(
        name: "body",
        value: body(
          reason: reason, brief: brief, locationName: locationName, note: note, now: now)
      ),
    ]
    return components.url
  }

  static func body(
    reason: GrokBriefReportReason,
    brief: String,
    locationName: String,
    note: String,
    now: Date = Date()
  ) -> String {
    let stamp = isoFormatter.string(from: now)
    let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
    var lines = [
      "Guideline 4.7 report — Today's Take",
      "Reason: \(reason.title)",
      "When: \(stamp)",
      "Location: \(locationName)",
      "",
      "Brief:",
      brief.trimmingCharacters(in: .whitespacesAndNewlines),
    ]
    if !trimmedNote.isEmpty {
      lines.append("")
      lines.append("Notes:")
      lines.append(trimmedNote)
    }
    return lines.joined(separator: "\n")
  }

  private static var supportAddress: String {
    AppLinks.supportEmail.absoluteString.replacingOccurrences(of: "mailto:", with: "")
  }

  private static let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()
}
