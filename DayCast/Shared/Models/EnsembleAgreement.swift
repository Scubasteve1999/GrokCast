import Foundation

/// Open-Meteo ensemble spread for the honesty strip. Not MinuteCast.
/// Agree hides. Disagree is one range sentence — never a fake clock.
enum EnsembleAgreement {
  enum State: String, Equatable, Sendable {
    case agree
    case softDisagree
    case strongDisagree
  }

  struct Verdict: Equatable, Sendable {
    let state: State
    let memberCount: Int
    let wetCount: Int
    let startRange: ClosedRange<Date>?
    let isStorm: Bool
    /// At least one member is already wet in the current hour.
    let alreadyWet: Bool

    var wetFraction: Double {
      guard memberCount > 0 else { return 0 }
      return Double(wetCount) / Double(memberCount)
    }

    /// Visible chip only when spread is worth saying. Agree is quieter as absence.
    var showsChip: Bool { state != .agree }
  }

  enum Thresholds {
    /// Measurable hourly precip (Open-Meteo `precipitation_unit=inch`).
    static let wetInches = 0.01
    static let minMembers = 4
    /// Below this and the primary hourly is also dry → hide (agree dry).
    static let hideWetFraction = 0.20
    /// Wet/dry split at or below this is strong disagreement.
    static let splitWetFraction = 0.80
    static let agreeSpreadMinutes = 60
    /// Inclusive: 3 hours (`4–7pm`) is strong, matching the honesty example.
    static let softSpreadMinutes = 180
    static let windowHours = 12
    /// Current hour still counts as "now" for first-wet.
    static let lookbackMinutes = 30
  }

  static func evaluate(
    snapshot: EnsemblePrecipSnapshot?,
    hours: [HourlyForecast] = [],
    now: Date = Date()
  ) -> Verdict? {
    guard let snapshot, snapshot.isUsable(at: now) else { return nil }
    return evaluate(
      times: snapshot.times,
      members: snapshot.members,
      stormByMember: snapshot.stormByMember.isEmpty ? nil : snapshot.stormByMember,
      primaryIsWetInWindow: primaryIsWetInWindow(hours: hours, now: now),
      now: now
    )
  }

  /// Soft-fail: nil when the sample is too thin to score.
  static func evaluate(
    times: [Date],
    members: [[Double]],
    stormByMember: [[Bool]]? = nil,
    primaryIsWetInWindow: Bool = false,
    now: Date = Date(),
    windowHours: Int = Thresholds.windowHours
  ) -> Verdict? {
    let usable = members.filter { $0.count == times.count }
    guard usable.count >= Thresholds.minMembers, !times.isEmpty else { return nil }

    let windowStart = now.addingTimeInterval(-Double(Thresholds.lookbackMinutes) * 60)
    let windowEnd = now.addingTimeInterval(Double(windowHours) * 3600)

    var starts: [Date] = []
    var storm = false
    for (memberIndex, series) in usable.enumerated() {
      guard
        let first = firstWetIndex(
          times: times,
          inches: series,
          windowStart: windowStart,
          windowEnd: windowEnd
        )
      else { continue }
      starts.append(times[first])
      if let flags = stormByMember, flags.indices.contains(memberIndex),
        flags[memberIndex].indices.contains(first)
      {
        storm = storm || flags[memberIndex][first]
      } else if let flags = stormByMember, flags.indices.contains(memberIndex) {
        let inWindow = zip(times, flags[memberIndex]).contains { time, isStorm in
          time >= windowStart && time < windowEnd && isStorm
        }
        storm = storm || inWindow
      }
    }

    let wetCount = starts.count
    let fraction = Double(wetCount) / Double(usable.count)

    if fraction < Thresholds.hideWetFraction {
      if primaryIsWetInWindow {
        return Verdict(
          state: .softDisagree,
          memberCount: usable.count,
          wetCount: wetCount,
          startRange: range(from: starts),
          isStorm: storm,
          alreadyWet: false
        )
      }
      return Verdict(
        state: .agree,
        memberCount: usable.count,
        wetCount: wetCount,
        startRange: range(from: starts),
        isStorm: storm,
        alreadyWet: false
      )
    }

    let startRange = range(from: starts)
    let alreadyWet = starts.contains {
      $0 <= now.addingTimeInterval(Double(Thresholds.lookbackMinutes) * 60)
    }

    if fraction <= Thresholds.splitWetFraction {
      return Verdict(
        state: .strongDisagree,
        memberCount: usable.count,
        wetCount: wetCount,
        startRange: startRange,
        isStorm: storm,
        alreadyWet: alreadyWet
      )
    }

    let spreadMinutes = spreadMinutes(from: starts)
    let state: State
    if spreadMinutes <= Double(Thresholds.agreeSpreadMinutes) {
      state = .agree
    } else if spreadMinutes < Double(Thresholds.softSpreadMinutes) {
      state = .softDisagree
    } else {
      state = .strongDisagree
    }

    return Verdict(
      state: state,
      memberCount: usable.count,
      wetCount: wetCount,
      startRange: startRange,
      isStorm: storm,
      alreadyWet: alreadyWet
    )
  }

  /// First hourly in the window that is wet on DayCast's primary Open-Meteo series.
  static func primaryIsWetInWindow(
    hours: [HourlyForecast],
    now: Date = Date(),
    windowHours: Int = Thresholds.windowHours
  ) -> Bool {
    let windowStart = now.addingTimeInterval(-Double(Thresholds.lookbackMinutes) * 60)
    let windowEnd = now.addingTimeInterval(Double(windowHours) * 3600)
    return hours.contains { hour in
      hour.time >= windowStart && hour.time < windowEnd && isWetHour(hour)
    }
  }

  static func isStormCode(_ code: Int) -> Bool {
    switch code {
    case 95, 96, 99: return true
    default: return false
    }
  }

  static func isWetHour(_ hour: HourlyForecast) -> Bool {
    if hour.liquidPrecip >= Thresholds.wetInches { return true }
    if (hour.snowfall ?? 0) >= Thresholds.wetInches { return true }
    return isStormCode(hour.weatherCode)
  }

  static func firstWetIndex(
    times: [Date],
    inches: [Double],
    windowStart: Date,
    windowEnd: Date
  ) -> Int? {
    for (index, time) in times.enumerated() {
      guard time >= windowStart, time < windowEnd else { continue }
      let amount = inches.indices.contains(index) ? inches[index] : 0
      if amount >= Thresholds.wetInches { return index }
    }
    return nil
  }

  private static func range(from starts: [Date]) -> ClosedRange<Date>? {
    guard let min = starts.min(), let max = starts.max() else { return nil }
    return min...max
  }

  private static func spreadMinutes(from starts: [Date]) -> Double {
    guard let min = starts.min(), let max = starts.max() else { return 0 }
    return max.timeIntervalSince(min) / 60
  }
}

// MARK: - Copy

enum EnsembleAgreementCopy {
  /// One blunt sentence. Nil on agree / missing verdict — quieter is cleaner.
  static func sentence(
    for verdict: EnsembleAgreement.Verdict?,
    timeZone: TimeZone = .current
  ) -> String? {
    guard let verdict, verdict.showsChip else { return nil }
    let verb = verdict.state == .strongDisagree ? "disagree" : "differ"
    let noun = verdict.isStorm ? "storm" : "rain"

    if verdict.wetCount == 0 {
      return "models \(verb) — \(noun) may hold off"
    }

    guard let range = verdict.startRange else {
      return "models \(verb) — \(noun) may hold off"
    }

    if verdict.alreadyWet {
      let through = HonestyStripCopy.compactHour(range.upperBound, timeZone: timeZone)
      return "models \(verb) — \(noun) timing still spread through \(through)"
    }

    if range.lowerBound == range.upperBound {
      let clock = HonestyStripCopy.compactHour(range.lowerBound, timeZone: timeZone)
      if verdict.wetFraction <= EnsembleAgreement.Thresholds.splitWetFraction {
        return "models \(verb) — \(noun) may miss or start around \(clock)"
      }
      return "models \(verb) — \(noun) may start around \(clock)"
    }

    let span = hourRange(range.lowerBound, range.upperBound, timeZone: timeZone)
    return "models \(verb) — \(noun) may start \(span)"
  }

  /// `4–7pm` when both ends share am/pm; `11am–2pm` otherwise.
  static func hourRange(_ start: Date, _ end: Date, timeZone: TimeZone) -> String {
    let a = HonestyStripCopy.hourParts(start, timeZone: timeZone)
    let b = HonestyStripCopy.hourParts(end, timeZone: timeZone)
    if a.period == b.period {
      return "\(a.hour)–\(b.hour)\(b.period)"
    }
    return "\(a.hour)\(a.period)–\(b.hour)\(b.period)"
  }
}
