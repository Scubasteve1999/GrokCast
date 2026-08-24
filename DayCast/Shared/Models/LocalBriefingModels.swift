import Foundation

/// One NWS office product card on Alerts → Local briefing.
/// Stable ids (`afd-{productId}` / `pns-{productId}`). Never `UUID()`.
struct LocalBriefingItem: Identifiable, Codable, Equatable, Sendable {
  let id: String
  let title: String
  let sourceName: String
  let issuedAt: Date
  let url: URL
  let productCode: String
  let officeID: String

  func relativeIssuedLabel(relativeTo now: Date = Date()) -> String {
    let interval = max(0, now.timeIntervalSince(issuedAt))
    if interval < 60 { return "just now" }
    let minutes = Int(interval / 60)
    if minutes < 60 { return "\(minutes)m ago" }
    let hours = Int(interval / 3600)
    if hours < 24 { return "\(hours)h ago" }
    let days = Int(interval / 86_400)
    return "\(days)d ago"
  }
}

enum LocalBriefingParser {
  static let afdMaxAge: TimeInterval = 18 * 3600
  static let pnsMaxAge: TimeInterval = 48 * 3600
  static let maxCards = 3

  static func isAFDFresh(_ issuedAt: Date, now: Date = Date()) -> Bool {
    now.timeIntervalSince(issuedAt) <= afdMaxAge
  }

  static func isPNSFresh(_ issuedAt: Date, now: Date = Date()) -> Bool {
    now.timeIntervalSince(issuedAt) <= pnsMaxAge
  }

  static func parseIssuance(_ string: String?) -> Date? {
    guard let string, !string.isEmpty else { return nil }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: string) { return date }
    iso.formatOptions = [.withInternetDateTime]
    return iso.date(from: string)
  }

  /// `Memphis, TN` → `NWS Memphis`. Missing name → `NWS MEG`.
  static func sourceName(officeName: String?, cwa: String) -> String {
    let trimmedCWA = cwa.trimmingCharacters(in: .whitespacesAndNewlines)
    let fallback = trimmedCWA.isEmpty ? "NWS" : "NWS \(trimmedCWA)"
    guard let raw = officeName?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty
    else {
      return fallback
    }
    let city =
      raw.split(separator: ",", maxSplits: 1).first.map {
        String($0).trimmingCharacters(in: .whitespacesAndNewlines)
      } ?? raw
    if city.lowercased().hasPrefix("nws ") { return city }
    return "NWS \(city)"
  }

  static func productPageURL(cwa: String, productCode: String) -> URL {
    var comps = URLComponents(string: "https://forecast.weather.gov/product.php")!
    comps.queryItems = [
      URLQueryItem(name: "site", value: "NWS"),
      URLQueryItem(name: "issuedby", value: cwa),
      URLQueryItem(name: "product", value: productCode),
      URLQueryItem(name: "format", value: "CI"),
    ]
    return comps.url!
  }

  /// First KEY MESSAGES bullet. Missing block → no AFD card (do not dump DISCUSSION).
  static func firstKeyMessage(fromAFD text: String) -> String? {
    keyMessageBullets(fromAFD: text).first
  }

  static func keyMessageBullets(fromAFD text: String) -> [String] {
    guard let block = keyMessagesBlock(from: text) else { return [] }
    var bullets: [String] = []
    var current: String?
    for rawLine in block.components(separatedBy: .newlines) {
      let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("-") {
        if let current {
          let collapsed = collapseWhitespace(current)
          if !collapsed.isEmpty { bullets.append(collapsed) }
        }
        current = String(trimmed.drop(while: { $0 == "-" || $0.isWhitespace }))
      } else if current != nil, !trimmed.isEmpty, !trimmed.hasPrefix("."), trimmed != "&&" {
        current = (current ?? "") + " " + trimmed
      }
    }
    if let current {
      let collapsed = collapseWhitespace(current)
      if !collapsed.isEmpty { bullets.append(collapsed) }
    }
    return bullets
  }

  static func pnsHeadline(from text: String) -> String? {
    if let wrapped = ellipsisHeadline(from: text) { return wrapped }
    return firstNonHeaderSentence(from: text)
  }

  /// Keep storm/survey/damage PNS. Drop NWR / radio / administrative notices.
  static func shouldKeepPNS(title: String, body: String) -> Bool {
    let haystack = (title + "\n" + body).lowercased()
    let isWeather =
      [
        "storm", "survey", "tornado", "damage", "flood", "winter", "heat", "event",
      ].contains { haystack.contains($0) }
    let isAdmin =
      [
        "nwr", "weather radio", "noaa weather radio", "administrative",
        "radio broadcast",
      ].contains { haystack.contains($0) }
    if isAdmin && !isWeather { return false }
    return isWeather
  }

  static func assemble(
    cwa: String,
    officeName: String?,
    afd: (id: String, issuedAt: Date, text: String)?,
    pns: [(id: String, issuedAt: Date, text: String)],
    now: Date = Date()
  ) -> [LocalBriefingItem] {
    let trimmedCWA = cwa.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedCWA.isEmpty else { return [] }
    let source = sourceName(officeName: officeName, cwa: trimmedCWA)
    var items: [LocalBriefingItem] = []

    if let afd, isAFDFresh(afd.issuedAt, now: now),
      let title = firstKeyMessage(fromAFD: afd.text)
    {
      items.append(
        LocalBriefingItem(
          id: "afd-\(afd.id)",
          title: title,
          sourceName: source,
          issuedAt: afd.issuedAt,
          url: productPageURL(cwa: trimmedCWA, productCode: "AFD"),
          productCode: "AFD",
          officeID: trimmedCWA
        )
      )
    }

    let sortedPNS = pns.sorted { $0.issuedAt > $1.issuedAt }
    for product in sortedPNS {
      if items.count >= maxCards { break }
      guard isPNSFresh(product.issuedAt, now: now) else { continue }
      guard let title = pnsHeadline(from: product.text), !title.isEmpty else { continue }
      guard shouldKeepPNS(title: title, body: product.text) else { continue }
      items.append(
        LocalBriefingItem(
          id: "pns-\(product.id)",
          title: title,
          sourceName: source,
          issuedAt: product.issuedAt,
          url: productPageURL(cwa: trimmedCWA, productCode: "PNS"),
          productCode: "PNS",
          officeID: trimmedCWA
        )
      )
    }

    return Array(items.prefix(maxCards))
  }

  // MARK: - Internals

  private static func keyMessagesBlock(from text: String) -> String? {
    let upper = text.uppercased()
    guard let headerRange = upper.range(of: ".KEY MESSAGES") else { return nil }
    let afterHeader = text[headerRange.upperBound...]
    let endIndex = afterHeader.range(of: "&&")?.lowerBound ?? afterHeader.endIndex
    return String(afterHeader[..<endIndex])
  }

  private static func ellipsisHeadline(from text: String) -> String? {
    var collecting: [String] = []
    var started = false
    for raw in text.components(separatedBy: .newlines) {
      let line = raw.trimmingCharacters(in: .whitespaces)
      if !started {
        guard line.contains("...") else { continue }
        started = true
        collecting.append(line)
        if isCompleteEllipsisHeadline(collecting) { break }
      } else {
        collecting.append(line)
        if isCompleteEllipsisHeadline(collecting) { break }
        if collecting.count > 8 { break }
      }
    }
    guard started else { return nil }
    let joined = collapseWhitespace(collecting.joined(separator: " "))
    let stripped = stripEllipsis(joined)
    return stripped.isEmpty ? nil : stripped
  }

  private static func isCompleteEllipsisHeadline(_ parts: [String]) -> Bool {
    let joined = parts.joined(separator: " ")
    guard let first = joined.range(of: "...") else { return false }
    return joined[first.upperBound...].contains("...")
  }

  private static func stripEllipsis(_ string: String) -> String {
    var result = string.trimmingCharacters(in: .whitespacesAndNewlines)
    while result.hasPrefix(".") {
      result.removeFirst()
    }
    while result.hasSuffix(".") {
      result.removeLast()
    }
    return collapseWhitespace(result)
  }

  private static func firstNonHeaderSentence(from text: String) -> String? {
    for raw in text.components(separatedBy: .newlines) {
      let line = raw.trimmingCharacters(in: .whitespaces)
      guard !line.isEmpty, !isPNSHeaderLine(line) else { continue }
      let collapsed = collapseWhitespace(line)
      return collapsed.isEmpty ? nil : collapsed
    }
    return nil
  }

  private static func isPNSHeaderLine(_ line: String) -> Bool {
    if line == "000" { return true }
    if line.hasPrefix("NOUS") || line.hasPrefix("PNS") || line.hasPrefix("AFD") { return true }
    let lower = line.lowercased()
    if lower.contains("public information statement") { return true }
    if lower.hasPrefix("national weather service") { return true }
    if line.range(of: #"^[A-Z]{2}Z\d"#, options: .regularExpression) != nil { return true }
    if line.range(
      of: #"\d{1,2}:\d{2} [AP]M [A-Z]{3}"#,
      options: .regularExpression
    ) != nil {
      return true
    }
    return false
  }

  private static func collapseWhitespace(_ string: String) -> String {
    string.split { $0.isWhitespace || $0.isNewline }.joined(separator: " ")
  }
}
