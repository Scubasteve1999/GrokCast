import Foundation

/// Persistent office-of-record strip. Blunt, no fearbait, no fake precision.
/// DayCast is not official WEA — never say that in visible copy.
enum HonestyStripCopy {
  struct Content: Equatable, Sendable {
    let wfoLabel: String
    let headline: String?
    let snippet: String?
    /// Agree / hidden ensemble leaves this nil. Disagree is one range sentence.
    let ensembleSentence: String?

    var isExpanded: Bool { headline != nil }

    /// Ensemble disagree wins over AFD on the second line. One sentence, not a card.
    var secondLine: String? { ensembleSentence ?? snippet }

    var showsEnsembleLine: Bool { ensembleSentence != nil }

    /// Calm: `nws memphis`. Watch/warning: `nws memphis · severe thunderstorm watch until 9pm`.
    var primaryLine: String {
      if let headline {
        return "\(wfoLabel) · \(headline)"
      }
      return wfoLabel
    }

    var accessibilityLabel: String {
      var parts = [spokenOffice(from: wfoLabel)]
      if let headline { parts.append(headline) }
      if let secondLine { parts.append(secondLine) }
      parts.append("DayCast is not an official wireless emergency alert.")
      return parts.joined(separator: ". ")
    }
  }

  /// `Memphis, TN` / CWA `MEG` → `nws memphis`. Missing name → `nws meg`.
  /// Same shape for any WFO (TBW → `nws tampa bay area`). Nil when we have no office.
  static func wfoLabel(officeName: String?, cwa: String?) -> String? {
    let trimmedCWA = cwa?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let source = LocalBriefingParser.sourceName(
      officeName: officeName,
      cwa: trimmedCWA
    )
    let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.uppercased() != "NWS" else { return nil }
    return trimmed.lowercased()
  }

  /// Product + until. Lowercase, no MinuteCast clock, no "most accurate".
  static func headline(
    event: String,
    expires: Date?,
    now: Date = Date(),
    timeZone: TimeZone = .current
  ) -> String? {
    let product = event.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !product.isEmpty else { return nil }
    guard let expires else { return product }
    return "\(product) \(untilPhrase(expires: expires, now: now, timeZone: timeZone))"
  }

  /// `until 9pm` same calendar day; `until tue 9pm` otherwise. Minutes only when not :00.
  static func untilPhrase(
    expires: Date,
    now: Date = Date(),
    timeZone: TimeZone = .current
  ) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let time = compactClock(expires, calendar: calendar)
    if calendar.isDate(expires, inSameDayAs: now) {
      return "until \(time)"
    }
    let weekday = LocationTimezone.formatter(dateFormat: "eee", timeZone: timeZone)
      .string(from: expires)
      .lowercased()
    return "until \(weekday) \(time)"
  }

  /// Hour-only clock for ensemble ranges. Minutes only when not :00 — never MinuteCast.
  static func compactHour(_ date: Date, timeZone: TimeZone) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return compactClock(date, calendar: calendar)
  }

  static func hourParts(_ date: Date, timeZone: TimeZone) -> (hour: Int, period: String) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let hour = calendar.component(.hour, from: date)
    let hour12 = hour % 12 == 0 ? 12 : hour % 12
    let period = hour < 12 ? "am" : "pm"
    return (hour12, period)
  }

  /// First fresh AFD key-message card. Skip when calm or the rail has no AFD.
  /// HWO is not fetched today — do not invent a second text-product pipeline.
  static func afdSnippet(from items: [LocalBriefingItem], maxCharacters: Int = 88) -> String? {
    guard
      let raw = items.first(where: { $0.productCode.uppercased() == "AFD" })?.title
    else { return nil }
    let collapsed = collapseWhitespace(raw)
    guard !collapsed.isEmpty else { return nil }
    return clip(collapsed, maxCharacters: maxCharacters)
  }

  /// Watch/warning only. Advisories keep the official chip but do not expand this strip.
  static func watchWarning(from alerts: [NWSAlert]) -> NWSAlert? {
    AlertsFeedCard.glanceChips(from: alerts).first { $0.isWatch || $0.isWarning }
  }

  static func content(
    officeName: String?,
    cwa: String?,
    alerts: [NWSAlert],
    briefingItems: [LocalBriefingItem],
    ensemble: EnsembleAgreement.Verdict? = nil,
    now: Date = Date(),
    timeZone: TimeZone = .current
  ) -> Content? {
    guard let wfo = wfoLabel(officeName: officeName, cwa: cwa) else { return nil }
    let ensembleSentence = EnsembleAgreementCopy.sentence(for: ensemble, timeZone: timeZone)
    if let alert = watchWarning(from: alerts),
      let headline = headline(
        event: alert.event,
        expires: alert.expires,
        now: now,
        timeZone: timeZone
      )
    {
      return Content(
        wfoLabel: wfo,
        headline: headline,
        snippet: afdSnippet(from: briefingItems),
        ensembleSentence: ensembleSentence
      )
    }
    return Content(
      wfoLabel: wfo,
      headline: nil,
      snippet: nil,
      ensembleSentence: ensembleSentence
    )
  }

  /// Standalone chrome only when the Alerts chip is absent — story-day peek has ~4pt slack.
  static func showsStandaloneStrip(hasWFO: Bool, showAlertsSlot: Bool) -> Bool {
    hasWFO && !showAlertsSlot
  }

  private static func compactClock(_ date: Date, calendar: Calendar) -> String {
    let hour = calendar.component(.hour, from: date)
    let minute = calendar.component(.minute, from: date)
    let hour12 = hour % 12 == 0 ? 12 : hour % 12
    let period = hour < 12 ? "am" : "pm"
    if minute == 0 {
      return "\(hour12)\(period)"
    }
    return "\(hour12):\(String(format: "%02d", minute))\(period)"
  }

  private static func spokenOffice(from wfoLabel: String) -> String {
    let trimmed = wfoLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.lowercased().hasPrefix("nws ") {
      return "National Weather Service \(trimmed.dropFirst(4))"
    }
    if trimmed.lowercased() == "nws" {
      return "National Weather Service"
    }
    return "National Weather Service \(trimmed)"
  }

  private static func collapseWhitespace(_ string: String) -> String {
    string.split { $0.isWhitespace || $0.isNewline }.joined(separator: " ")
  }

  private static func clip(_ string: String, maxCharacters: Int) -> String {
    guard string.count > maxCharacters else { return string }
    let prefix = string.prefix(maxCharacters)
    if let lastSpace = prefix.lastIndex(of: " "), lastSpace > prefix.startIndex {
      return String(prefix[..<lastSpace]) + "…"
    }
    return String(prefix) + "…"
  }
}
