import Foundation

/// Collapses overlapping NWS point-query features into one user-facing alert.
/// `/alerts/active?point=` returns one GeoJSON feature per UGC; county + zone
/// of the same Air Quality Alert are not two sources.
enum NWSAlertGrouping {
  struct Group: Equatable {
    let representative: NWSAlert
    let members: [NWSAlert]
  }

  /// One representative per group, in first-seen group order.
  static func representatives(from alerts: [NWSAlert]) -> [NWSAlert] {
    grouped(from: alerts).map(\.representative)
  }

  static func uniqueEvents(from alerts: [NWSAlert]) -> [String] {
    var seen = Set<String>()
    var events: [String] = []
    for alert in representatives(from: alerts) {
      let key = normalizedEvent(alert.event)
      if seen.insert(key).inserted {
        events.append(alert.event)
      }
    }
    return events
  }

  static func grouped(
    from alerts: [NWSAlert],
    calendar: Calendar = Calendar(identifier: .gregorian)
  ) -> [Group] {
    var order: [String] = []
    var buckets: [String: [NWSAlert]] = [:]
    for alert in alerts {
      let key = groupingKey(for: alert, calendar: calendar)
      if buckets[key] == nil {
        order.append(key)
      }
      buckets[key, default: []].append(alert)
    }
    return order.compactMap { key in
      guard let members = buckets[key], !members.isEmpty else { return nil }
      return Group(representative: pickRepresentative(members), members: members)
    }
  }

  static func groupingKey(for alert: NWSAlert, calendar: Calendar) -> String {
    let event = normalizedEvent(alert.event)
    guard let expires = alert.expires else { return event }
    let day = calendar.startOfDay(for: expires).timeIntervalSince1970
    return "\(event)|\(Int(day))"
  }

  static func normalizedEvent(_ event: String) -> String {
    event.lowercased()
      .split { $0.isWhitespace || $0.isNewline }
      .joined(separator: " ")
  }

  static func pickRepresentative(_ members: [NWSAlert]) -> NWSAlert {
    members.max { lhs, rhs in
      if lhs.severityLevel != rhs.severityLevel {
        return lhs.severityLevel < rhs.severityLevel
      }
      let lhsInstruction = hasInstruction(lhs)
      let rhsInstruction = hasInstruction(rhs)
      if lhsInstruction != rhsInstruction {
        return !lhsInstruction && rhsInstruction
      }
      let lhsSent = lhs.sent ?? lhs.firstSeen
      let rhsSent = rhs.sent ?? rhs.firstSeen
      if lhsSent != rhsSent {
        return lhsSent > rhsSent
      }
      return lhs.id > rhs.id
    } ?? members[0]
  }

  private static func hasInstruction(_ alert: NWSAlert) -> Bool {
    guard let instruction = alert.instruction else { return false }
    return !instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}
