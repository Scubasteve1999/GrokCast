import Foundation

/// NewsData.io latest-news fetch for Your News. Key lives in gitignored `DeveloperAPIKey`.
enum NewsDataService {
  static var isConfigured: Bool {
    guard let key = DeveloperAPIKey.newsData?.trimmingCharacters(in: .whitespacesAndNewlines)
    else { return false }
    return !key.isEmpty
  }

  static func fetchWeatherArticles() async -> [NewsDataArticle] {
    guard isConfigured,
      let key = DeveloperAPIKey.newsData,
      var comps = URLComponents(string: "https://newsdata.io/api/1/latest")
    else { return [] }
    comps.queryItems = [
      URLQueryItem(name: "apikey", value: key),
      URLQueryItem(
        name: "q",
        value: "tornado OR hurricane OR thunderstorm OR wildfire OR flood OR weather"),
      URLQueryItem(name: "country", value: "us"),
      URLQueryItem(name: "language", value: "en"),
    ]
    guard let url = comps.url else { return [] }
    do {
      var request = URLRequest(url: url)
      request.setValue("DayCast/1.0 (https://daycast.app)", forHTTPHeaderField: "User-Agent")
      request.timeoutInterval = 15
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
        return []
      }
      let decoded = try JSONDecoder().decode(NewsDataLatestResponse.self, from: data)
      guard decoded.status == "success" else { return [] }
      return decoded.results ?? []
    } catch {
      return []
    }
  }
}
