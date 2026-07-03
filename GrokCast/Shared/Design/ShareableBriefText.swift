import Foundation

enum ShareableBriefText {
  static func weatherBrief(
    locationName: String,
    temperatureLine: String?,
    condition: String?,
    brief: String
  ) -> String {
    var lines = ["GrokCast — \(locationName)"]
    if let temperatureLine, !temperatureLine.isEmpty {
      lines.append(temperatureLine + (condition.map { " · \($0)" } ?? ""))
    }
    lines.append("")
    lines.append(brief)
    lines.append("")
    lines.append("Shared from GrokCast")
    return lines.joined(separator: "\n")
  }

  static func alertsSummary(locationName: String, summary: String, alertEvents: [String]) -> String {
    var lines = ["GrokCast Alert Summary — \(locationName)"]
    if !alertEvents.isEmpty {
      lines.append(alertEvents.joined(separator: " · "))
    }
    lines.append("")
    lines.append(summary)
    lines.append("")
    lines.append("Shared from GrokCast")
    return lines.joined(separator: "\n")
  }

  static func radarExplanation(context: RadarExplainContext, body: String) -> String {
    let lines = [
      "GrokCast Radar — \(context.locationName)",
      "\(context.modeLabel) · \(context.frameLabel) · \(context.productName)",
      "",
      body,
      "",
      "Shared from GrokCast",
    ]
    return lines.joined(separator: "\n")
  }

  static func stormSpotterReport(
    locationName: String,
    observerNotes: String?,
    analysis: String
  ) -> String {
    var lines = [
      "GrokCast Storm Spotter — \(locationName)",
      "#GrokCastStormSpotter",
      "",
    ]
    if let notes = observerNotes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
      lines.append("Observer notes: \(notes)")
      lines.append("")
    }
    lines.append(analysis)
    lines.append("")
    lines.append("Shared from GrokCast · Storm Spotter")
    return lines.joined(separator: "\n")
  }
}
