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

enum NewsDataParser {
  static let productCode = "NEWS"
  static let officeID = "newsdata"

  private static let weatherTokens = [
    "tornado", "hurricane", "tropical storm", "thunderstorm", "flash flood",
    "wildfire", "blizzard", "drought", "lightning", "hail", "heat wave",
    "heatwave", "winter storm", "severe weather", "cyclone", "typhoon",
    "monsoon", "nor'easter", "flood", "weather", "storm",
  ]

  static func isWeatherStory(title: String, description: String?) -> Bool {
    let hay = (title + " " + (description ?? "")).lowercased()
    return weatherTokens.contains { hay.contains($0) }
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

  static func items(from articles: [NewsDataArticle], now: Date = Date()) -> [LocalBriefingItem] {
    var seenTitles = Set<String>()
    var items: [LocalBriefingItem] = []
    for article in articles {
      if items.count >= LocalBriefingParser.maxCards { break }
      guard let title = article.title?.trimmingCharacters(in: .whitespacesAndNewlines),
        !title.isEmpty,
        isWeatherStory(title: title, description: article.description),
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
      items.append(
        LocalBriefingItem(
          id: "news-\(id)",
          title: title,
          sourceName: displaySource(name: article.sourceName, id: article.sourceID),
          issuedAt: issued,
          url: link,
          productCode: productCode,
          officeID: officeID,
          imageURL: imageURL
        )
      )
    }
    return items
  }
}
