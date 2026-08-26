import XCTest

@testable import DayCast

final class NewsDataParserTests: XCTestCase {
  func testDecodesLatestPayloadAndKeepsWeatherWithImage() throws {
    let json = """
      {
        "status": "success",
        "results": [
          {
            "article_id": "abc",
            "title": "Tropical Storm Julio forms in the Pacific",
            "link": "https://apnews.com/article/julio",
            "image_url": "https://cdn.example.com/julio.jpg",
            "source_name": "Associated Press",
            "source_id": "apnews",
            "pubDate": "2026-08-25 12:52:00",
            "description": "The storm is not threatening land."
          },
          {
            "article_id": "songs",
            "title": "Australia bans fully AI-generated songs from charts",
            "link": "https://apnews.com/article/songs",
            "image_url": "https://cdn.example.com/songs.jpg",
            "source_name": "Apnews",
            "source_id": "apnews",
            "pubDate": "2026-08-25 12:00:00",
            "description": "Charts only."
          }
        ]
      }
      """.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(NewsDataLatestResponse.self, from: json)
    XCTAssertEqual(decoded.status, "success")
    let items = NewsDataParser.items(from: decoded.results ?? [])
    XCTAssertEqual(items.map(\.title), ["Tropical Storm Julio forms in the Pacific"])
    XCTAssertEqual(items.first?.sourceName, "Associated Press")
    XCTAssertEqual(items.first?.productCode, "NEWS")
    XCTAssertEqual(items.first?.imageURL?.absoluteString, "https://cdn.example.com/julio.jpg")
    XCTAssertEqual(items.first?.displayTitle, items.first?.title)
  }

  func testDropsHttpImageAndHttpLink() {
    let articles = [
      NewsDataArticle(
        articleID: "1",
        title: "Hurricane watch issued",
        link: "http://example.com/hurricane",
        imageURL: "https://cdn.example.com/a.jpg",
        sourceName: "AP",
        sourceID: "ap",
        pubDate: "2026-08-25 12:00:00",
        description: nil),
      NewsDataArticle(
        articleID: "2",
        title: "Tornado warning for the county",
        link: "https://example.com/tornado",
        imageURL: "http://cdn.example.com/b.jpg",
        sourceName: "AP",
        sourceID: "ap",
        pubDate: "2026-08-25 12:00:00",
        description: nil),
    ]
    let items = NewsDataParser.items(from: articles)
    XCTAssertEqual(items.count, 1)
    XCTAssertEqual(items[0].title, "Tornado warning for the county")
    XCTAssertNil(items[0].imageURL)
  }

  func testDedupesSyndicatedTitleAndFillsFromNWS() {
    let news = [
      newsItem(id: "a", title: "Tropical Storm Julio forms"),
      newsItem(id: "b", title: "Tropical Storm Julio forms"),
    ]
    let nws = [
      newsItem(id: "nws", title: "Mid-South storms Wednesday", code: "AFD", office: "MEG")
    ]
    let merged = LocalBriefingParser.mergingNews(news, nws: nws)
    XCTAssertEqual(merged.map(\.title), [
      "Tropical Storm Julio forms",
      "Mid-South storms Wednesday",
    ])
  }

  func testHttpSourceNameFallsBackToID() {
    XCTAssertEqual(
      NewsDataParser.displaySource(name: "Https://www.knoe.com", id: "knoe"),
      "knoe")
    XCTAssertEqual(
      NewsDataParser.displaySource(name: "Popular Science", id: "popsci"),
      "Popular Science")
  }

  func testErrorPayloadDoesNotThrow() throws {
    let json = """
      {"status":"error","results":{"message":"The provided API key is not valid.","code":"Unauthorized"}}
      """.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(NewsDataLatestResponse.self, from: json)
    XCTAssertEqual(decoded.status, "error")
    XCTAssertNil(decoded.results)
  }

  private func newsItem(
    id: String, title: String, code: String = "NEWS", office: String = "newsdata"
  ) -> LocalBriefingItem {
    LocalBriefingItem(
      id: id,
      title: title,
      sourceName: "AP",
      issuedAt: Date(),
      url: URL(string: "https://example.com/\(id)")!,
      productCode: code,
      officeID: office,
      imageURL: URL(string: "https://cdn.example.com/\(id).jpg")
    )
  }
}
