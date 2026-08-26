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

  func testOliveBranchPlaceUsesMemphisMarket() {
    let place = NewsDataParser.place(from: "Olive Branch, MS")
    XCTAssertEqual(place?.city, "Olive Branch")
    XCTAssertEqual(place?.stateAbbr, "MS")
    XCTAssertEqual(place?.stateName, "Mississippi")
    XCTAssertEqual(place?.metro, "Memphis")
    XCTAssertTrue(place?.matchTerms.contains("Memphis") == true)
    XCTAssertFalse(place?.matchTerms.contains("MS") == true)
    let q = NewsDataParser.searchQuery(for: place!)
    XCTAssertLessThanOrEqual(q.count, NewsDataParser.maxQueryLength)
    XCTAssertTrue(q.contains("Olive Branch"))
    XCTAssertTrue(q.contains("Memphis"))
    XCTAssertTrue(q.contains("weather"))
    XCTAssertFalse(q.contains("Mississippi"))
  }

  func testSanFranciscoPlaceUsesCalifornia() {
    let place = NewsDataParser.place(from: "San Francisco, CA")
    XCTAssertEqual(place?.city, "San Francisco")
    XCTAssertEqual(place?.stateName, "California")
    XCTAssertNil(place?.metro)
    XCTAssertEqual(place?.matchTerms, ["San Francisco"])
    let q = NewsDataParser.searchQuery(for: place!)
    XCTAssertLessThanOrEqual(q.count, NewsDataParser.maxQueryLength)
    XCTAssertTrue(q.contains("San Francisco"))
    XCTAssertTrue(q.contains("weather"))
    XCTAssertFalse(q.contains("California"))
  }

  func testCurrentLocationHasNoPlace() {
    XCTAssertNil(NewsDataParser.place(from: "Current Location"))
  }

  func testDropsStoriesThatDoNotMentionTheCity() {
    let place = NewsDataParser.place(from: "Olive Branch, MS")!
    let articles = [
      NewsDataArticle(
        articleID: "eu",
        title: "Extreme weather in Europe breaks heat records",
        link: "https://example.com/europe",
        imageURL: "https://cdn.example.com/eu.jpg",
        sourceName: "WSJ",
        sourceID: "wsj",
        pubDate: "2026-08-25 12:00:00",
        description: "A heat wave across southern Europe."),
      NewsDataArticle(
        articleID: "ms",
        title: "Mississippi heat wave breaks records",
        link: "https://example.com/ms-heat",
        imageURL: "https://cdn.example.com/ms.jpg",
        sourceName: "AP",
        sourceID: "ap",
        pubDate: "2026-08-25 12:00:00",
        description: "Statewide heat."),
      NewsDataArticle(
        articleID: "in",
        title: "Powerful storms knocked out power in northwest Indiana",
        link: "https://example.com/indiana",
        imageURL: "https://cdn.example.com/in.jpg",
        sourceName: "CNN",
        sourceID: "cnn",
        pubDate: "2026-08-25 12:00:00",
        description: nil),
      NewsDataArticle(
        articleID: "fox",
        title: "FOX13 lists Mid-South food distribution sites following weekend storm",
        link: "https://example.com/fox13",
        imageURL: "https://cdn.example.com/fox.jpg",
        sourceName: "FOX13",
        sourceID: "fox13",
        pubDate: "2026-08-25 11:00:00",
        description: nil),
      NewsDataArticle(
        articleID: "mem",
        title: "Storms roll through Memphis this evening",
        link: "https://example.com/memphis",
        imageURL: "https://cdn.example.com/mem.jpg",
        sourceName: "WMC",
        sourceID: "wmc",
        pubDate: "2026-08-25 12:00:00",
        description: "Olive Branch under a severe thunderstorm watch."),
    ]
    let items = NewsDataParser.items(from: articles, place: place, requirePlaceMention: true)
    XCTAssertEqual(
      items.map(\.title),
      [
        "Storms roll through Memphis this evening",
        "FOX13 lists Mid-South food distribution sites following weekend storm",
      ]
    )
  }

  func testOliveBranchMapsToMemphisLocalStations() {
    let market = USLocalNewsMarkets.market(for: .oliveBranch)
    XCTAssertEqual(market?.name, "Memphis")
    XCTAssertTrue(market?.domains.contains("fox13memphis") == true)
    XCTAssertTrue(market?.domains.contains("actionnews5") == true)
    XCTAssertLessThanOrEqual(market?.domains.count ?? 99, USLocalNewsMarkets.maxDomains)
  }

  func testSanFranciscoMapsToBayAreaMarket() {
    let sf = SavedLocation(name: "San Francisco, CA", latitude: 37.7749, longitude: -122.4194)
    XCTAssertEqual(USLocalNewsMarkets.market(for: sf)?.name, "San Francisco")
  }

  func testLondonHasNoUSMarket() {
    let london = SavedLocation(name: "London", latitude: 51.5074, longitude: -0.1278)
    XCTAssertNil(USLocalNewsMarkets.market(for: london))
  }

  func testLocalStationWeatherDoesNotNeedCityInHeadline() {
    let articles = [
      NewsDataArticle(
        articleID: "mlgw",
        title: "Over 25k customers still without power as MLGW faces storm aftermath",
        link: "https://www.actionnews5.com/storm",
        imageURL: "https://cdn.example.com/storm.jpg",
        sourceName: "Action News 5",
        sourceID: "actionnews5",
        pubDate: "2026-08-25 12:00:00",
        description: nil),
      NewsDataArticle(
        articleID: "crime",
        title: "Man injured after car slams into barbershop in Whitehaven",
        link: "https://www.actionnews5.com/crime",
        imageURL: "https://cdn.example.com/crime.jpg",
        sourceName: "Action News 5",
        sourceID: "actionnews5",
        pubDate: "2026-08-25 12:00:00",
        description: nil),
    ]
    let items = NewsDataParser.items(
      from: articles,
      place: NewsDataParser.place(from: "Olive Branch, MS"),
      requirePlaceMention: false
    )
    XCTAssertEqual(
      items.map(\.title),
      ["Over 25k customers still without power as MLGW faces storm aftermath"]
    )
  }

  func testParsesInvalidDomainListFrom422() throws {
    let json = """
      {"status":"error","results":{"message":"The domain you provided does not exist in our database.","code":"UnsupportedFilter","invalid_domain":"abc24,wmc"}}
      """.data(using: .utf8)!
    XCTAssertEqual(NewsDataErrorBody.invalidDomains(in: json), ["abc24", "wmc"])
  }

  func testOliveBranchCoordsCountAsUS() {
    XCTAssertTrue(NewsDataService.isLikelyUS(.oliveBranch))
    let london = SavedLocation(name: "London", latitude: 51.5074, longitude: -0.1278)
    XCTAssertFalse(NewsDataService.isLikelyUS(london))
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
