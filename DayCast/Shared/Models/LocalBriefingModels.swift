import Foundation

/// One NWS office product card on Alerts → Local briefing.
/// Stable ids (`afd-{productId}-km{index}` / `pns-{productId}`). Never `UUID()`.
/// `imageURL` is a real `https` image from the source product text, else nil.
struct LocalBriefingItem: Identifiable, Codable, Equatable, Sendable {
  let id: String
  let title: String
  let sourceName: String
  let issuedAt: Date
  let url: URL
  let productCode: String
  let officeID: String
  let imageURL: URL?

  /// Punchy card headline. Publisher news keeps its own title.
  var displayTitle: String { YourNewsHeadline.displayTitle(for: self) }

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

  /// NewsData stories first (photos), then NWS AFD/PNS to fill remaining slots.
  static func mergingNews(_ news: [LocalBriefingItem], nws: [LocalBriefingItem]) -> [LocalBriefingItem] {
    var out: [LocalBriefingItem] = []
    var seen = Set<String>()
    func take(_ item: LocalBriefingItem) {
      guard out.count < maxCards else { return }
      let key = item.title.lowercased()
      guard !seen.contains(key) else { return }
      seen.insert(key)
      out.append(item)
    }
    for item in news { take(item) }
    for item in nws { take(item) }
    return out
  }

  /// `KMEG` / `MEG` match CWA `MEG`. Missing office does not match — fail closed.
  static func issuingOffice(_ office: String?, matchesCWA cwa: String) -> Bool {
    let trimmedCWA = cwa.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard !trimmedCWA.isEmpty else { return false }
    let trimmedOffice = (office ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard !trimmedOffice.isEmpty else { return false }
    return trimmedOffice == trimmedCWA || trimmedOffice == "K\(trimmedCWA)"
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

  /// First KEY MESSAGES bullet, or nil if the block is missing/empty.
  /// Assemble uses the full `keyMessageBullets` list; this remains the one-line wrapper.
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
    var seenTitles = Set<String>()

    if let afd, isAFDFresh(afd.issuedAt, now: now) {
      let bullets = keyMessageBullets(fromAFD: afd.text)
      let afdImageURL = firstImageURL(in: afd.text)
      for (index, title) in bullets.enumerated() {
        if items.count >= maxCards { break }
        guard !title.isEmpty, !seenTitles.contains(title) else { continue }
        seenTitles.insert(title)
        items.append(
          LocalBriefingItem(
            id: "afd-\(afd.id)-km\(index)",
            title: title,
            sourceName: source,
            issuedAt: afd.issuedAt,
            url: productPageURL(cwa: trimmedCWA, productCode: "AFD"),
            productCode: "AFD",
            officeID: trimmedCWA,
            imageURL: afdImageURL
          )
        )
      }
    }

    let sortedPNS = pns.sorted { $0.issuedAt > $1.issuedAt }
    for product in sortedPNS {
      if items.count >= maxCards { break }
      guard isPNSFresh(product.issuedAt, now: now) else { continue }
      guard let title = pnsHeadline(from: product.text), !title.isEmpty else { continue }
      guard shouldKeepPNS(title: title, body: product.text) else { continue }
      guard !seenTitles.contains(title) else { continue }
      seenTitles.insert(title)
      items.append(
        LocalBriefingItem(
          id: "pns-\(product.id)",
          title: title,
          sourceName: source,
          issuedAt: product.issuedAt,
          url: productPageURL(cwa: trimmedCWA, productCode: "PNS"),
          productCode: "PNS",
          officeID: trimmedCWA,
          imageURL: firstImageURL(in: product.text)
        )
      )
    }

    return Array(items.prefix(maxCards))
  }

  /// First obvious image `https` URL in product text. Soft-fail → nil. Never invents.
  static func firstImageURL(in text: String) -> URL? {
    guard let regex = httpsURLRegex else { return nil }
    let ns = text as NSString
    let full = NSRange(location: 0, length: ns.length)
    let matches = regex.matches(in: text, options: [], range: full)
    for match in matches {
      let raw = stripTrailingURLPunctuation(ns.substring(with: match.range))
      guard let url = URL(string: raw), isObviousImageURL(url) else { continue }
      return url
    }
    return nil
  }

  // MARK: - Internals

  private static let httpsURLRegex: NSRegularExpression? = try? NSRegularExpression(
    pattern: #"https://[^\s<>]+"#,
    options: [.caseInsensitive]
  )

  private static let imagePathExtensions: Set<String> = ["jpg", "jpeg", "png", "webp", "gif"]

  private static func stripTrailingURLPunctuation(_ raw: String) -> String {
    var result = raw
    while let last = result.last, ".,;:!?)]}>\"'".contains(last) {
      result.removeLast()
    }
    return result
  }

  private static func isObviousImageURL(_ url: URL) -> Bool {
    guard url.scheme?.lowercased() == "https" else { return false }
    guard let host = url.host?.lowercased(), !host.isEmpty else { return false }
    if imagePathExtensions.contains(url.pathExtension.lowercased()) { return true }
    return isKnownWeatherImageHost(host, path: url.path)
  }

  /// `media.weather.gov` is a media host. Other weather.gov / noaa.gov hosts only
  /// when the path is an image directory — never `product.php` / office pages.
  private static func isKnownWeatherImageHost(_ host: String, path: String) -> Bool {
    if host == "media.weather.gov" || host.hasSuffix(".media.weather.gov") {
      return true
    }
    let isNOAAFamily =
      host == "weather.gov" || host.hasSuffix(".weather.gov")
      || host == "noaa.gov" || host.hasSuffix(".noaa.gov")
    guard isNOAAFamily else { return false }
    let lower = path.lowercased()
    return lower.contains("/images/") || lower.contains("/media/") || lower.contains("/img/")
      || lower.contains("/graphics/")
  }

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
