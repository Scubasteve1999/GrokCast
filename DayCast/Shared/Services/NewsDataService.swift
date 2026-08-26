import Foundation

/// NewsData.io latest-news fetch for Your News. Key lives in gitignored `DeveloperAPIKey`.
enum NewsDataService {
  static let weatherQuery = "weather OR storm OR tornado OR flood"

  static var isConfigured: Bool {
    guard let key = DeveloperAPIKey.newsData?.trimmingCharacters(in: .whitespacesAndNewlines)
    else { return false }
    return !key.isEmpty
  }

  static func fetchWeatherArticles(for location: SavedLocation) async -> [NewsDataArticle] {
    guard isConfigured, isLikelyUS(location) else { return [] }
    if let market = USLocalNewsMarkets.market(for: location) {
      let local = await latest(query: weatherQuery, domains: market.domains)
      if !local.isEmpty { return local }
    }
    guard let place = NewsDataParser.place(from: location.name) else { return [] }
    return await latest(query: NewsDataParser.searchQuery(for: place), domains: [])
  }

  /// CONUS bbox, or a US state suffix on the saved name (`Olive Branch, MS`).
  static func isLikelyUS(_ location: SavedLocation) -> Bool {
    if NewsDataParser.place(from: location.name)?.stateAbbr != nil { return true }
    return (24.4...49.5).contains(location.latitude)
      && (-125.0...(-66.0)).contains(location.longitude)
  }

  private static func latest(query: String, domains: [String]) async -> [NewsDataArticle] {
    var remaining = Array(domains.prefix(USLocalNewsMarkets.maxDomains))
    for _ in 0..<3 {
      let outcome = await request(query: query, domains: remaining)
      switch outcome {
      case .articles(let articles):
        return articles
      case .invalidDomains(let bad):
        let dropped = Set(bad.map { $0.lowercased() })
        remaining = remaining.filter { !dropped.contains($0.lowercased()) }
        if remaining.isEmpty { return [] }
      case .failed:
        return []
      }
    }
    return []
  }

  private enum Outcome {
    case articles([NewsDataArticle])
    case invalidDomains([String])
    case failed
  }

  private static func request(query: String, domains: [String]) async -> Outcome {
    guard let key = DeveloperAPIKey.newsData,
      var comps = URLComponents(string: "https://newsdata.io/api/1/latest")
    else { return .failed }
    var items = [
      URLQueryItem(name: "apikey", value: key),
      URLQueryItem(name: "q", value: query),
      URLQueryItem(name: "language", value: "en"),
      URLQueryItem(name: "country", value: "us"),
    ]
    if !domains.isEmpty {
      items.append(URLQueryItem(name: "domain", value: domains.joined(separator: ",")))
    }
    comps.queryItems = items
    guard let url = comps.url else { return .failed }
    do {
      var request = URLRequest(url: url)
      request.setValue("DayCast/1.0 (https://daycast.app)", forHTTPHeaderField: "User-Agent")
      request.timeoutInterval = 15
      let (data, response) = try await URLSession.shared.data(for: request)
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      if status == 422 {
        return .invalidDomains(NewsDataErrorBody.invalidDomains(in: data))
      }
      guard (200...299).contains(status) else { return .failed }
      let decoded = try JSONDecoder().decode(NewsDataLatestResponse.self, from: data)
      guard decoded.status == "success" else { return .failed }
      return .articles(decoded.results ?? [])
    } catch {
      return .failed
    }
  }
}

struct NewsDataErrorBody: Decodable {
  let status: String
  let results: NewsDataErrorResults?

  static func invalidDomains(in data: Data) -> [String] {
    guard let body = try? JSONDecoder().decode(NewsDataErrorBody.self, from: data) else {
      return []
    }
    return body.results?.invalidDomains ?? []
  }
}

enum NewsDataErrorResults: Decodable {
  case detail(NewsDataErrorDetail)
  case details([NewsDataErrorDetail])

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let one = try? container.decode(NewsDataErrorDetail.self) {
      self = .detail(one)
      return
    }
    if let many = try? container.decode([NewsDataErrorDetail].self) {
      self = .details(many)
      return
    }
    self = .details([])
  }

  var invalidDomains: [String] {
    let details: [NewsDataErrorDetail]
    switch self {
    case .detail(let one): details = [one]
    case .details(let many): details = many
    }
    return details.flatMap(\.invalidDomains)
  }
}

struct NewsDataErrorDetail: Decodable {
  let message: String?
  let code: String?
  let invalidDomain: String?

  private enum CodingKeys: String, CodingKey {
    case message, code
    case invalidDomain = "invalid_domain"
  }

  var invalidDomains: [String] {
    (invalidDomain ?? "")
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}
