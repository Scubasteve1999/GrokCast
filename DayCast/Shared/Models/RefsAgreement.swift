import Foundation

/// REFS timing confidence. A multi-hour window, never a minute clock.
/// Separate from `ForecastEraNotice` and from the Open-Meteo `HonestyStrip`.
enum RefsAgreementTier: String, Codable, Equatable, Sendable {
  case locked
  case likelyWindow = "likely_window"
  case wideWindow = "wide_window"
  case split
  case dryConsensus = "dry_consensus"
}

struct RefsTimingWindow: Codable, Equatable, Sendable {
  var startLocal: Date
  var endLocal: Date
  var widthHours: Int
  /// Hour inside the window. Never shown without the window.
  var softPeakLocal: Date?

  enum CodingKeys: String, CodingKey {
    case startLocal = "start_local"
    case endLocal = "end_local"
    case widthHours = "width_hours"
    case softPeakLocal = "soft_peak_local"
  }
}

struct RefsAgreementSources: Codable, Equatable, Sendable {
  var refsCycle: String
  var domain: String
  var hrrrCycle: String?
  var labels: [String]

  enum CodingKeys: String, CodingKey {
    case refsCycle = "refs_cycle"
    case domain
    case hrrrCycle = "hrrr_cycle"
    case labels
  }
}

struct RefsDivergence: Codable, Equatable, Sendable {
  var present: Bool
  var hrrrPeakLocal: Date?
  var sentence: String

  enum CodingKeys: String, CodingKey {
    case present
    case hrrrPeakLocal = "hrrr_peak_local"
    case sentence
  }
}

struct RefsAgreementPayload: Codable, Equatable, Sendable {
  var agreementTier: RefsAgreementTier
  var timingWindow: RefsTimingWindow?
  var sources: RefsAgreementSources
  var divergence: RefsDivergence?
  var asOf: Date
  var parallel: Bool
  /// True only for the documented sample. Live extracts omit it.
  var stub: Bool?

  enum CodingKeys: String, CodingKey {
    case agreementTier = "agreement_tier"
    case timingWindow = "timing_window"
    case sources
    case divergence
    case asOf = "as_of"
    case parallel
    case stub
  }

  init(
    agreementTier: RefsAgreementTier,
    timingWindow: RefsTimingWindow?,
    sources: RefsAgreementSources,
    divergence: RefsDivergence?,
    asOf: Date,
    parallel: Bool,
    stub: Bool? = nil
  ) {
    self.agreementTier = agreementTier
    self.timingWindow = timingWindow
    self.sources = sources
    self.divergence = divergence
    self.asOf = asOf
    self.parallel = parallel
    self.stub = stub
  }
}

enum RefsAgreement {
  static let wetEASPercent = 30.0
  static let lockedMaxHours = 2
  static let lockedMinPeak = 60.0
  static let likelyMaxHours = 4
  static let likelyMinPeak = 40.0
  static let hrrrWetMillimeters = 0.254
  /// NCEP production cutover. `parallel` stays true until this instant.
  static let cutoverUTC = Date(timeIntervalSince1970: 1_791_979_200)

  struct HourSample: Equatable, Sendable {
    var valid: Date
    var easPercent: Double
  }

  struct HrrrSample: Equatable, Sendable {
    var valid: Date
    var apcpMillimeters: Double
  }

  struct Meta: Equatable, Sendable {
    var refsCycle: String
    var hrrrCycle: String?
    var domain: String
    var asOf: Date
  }

  static func parallel(at date: Date) -> Bool {
    date < cutoverUTC
  }

  static func floorHour(_ date: Date) -> Date {
    let floored = (date.timeIntervalSince1970 / 3600).rounded(.down) * 3600
    return Date(timeIntervalSince1970: floored)
  }

  static func classify(
    refsHours: [HourSample],
    hrrrHours: [HrrrSample]?,
    timeZone: TimeZone,
    meta: Meta
  ) -> RefsAgreementPayload {
    let lookedAtHrrr = hrrrHours != nil
    let labels = lookedAtHrrr ? ["REFS", "HRRR"] : ["REFS"]
    let wet = refsHours
      .map { HourSample(valid: floorHour($0.valid), easPercent: $0.easPercent) }
      .filter { $0.easPercent >= wetEASPercent }
      .sorted { $0.valid < $1.valid }
    let peak = (hrrrHours ?? [])
      .map { HrrrSample(valid: floorHour($0.valid), apcpMillimeters: $0.apcpMillimeters) }
      .filter { $0.apcpMillimeters >= hrrrWetMillimeters }
      .sorted { lhs, rhs in
        if lhs.apcpMillimeters == rhs.apcpMillimeters { return lhs.valid < rhs.valid }
        return lhs.apcpMillimeters > rhs.apcpMillimeters
      }
      .first
    let sources = RefsAgreementSources(
      refsCycle: meta.refsCycle,
      domain: meta.domain,
      hrrrCycle: meta.hrrrCycle,
      labels: labels
    )
    if wet.isEmpty {
      if let peak {
        return RefsAgreementPayload(
          agreementTier: .split,
          timingWindow: nil,
          sources: sources,
          divergence: RefsDivergence(
            present: true,
            hrrrPeakLocal: peak.valid,
            sentence: divergenceSentence(
              hrrrPeak: peak.valid,
              windowStart: nil,
              windowEnd: nil,
              timeZone: timeZone
            )
          ),
          asOf: meta.asOf,
          parallel: parallel(at: meta.asOf)
        )
      }
      return RefsAgreementPayload(
        agreementTier: .dryConsensus,
        timingWindow: nil,
        sources: sources,
        divergence: nil,
        asOf: meta.asOf,
        parallel: parallel(at: meta.asOf)
      )
    }

    let start = wet[0].valid
    let last = wet[wet.count - 1].valid
    let end = last.addingTimeInterval(3600)
    let width = max(1, Int((end.timeIntervalSince(start) / 3600).rounded()))
    let soft = wet.max { $0.easPercent < $1.easPercent } ?? wet[0]
    let softInside = soft.valid >= start && soft.valid < end
    var window = RefsTimingWindow(
      startLocal: start,
      endLocal: end,
      widthHours: width,
      softPeakLocal: softInside ? soft.valid : nil
    )
    let peakOutside = peak.map { $0.valid < start || $0.valid >= end } ?? false
    let tier: RefsAgreementTier
    if peakOutside {
      tier = .split
    } else if width <= lockedMaxHours && soft.easPercent >= lockedMinPeak {
      tier = .locked
    } else if width <= likelyMaxHours && soft.easPercent >= likelyMinPeak {
      tier = .likelyWindow
    } else {
      tier = .wideWindow
    }
    let divergence: RefsDivergence? = peakOutside
      ? RefsDivergence(
        present: true,
        hrrrPeakLocal: peak?.valid,
        sentence: divergenceSentence(
          hrrrPeak: peak?.valid ?? start,
          windowStart: start,
          windowEnd: end,
          timeZone: timeZone
        )
      )
      : nil
    if !softInside { window.softPeakLocal = nil }
    return RefsAgreementPayload(
      agreementTier: tier,
      timingWindow: window,
      sources: sources,
      divergence: divergence,
      asOf: meta.asOf,
      parallel: parallel(at: meta.asOf)
    )
  }

  static func divergenceSentence(
    hrrrPeak: Date,
    windowStart: Date?,
    windowEnd: Date?,
    timeZone: TimeZone
  ) -> String {
    let near = hourLabel(hrrrPeak, timeZone: timeZone)
    guard let windowStart, let windowEnd else {
      return "The hourly model puts the rain near \(near); the ensemble still doesn't share that hour — the timing isn't locked yet."
    }
    let range = rangePhrase(start: windowStart, end: windowEnd, timeZone: timeZone)
    return "The hourly model puts the rain near \(near); the ensemble still says anywhere from \(range) — the timing isn't locked yet."
  }

  static func hourLabel(_ date: Date, timeZone: TimeZone) -> String {
    let hour = calendarHour(date, timeZone: timeZone)
    let suffix = hour >= 12 ? "pm" : "am"
    let clock = hour % 12 == 0 ? 12 : hour % 12
    return "\(clock)\(suffix)"
  }

  static func rangePhrase(start: Date, end: Date, timeZone: TimeZone) -> String {
    let startHour = calendarHour(start, timeZone: timeZone)
    let endHour = calendarHour(end, timeZone: timeZone)
    let startSuffix = startHour >= 12 ? "pm" : "am"
    let endSuffix = endHour >= 12 ? "pm" : "am"
    let startClock = startHour % 12 == 0 ? 12 : startHour % 12
    let endClock = endHour % 12 == 0 ? 12 : endHour % 12
    if startSuffix == endSuffix { return "\(startClock) to \(endClock)\(endSuffix)" }
    return "\(startClock)\(startSuffix) to \(endClock)\(endSuffix)"
  }

  /// Drop a soft peak that has no window, drop any "EAS" consumer copy, keep REFS/HRRR labels.
  static func sanitized(_ payload: RefsAgreementPayload) -> RefsAgreementPayload {
    var copy = payload
    copy.sources.labels = copy.sources.labels.filter { $0 == "REFS" || $0 == "HRRR" }
    if copy.agreementTier == .dryConsensus {
      copy.timingWindow = nil
      copy.divergence = nil
      return copy
    }
    if var window = copy.timingWindow {
      window.startLocal = floorHour(window.startLocal)
      window.endLocal = floorHour(window.endLocal)
      if let peak = window.softPeakLocal {
        let floored = floorHour(peak)
        if floored >= window.startLocal && floored < window.endLocal {
          window.softPeakLocal = floored
        } else {
          window.softPeakLocal = nil
        }
      }
      copy.timingWindow = window
    }
    if let divergence = copy.divergence {
      let banned = divergence.sentence.range(of: "eas", options: .caseInsensitive) != nil
      if !divergence.present || banned {
        copy.divergence = nil
      }
    }
    return copy
  }

  static func decode(_ data: Data) -> RefsAgreementPayload? {
    guard let payload = try? decoder.decode(RefsAgreementPayload.self, from: data) else { return nil }
    let clean = sanitized(payload)
    if clean.timingWindow == nil && clean.agreementTier != .dryConsensus && clean.agreementTier != .split {
      return nil
    }
    return clean
  }

  /// Canonical QA sentence. Not a live extract. `stub` stays true.
  static var debugSample: RefsAgreementPayload {
    let json = """
      {
        "agreement_tier": "split",
        "timing_window": {
          "start_local": "2026-09-21T14:00:00-05:00",
          "end_local": "2026-09-21T17:00:00-05:00",
          "width_hours": 3,
          "soft_peak_local": "2026-09-21T15:00:00-05:00"
        },
        "sources": {
          "refs_cycle": "2026-09-21T12:00:00Z",
          "domain": "conus",
          "hrrr_cycle": "2026-09-21T17:00:00Z",
          "labels": ["REFS", "HRRR"]
        },
        "divergence": {
          "present": true,
          "hrrr_peak_local": "2026-09-21T15:00:00-05:00",
          "sentence": "The hourly model puts the rain near 3pm; the ensemble still says anywhere from 2 to 5pm — the timing isn't locked yet."
        },
        "as_of": "2026-09-21T18:00:00Z",
        "parallel": true,
        "stub": true
      }
      """
    guard let payload = decode(Data(json.utf8)) else {
      preconditionFailure("REFS debug sample must decode")
    }
    return payload
  }

  private static func calendarHour(_ date: Date, timeZone: TimeZone) -> Int {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.component(.hour, from: date)
  }

  private static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let text = try container.decode(String.self)
      if let date = isoFractional.date(from: text) ?? iso.date(from: text) {
        return date
      }
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Expected an ISO-8601 hour"
      )
    }
    return decoder
  }()

  private static let iso: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  private static let isoFractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()
}

enum RefsAgreementCopy {
  static func tierTitle(_ tier: RefsAgreementTier) -> String {
    switch tier {
    case .locked: "Timing is tight"
    case .likelyWindow: "Likely window"
    case .wideWindow: "Wide window"
    case .split: "Timing isn't locked"
    case .dryConsensus: "Ensemble agrees dry"
    }
  }

  static let dryLine = "The ensemble agrees this stretch stays dry."

  static func sourceLine(_ labels: [String]) -> String {
    labels.filter { $0 == "REFS" || $0 == "HRRR" }.joined(separator: " · ")
  }

  static func windowPhrase(_ window: RefsTimingWindow, timeZone: TimeZone) -> String {
    RefsAgreement.rangePhrase(start: window.startLocal, end: window.endLocal, timeZone: timeZone)
  }

  /// Window when the ensemble has one. Dry copy only for `dry_consensus`.
  /// A split with no window leads with the divergence sentence.
  static func primaryLine(_ payload: RefsAgreementPayload, timeZone: TimeZone) -> String {
    if let window = payload.timingWindow {
      return windowPhrase(window, timeZone: timeZone)
    }
    if payload.agreementTier == .dryConsensus {
      return dryLine
    }
    if let sentence = payload.divergence?.sentence, payload.divergence?.present == true {
      return sentence
    }
    return dryLine
  }

  static func accessibility(_ payload: RefsAgreementPayload, timeZone: TimeZone) -> String {
    var parts = [tierTitle(payload.agreementTier)]
    if let window = payload.timingWindow {
      parts.append(windowPhrase(window, timeZone: timeZone))
    } else if payload.agreementTier == .dryConsensus {
      parts.append(dryLine)
    }
    let sources = sourceLine(payload.sources.labels)
    if !sources.isEmpty { parts.append(sources) }
    if let sentence = payload.divergence?.sentence, payload.divergence?.present == true {
      parts.append(sentence)
    }
    return parts.joined(separator: ". ")
  }
}
