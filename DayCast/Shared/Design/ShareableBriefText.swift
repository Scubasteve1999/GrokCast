import Foundation

enum ShareableBriefText {
  static func weatherBrief(
    locationName: String,
    temperatureLine: String?,
    condition: String?,
    brief: String
  ) -> String {
    var lines = ["DayCast — \(locationName)"]
    if let temperatureLine, !temperatureLine.isEmpty {
      lines.append(temperatureLine + (condition.map { " · \($0)" } ?? ""))
    }
    lines.append("")
    lines.append(brief)
    lines.append("")
    lines.append(ShareAttribution.footer(for: .todayCard))
    return lines.joined(separator: "\n")
  }

  static func alertsSummary(locationName: String, summary: String, alertEvents: [String]) -> String {
    var lines = ["DayCast Alert Summary — \(locationName)"]
    if !alertEvents.isEmpty {
      lines.append(alertEvents.joined(separator: " · "))
    }
    lines.append("")
    lines.append(summary)
    lines.append("")
    lines.append(ShareAttribution.footer(for: .alertsSummary))
    return lines.joined(separator: "\n")
  }

  static func radarExplanation(context: RadarExplainContext, body: String) -> String {
    let lines = [
      "DayCast Radar — \(context.locationName)",
      "\(context.modeLabel) · \(context.frameLabel) · \(context.productName)",
      "",
      body,
      "",
      ShareAttribution.footer(for: .radarExplanation),
    ]
    return lines.joined(separator: "\n")
  }

  static func stormSpotterReport(
    locationName: String,
    observerNotes: String?,
    analysis: String
  ) -> String {
    var lines = [
      "DayCast Sky Check — \(locationName)",
      "#DayCastSkyCheck",
      "",
    ]
    if let notes = observerNotes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
      lines.append("Observer notes: \(notes)")
      lines.append("")
    }
    lines.append(analysis)
    lines.append("")
    lines.append(ShareAttribution.footer(for: .stormReport))
    return lines.joined(separator: "\n")
  }
}
