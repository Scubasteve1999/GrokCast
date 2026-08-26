import Foundation

/// One US TV/newspaper market. `domains` are NewsData.io `source_id` values (max 5 per request).
struct USLocalNewsMarket: Equatable, Sendable {
  let name: String
  let latitude: Double
  let longitude: Double
  let domains: [String]
  let aliases: [String]
  let matchTerms: [String]

  func matches(city: String) -> Bool {
    let key = city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !key.isEmpty else { return false }
    if name.lowercased() == key { return true }
    return aliases.contains { $0.lowercased() == key }
  }
}

enum USLocalNewsMarkets {
  static let maxDomains = 5
  /// Olive Branch → Memphis is ~18 mi; keep a wide DMA umbrella.
  static let maxDistanceMiles: Double = 280

  static func market(for location: SavedLocation) -> USLocalNewsMarket? {
    guard NewsDataService.isLikelyUS(location) else { return nil }
    let city = NewsDataParser.place(from: location.name)?.city ?? location.name
    if let named = all.first(where: { $0.matches(city: city) }) {
      return named
    }
    var best: (market: USLocalNewsMarket, miles: Double)?
    for market in all {
      let miles = distanceMiles(
        lat1: location.latitude, lon1: location.longitude,
        lat2: market.latitude, lon2: market.longitude)
      if let current = best {
        if miles < current.miles { best = (market, miles) }
      } else {
        best = (market, miles)
      }
    }
    guard let best, best.miles <= maxDistanceMiles else { return nil }
    return best.market
  }

  static func distanceMiles(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let r = 3958.8
    let p1 = lat1 * .pi / 180
    let p2 = lat2 * .pi / 180
    let dPhi = (lat2 - lat1) * .pi / 180
    let dLam = (lon2 - lon1) * .pi / 180
    let a = sin(dPhi / 2) * sin(dPhi / 2)
      + cos(p1) * cos(p2) * sin(dLam / 2) * sin(dLam / 2)
    return 2 * r * atan2(sqrt(a), sqrt(1 - a))
  }

  static let all: [USLocalNewsMarket] = [
    market(
      "New York", 40.7128, -74.0060,
      ["nypost", "abc7ny", "nbcnewyork", "pix11", "nytimes"],
      ["newark", "jersey city", "yonkers", "hoboken"],
      ["New York", "NYC", "Manhattan"]),
    market(
      "Los Angeles", 34.0522, -118.2437,
      ["latimes", "ktla", "nbcla", "abc7", "foxla"],
      ["long beach", "anaheim", "pasadena", "glendale", "santa monica"],
      ["Los Angeles", "LA", "Southern California"]),
    market(
      "Chicago", 41.8781, -87.6298,
      ["chicagotribune", "abc7chicago", "nbcchicago", "wgn", "suntimes"],
      ["evanston", "naperville", "aurora", "joliet"],
      ["Chicago"]),
    market(
      "Philadelphia", 39.9526, -75.1652,
      ["6abc", "nbcphiladelphia", "fox29", "inquirer"],
      ["camden", "wilmington", "trenton"],
      ["Philadelphia", "Philly"]),
    market(
      "Dallas", 32.7767, -96.7970,
      ["wfaa", "nbcdfw", "fox4news", "dallasnews"],
      ["fort worth", "arlington", "plano", "irving"],
      ["Dallas", "Fort Worth", "DFW"]),
    market(
      "Houston", 29.7604, -95.3698,
      ["khou", "click2houston", "abc13", "houstonchronicle"],
      ["pasadena", "pearland", "sugar land", "the woodlands"],
      ["Houston"]),
    market(
      "Washington", 38.9072, -77.0369,
      ["washingtonpost", "nbcwashington", "wusa9", "wjla", "wtop"],
      ["arlington", "alexandria", "silver spring", "bethesda"],
      ["Washington", "DC", "D.C."]),
    market(
      "Miami", 25.7617, -80.1918,
      ["local10", "nbc6", "miamiherald", "wsvn"],
      ["fort lauderdale", "hialeah", "hollywood", "miami beach"],
      ["Miami", "South Florida"]),
    market(
      "Atlanta", 33.7490, -84.3880,
      ["wsbtv", "11alive", "fox5atlanta", "ajc"],
      ["marietta", "decatur", "sandy springs"],
      ["Atlanta"]),
    market(
      "Boston", 42.3601, -71.0589,
      ["wcvb", "nbcboston", "boston25", "bostonglobe"],
      ["cambridge", "somerville", "quincy", "brookline"],
      ["Boston"]),
    market(
      "San Francisco", 37.7749, -122.4194,
      ["sfgate", "abc7news", "ktvu", "nbcbayarea", "mercurynews"],
      ["oakland", "san jose", "berkeley", "daly city", "fremont", "palo alto"],
      ["San Francisco", "Bay Area", "Oakland"]),
    market(
      "Phoenix", 33.4484, -112.0740,
      ["12news", "abc15", "fox10phoenix", "azcentral"],
      ["mesa", "scottsdale", "tempe", "glendale", "chandler"],
      ["Phoenix"]),
    market(
      "Seattle", 47.6062, -122.3321,
      ["king5", "komonews", "kiro7", "seattletimes"],
      ["bellevue", "tacoma", "everett", "redmond"],
      ["Seattle"]),
    market(
      "Detroit", 42.3314, -83.0458,
      ["wxyz", "clickondetroit", "fox2detroit", "freep"],
      ["dearborn", "warren", "sterling heights"],
      ["Detroit"]),
    market(
      "Minneapolis", 44.9778, -93.2650,
      ["kare11", "kstp", "fox9", "startribune"],
      ["st paul", "saint paul", "bloomington"],
      ["Minneapolis", "St. Paul", "Twin Cities"]),
    market(
      "Tampa", 27.9506, -82.4572,
      ["wfla", "wtsp", "abcactionnews", "tampabay"],
      ["st petersburg", "saint petersburg", "clearwater", "brandon"],
      ["Tampa", "Tampa Bay"]),
    market(
      "Denver", 39.7392, -104.9903,
      ["9news", "denver7", "fox31", "denverpost"],
      ["aurora", "lakewood", "boulder"],
      ["Denver"]),
    market(
      "Orlando", 28.5383, -81.3792,
      ["wesh", "clickorlando", "fox35orlando", "orlandosentinel"],
      ["kissimmee", "sanford"],
      ["Orlando"]),
    market(
      "Cleveland", 41.4993, -81.6944,
      ["news5cleveland", "wkyc", "fox8", "clevelandcom"],
      ["akron", "parma"],
      ["Cleveland"]),
    market(
      "Sacramento", 38.5816, -121.4944,
      ["abc10", "news10", "fox40", "sacbee"],
      ["roseville", "elk grove", "folsom"],
      ["Sacramento"]),
    market(
      "St. Louis", 38.6270, -90.1994,
      ["kmov", "ksdk", "fox2now", "stltoday"],
      ["st charles", "o fallon"],
      ["St. Louis", "Saint Louis"]),
    market(
      "Portland", 45.5152, -122.6784,
      ["katu", "kgw", "fox12oregon", "oregonlive"],
      ["vancouver", "gresham", "beaverton"],
      ["Portland"]),
    market(
      "Charlotte", 35.2271, -80.8431,
      ["wsoctv", "wcnc", "fox46charlotte", "charlotteobserver"],
      ["concord", "gastonia"],
      ["Charlotte"]),
    market(
      "Raleigh", 35.7796, -78.6382,
      ["wral", "abc11", "cbs17", "newsobserver"],
      ["durham", "cary", "chapel hill"],
      ["Raleigh", "Durham"]),
    market(
      "Nashville", 36.1627, -86.7816,
      ["wsmv", "newschannel5", "fox17", "tennessean"],
      ["murfreesboro", "franklin", "hendersonville"],
      ["Nashville"]),
    market(
      "San Diego", 32.7157, -117.1611,
      ["10news", "nbcsandiego", "fox5sandiego"],
      ["chula vista", "oceanside", "escondido"],
      ["San Diego"]),
    market(
      "Austin", 30.2672, -97.7431,
      ["kxan", "kvue", "fox7austin", "statesman"],
      ["round rock", "cedar park"],
      ["Austin"]),
    market(
      "Las Vegas", 36.1699, -115.1398,
      ["8newsnow", "news3lv", "fox5vegas", "reviewjournal"],
      ["henderson", "north las vegas"],
      ["Las Vegas"]),
    market(
      "Kansas City", 39.0997, -94.5786,
      ["kmbc", "kshb", "fox4kc", "kansascity"],
      ["overland park", "olathe", "independence"],
      ["Kansas City"]),
    market(
      "Indianapolis", 39.7684, -86.1581,
      ["wthr", "theindychannel", "fox59", "indystar"],
      ["carmel", "fishers"],
      ["Indianapolis"]),
    market(
      "Columbus", 39.9612, -82.9988,
      ["10tv", "nbc4i", "wsyx", "dispatch"],
      ["dublin", "westerville"],
      ["Columbus"]),
    market(
      "Milwaukee", 43.0389, -87.9065,
      ["jsonline", "tmj4", "fox6now", "cbs58"],
      ["waukesha", "racine"],
      ["Milwaukee"]),
    market(
      "Salt Lake City", 40.7608, -111.8910,
      ["ksl", "fox13now", "abc4utah"],
      ["west valley city", "provo", "ogden"],
      ["Salt Lake City", "Utah"]),
    market(
      "Baltimore", 39.2904, -76.6122,
      ["wbaltv", "wmar", "foxbaltimore", "baltimoresun"],
      ["towson", "columbia"],
      ["Baltimore"]),
    market(
      "Pittsburgh", 40.4406, -79.9959,
      ["wtae", "wpxi", "cbsnews_pittsburgh"],
      ["monroeville"],
      ["Pittsburgh"]),
    market(
      "Cincinnati", 39.1031, -84.5120,
      ["wcpo", "wlwt", "fox19"],
      ["covington"],
      ["Cincinnati"]),
    market(
      "New Orleans", 29.9511, -90.0715,
      ["wwltv", "wdsu", "fox8live", "nola"],
      ["metairie", "kenner", "slidell"],
      ["New Orleans"]),
    market(
      "Memphis", 35.1495, -90.0490,
      ["fox13memphis", "actionnews5", "wreg"],
      [
        "olive branch", "southaven", "germantown", "collierville", "bartlett",
        "horn lake", "west memphis", "hernando", "cordova", "arlington",
      ],
      ["Memphis", "Mid-South", "Shelby County", "Olive Branch", "MLGW"]),
    market(
      "Louisville", 38.2527, -85.7585,
      ["wlky", "wave3", "wdrb"],
      ["jeffersonville", "new albany"],
      ["Louisville"]),
    market(
      "Birmingham", 33.5186, -86.8104,
      ["abc3340", "wvtm13", "wbrc"],
      ["hoover", "vestavia hills"],
      ["Birmingham"]),
    market(
      "Oklahoma City", 35.4676, -97.5164,
      ["koco", "news9", "fox25"],
      ["norman", "edmond"],
      ["Oklahoma City"]),
    market(
      "Little Rock", 34.7465, -92.2896,
      ["kark", "thv11", "fox16"],
      ["north little rock", "conway"],
      ["Little Rock"]),
    market(
      "Jackson", 32.2988, -90.1848,
      ["wlbt", "wapt", "fox40"],
      ["clinton", "ridgeland", "madison"],
      ["Jackson"]),
    market(
      "Tulsa", 36.1540, -95.9928,
      ["ktul", "fox23", "newson6"],
      ["broken arrow"],
      ["Tulsa"]),
  ]

  private static func market(
    _ name: String,
    _ lat: Double,
    _ lon: Double,
    _ domains: [String],
    _ aliases: [String],
    _ matchTerms: [String]
  ) -> USLocalNewsMarket {
    USLocalNewsMarket(
      name: name,
      latitude: lat,
      longitude: lon,
      domains: Array(domains.prefix(maxDomains)),
      aliases: aliases,
      matchTerms: matchTerms
    )
  }
}
