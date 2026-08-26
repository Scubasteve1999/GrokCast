import Foundation

struct NewsDataLatestResponse: Decodable {
  let status: String
  let results: [NewsDataArticle]?

  private enum CodingKeys: String, CodingKey {
    case status, results
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    status = try container.decode(String.self, forKey: .status)
    results = try? container.decode([NewsDataArticle].self, forKey: .results)
  }
}

struct NewsDataArticle: Decodable, Equatable, Sendable {
  let articleID: String?
  let title: String?
  let link: String?
  let imageURL: String?
  let sourceName: String?
  let sourceID: String?
  let pubDate: String?
  let description: String?

  private enum CodingKeys: String, CodingKey {
    case articleID = "article_id"
    case title
    case link
    case imageURL = "image_url"
    case sourceName = "source_name"
    case sourceID = "source_id"
    case pubDate
    case description
  }
}

/// City / metro / state tokens for a NewsData query. Free-plan `q` max is 100 chars.
struct NewsDataPlace: Equatable, Sendable {
  let city: String
  let stateAbbr: String?
  let stateName: String?
  let metro: String?
  let extraMatch: [String]

  var matchTerms: [String] {
    var terms: [String] = []
    func add(_ raw: String?) {
      guard let raw else { return }
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return }
      if terms.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
        return
      }
      terms.append(trimmed)
    }
    add(city)
    add(metro)
    extraMatch.forEach { add($0) }
    return terms
  }
}

enum NewsDataParser {
  static let productCode = "NEWS"
  static let officeID = "newsdata"
  static let maxQueryLength = 100

  private static let weatherTokens = [
    "tornado", "hurricane", "tropical storm", "thunderstorm", "flash flood",
    "wildfire", "blizzard", "drought", "lightning", "hail", "heat wave",
    "heatwave", "winter storm", "severe weather", "cyclone", "typhoon",
    "monsoon", "nor'easter", "flood", "weather", "storm",
  ]

  /// Small-town weather market when the city itself rarely makes a headline.
  private static let metroByCity: [String: String] = [
    "olive branch": "Memphis",
    "southaven": "Memphis",
    "horn lake": "Memphis",
    "hernando": "Memphis",
    "collierville": "Memphis",
    "germantown": "Memphis",
    "bartlett": "Memphis",
    "west memphis": "Memphis",
  ]

  private static let extraMatchByCity: [String: [String]] = [
    "olive branch": ["Mid-South", "Shelby County", "MLGW"],
    "southaven": ["Mid-South", "DeSoto County", "MLGW"],
    "horn lake": ["Mid-South", "DeSoto County", "MLGW"],
    "hernando": ["Mid-South", "DeSoto County"],
    "collierville": ["Mid-South", "Shelby County", "MLGW"],
    "germantown": ["Mid-South", "Shelby County", "MLGW"],
    "bartlett": ["Mid-South", "Shelby County", "MLGW"],
    "west memphis": ["Mid-South", "MLGW"],
  ]

  private static let stateNames: [String: String] = [
    "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas",
    "CA": "California", "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware",
    "DC": "District of Columbia", "FL": "Florida", "GA": "Georgia", "HI": "Hawaii",
    "ID": "Idaho", "IL": "Illinois", "IN": "Indiana", "IA": "Iowa",
    "KS": "Kansas", "KY": "Kentucky", "LA": "Louisiana", "ME": "Maine",
    "MD": "Maryland", "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota",
    "MS": "Mississippi", "MO": "Missouri", "MT": "Montana", "NE": "Nebraska",
    "NV": "Nevada", "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico",
    "NY": "New York", "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio",
    "OK": "Oklahoma", "OR": "Oregon", "PA": "Pennsylvania", "RI": "Rhode Island",
    "SC": "South Carolina", "SD": "South Dakota", "TN": "Tennessee", "TX": "Texas",
    "UT": "Utah", "VT": "Vermont", "VA": "Virginia", "WA": "Washington",
    "WV": "West Virginia", "WI": "Wisconsin", "WY": "Wyoming",
  ]

  static func place(from locationName: String) -> NewsDataPlace? {
    let trimmed = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if trimmed.caseInsensitiveCompare("Current Location") == .orderedSame { return nil }

    var city = trimmed
    var stateAbbr: String?
    if let comma = trimmed.lastIndex(of: ",") {
      let before = String(trimmed[..<comma]).trimmingCharacters(in: .whitespacesAndNewlines)
      let after = String(trimmed[trimmed.index(after: comma)...])
        .trimmingCharacters(in: .whitespacesAndNewlines)
      if !before.isEmpty { city = before }
      let code = after.uppercased()
      if stateNames[code] != nil { stateAbbr = code }
    }
    guard !city.isEmpty else { return nil }
    let key = city.lowercased()
    let metro = metroByCity[key]
    let extra = extraMatchByCity[key] ?? []
    let stateName = stateAbbr.flatMap { stateNames[$0] }
    return NewsDataPlace(
      city: city,
      stateAbbr: stateAbbr,
      stateName: stateName,
      metro: metro,
      extraMatch: extra
    )
  }

  static func searchQuery(for place: NewsDataPlace) -> String {
    let weatherFull = "weather OR storm OR tornado OR flood"
    let weatherShort = "weather OR storm"
    var places: [String] = [place.city]
    if let metro = place.metro, metro.caseInsensitiveCompare(place.city) != .orderedSame {
      places.append(metro)
    }

    let candidates = [
      combinedQuery(places: places, weather: weatherFull),
      combinedQuery(places: places, weather: weatherShort),
      combinedQuery(places: Array(places.prefix(2)), weather: weatherShort),
      combinedQuery(places: [place.city], weather: weatherShort),
    ]
    if let fit = candidates.first(where: { $0.count <= maxQueryLength }) {
      return fit
    }
    let fallback = "\(quoted(place.city)) AND weather"
    return String(fallback.prefix(maxQueryLength))
  }

  static func mentionsPlace(title: String, description: String?, terms: [String]) -> Bool {
    guard !terms.isEmpty else { return true }
    let hay = fold(title + " " + (description ?? ""))
    for term in terms {
      let needle = fold(term)
      guard !needle.isEmpty else { continue }
      if needle.count <= 2 {
        if hay.range(of: "\\b\(NSRegularExpression.escapedPattern(for: needle))\\b", options: .regularExpression)
          != nil
        {
          return true
        }
      } else if hay.contains(needle) {
        return true
      }
    }
    return false
  }

  static func isWeatherStory(title: String, description: String?) -> Bool {
    let hay = (title + " " + (description ?? "")).lowercased()
    return weatherTokens.contains { hay.contains($0) }
  }

  private static func combinedQuery(places: [String], weather: String) -> String {
    let clause = places.map(quoted).joined(separator: " OR ")
    return "(\(clause)) AND (\(weather))"
  }

  private static func quoted(_ raw: String) -> String {
    raw.contains(where: { $0.isWhitespace }) ? "\"\(raw)\"" : raw
  }

  private static func fold(_ raw: String) -> String {
    raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
  }

  static func parsePubDate(_ raw: String?) -> Date? {
    guard let raw, !raw.isEmpty else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    if let date = formatter.date(from: raw) { return date }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: raw) { return date }
    iso.formatOptions = [.withInternetDateTime]
    return iso.date(from: raw)
  }

  static func displaySource(name: String?, id: String?) -> String {
    let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if trimmed.isEmpty || trimmed.lowercased().hasPrefix("http") {
      let fallback = id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      return fallback.isEmpty ? "News" : fallback
    }
    return trimmed
  }

  static func items(
    from articles: [NewsDataArticle],
    place: NewsDataPlace? = nil,
    requirePlaceMention: Bool = false,
    now: Date = Date()
  ) -> [LocalBriefingItem] {
    let terms = place?.matchTerms ?? []
    var seenTitles = Set<String>()
    var scored: [(item: LocalBriefingItem, score: Int)] = []
    for article in articles {
      guard let title = article.title?.trimmingCharacters(in: .whitespacesAndNewlines),
        !title.isEmpty,
        isWeatherStory(title: title, description: article.description),
        !requirePlaceMention
          || mentionsPlace(title: title, description: article.description, terms: terms),
        let link = article.link.flatMap(URL.init(string:)),
        link.scheme == "https",
        let issued = parsePubDate(article.pubDate) ?? Optional(now)
      else { continue }
      let folded = title.lowercased()
      guard !seenTitles.contains(folded) else { continue }
      seenTitles.insert(folded)
      let imageURL = article.imageURL.flatMap(URL.init(string:)).flatMap { url in
        url.scheme == "https" ? url : nil
      }
      let id = article.articleID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? folded
      let item = LocalBriefingItem(
        id: "news-\(id)",
        title: title,
        sourceName: displaySource(name: article.sourceName, id: article.sourceID),
        issuedAt: issued,
        url: link,
        productCode: productCode,
        officeID: officeID,
        imageURL: imageURL
      )
      let score = localityScore(
        title: title, description: article.description, place: place)
      scored.append((item, score))
    }
    return scored.sorted { lhs, rhs in
      if lhs.score != rhs.score { return lhs.score > rhs.score }
      return (lhs.item.imageURL != nil ? 0 : 1) < (rhs.item.imageURL != nil ? 0 : 1)
    }.prefix(LocalBriefingParser.maxCards).map(\.item)
  }

  static func localityScore(title: String, description: String?, place: NewsDataPlace?) -> Int {
    guard let place else { return 0 }
    let t = fold(title)
    let d = fold(description ?? "")
    func hit(_ raw: String, titleWeight: Int) -> Int {
      let needle = fold(raw)
      guard needle.count >= 3 else { return 0 }
      if t.contains(needle) { return titleWeight }
      if d.contains(needle) { return 1 }
      return 0
    }
    var score = hit(place.city, titleWeight: 5)
    if let metro = place.metro { score += hit(metro, titleWeight: 4) }
    for extra in place.extraMatch { score += hit(extra, titleWeight: 2) }
    return score
  }
}
