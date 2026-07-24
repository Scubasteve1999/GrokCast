import Foundation

/// Client for SPC / NWS ArcGIS MapServer severe products (outlooks, MDs, LSRs).
/// Failures return empty results — never throw into UI layers.
final class SPCSevereService: Sendable {

  private let outlookBase =
    "https://mapservices.weather.noaa.gov/vector/rest/services/outlooks/SPC_wx_outlks/MapServer"
  private let mdBase =
    "https://mapservices.weather.noaa.gov/vector/rest/services/outlooks/spc_mesoscale_discussion/MapServer"
  private let lsrBase =
    "https://mapservices.weather.noaa.gov/vector/rest/services/obs/nws_local_storm_reports/MapServer"

  private let userAgent =
    "SpotterCast/1.0.2 (https://scubasteve1999.github.io/SpotterCast/support/; stephenmoorecm1357@gmail.com)"

  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  // MARK: - Day 1 outlook

  /// Spatial query for Day 1 categorical + tornado/hail/wind probabilities at a point.
  func fetchDay1Outlook(latitude: Double, longitude: Double) async -> SPCDay1Outlook {
    async let categorical = queryHighestDN(
      base: outlookBase, layer: 1, latitude: latitude, longitude: longitude)
    async let tornado = queryHighestDN(
      base: outlookBase, layer: 3, latitude: latitude, longitude: longitude)
    async let hail = queryHighestDN(
      base: outlookBase, layer: 5, latitude: latitude, longitude: longitude)
    async let wind = queryHighestDN(
      base: outlookBase, layer: 7, latitude: latitude, longitude: longitude)

    let cat = await categorical
    let tor = await tornado
    let hailHit = await hail
    let windHit = await wind

    guard let cat else { return .empty }

    return SPCDay1Outlook(
      category: SPCOutlookCategory(dn: cat.dn),
      label: cat.label,
      labelDetail: cat.label2,
      valid: cat.valid,
      expire: cat.expire,
      issue: cat.issue,
      tornadoProbability: tor.flatMap { Self.probabilityPercent(from: $0) },
      hailProbability: hailHit.flatMap { Self.probabilityPercent(from: $0) },
      windProbability: windHit.flatMap { Self.probabilityPercent(from: $0) }
    )
  }

  // MARK: - Mesoscale discussions

  /// MDs intersecting or within `distanceMiles` of the point.
  func fetchMesoscaleDiscussions(
    latitude: Double,
    longitude: Double,
    distanceMiles: Double = 250
  ) async -> [SPCMesoscaleDiscussion] {
    guard
      let features = await queryFeatures(
        urlString: "\(mdBase)/0/query",
        latitude: latitude,
        longitude: longitude,
        distanceMiles: distanceMiles,
        outFields: "objectid,name,folderpath,popupinfo",
        returnGeometry: false,
        resultRecordCount: 12
      )
    else { return [] }

    return features.compactMap { feature in
      let attrs = feature.attributes
      let objectID = attrs.intValue("objectid") ?? Int.random(in: 1...1_000_000)
      let number = attrs.stringValue("name") ?? ""
      let info = attrs.stringValue("folderpath")
      let link = attrs.stringValue("popupinfo")
      guard !number.isEmpty || info != nil || link != nil else { return nil }
      return SPCMesoscaleDiscussion(
        id: "md-\(objectID)",
        number: number,
        info: info,
        linkHTML: link
      )
    }
  }

  // MARK: - Local storm reports

  /// Recent LSRs within `distanceMiles` (last 24h layer).
  func fetchLocalStormReports(
    latitude: Double,
    longitude: Double,
    distanceMiles: Double = 100
  ) async -> [SPCLocalStormReport] {
    guard
      let features = await queryFeatures(
        urlString: "\(lsrBase)/0/query",
        latitude: latitude,
        longitude: longitude,
        distanceMiles: distanceMiles,
        outFields:
          "objectid,descript,loc_desc,state,magnitude,units,remarks,lsr_validtime,valid_time",
        returnGeometry: true,
        resultRecordCount: 25,
        orderByFields: "lsr_validtime DESC"
      )
    else { return [] }

    return features.compactMap { feature in
      let attrs = feature.attributes
      let objectID = attrs.intValue("objectid") ?? Int.random(in: 1...1_000_000)
      let descript = attrs.stringValue("descript") ?? ""
      let lat = feature.geometry?.y ?? feature.geometry?.latitude
      let lon = feature.geometry?.x ?? feature.geometry?.longitude
      let reportedAt = Self.parseLSRDate(
        epochMs: attrs.doubleValue("lsr_validtime"),
        validTime: attrs.stringValue("valid_time")
      )
      return SPCLocalStormReport(
        id: "lsr-\(objectID)",
        description: descript,
        locationDescription: attrs.stringValue("loc_desc"),
        state: attrs.stringValue("state"),
        magnitude: attrs.stringValue("magnitude"),
        units: attrs.stringValue("units"),
        remarks: attrs.stringValue("remarks"),
        reportedAt: reportedAt,
        latitude: lat,
        longitude: lon
      )
    }
  }

  // MARK: - ArcGIS helpers

  private struct OutlookHit {
    let dn: Int
    let label: String?
    let label2: String?
    let valid: String?
    let expire: String?
    let issue: String?
  }

  private func queryHighestDN(
    base: String,
    layer: Int,
    latitude: Double,
    longitude: Double
  ) async -> OutlookHit? {
    guard
      let features = await queryFeatures(
        urlString: "\(base)/\(layer)/query",
        latitude: latitude,
        longitude: longitude,
        distanceMiles: nil,
        outFields: "dn,label,label2,valid,expire,issue",
        returnGeometry: false,
        resultRecordCount: 20
      ), !features.isEmpty
    else { return nil }

    let hits: [OutlookHit] = features.compactMap { feature in
      guard let dn = feature.attributes.intValue("dn") else { return nil }
      return OutlookHit(
        dn: dn,
        label: feature.attributes.stringValue("label"),
        label2: feature.attributes.stringValue("label2"),
        valid: feature.attributes.stringValue("valid"),
        expire: feature.attributes.stringValue("expire"),
        issue: feature.attributes.stringValue("issue")
      )
    }
    return hits.max(by: { $0.dn < $1.dn })
  }

  /// Probabilistic outlook layers use `dn` as the percent contour (2, 5, 10, …).
  private static func probabilityPercent(from hit: OutlookHit) -> Int? {
    if hit.dn > 0 { return hit.dn }
    if let label = hit.label, let parsed = Int(label.filter(\.isNumber)) { return parsed }
    return nil
  }

  private func queryFeatures(
    urlString: String,
    latitude: Double,
    longitude: Double,
    distanceMiles: Double?,
    outFields: String,
    returnGeometry: Bool,
    resultRecordCount: Int,
    orderByFields: String? = nil
  ) async -> [ArcGISFeature]? {
    var components = URLComponents(string: urlString)
    var items: [URLQueryItem] = [
      URLQueryItem(name: "geometry", value: "\(longitude),\(latitude)"),
      URLQueryItem(name: "geometryType", value: "esriGeometryPoint"),
      URLQueryItem(name: "inSR", value: "4326"),
      URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
      URLQueryItem(name: "outFields", value: outFields),
      URLQueryItem(name: "returnGeometry", value: returnGeometry ? "true" : "false"),
      URLQueryItem(name: "resultRecordCount", value: "\(resultRecordCount)"),
      URLQueryItem(name: "f", value: "json"),
    ]
    if let distanceMiles {
      items.append(URLQueryItem(name: "distance", value: "\(distanceMiles)"))
      items.append(URLQueryItem(name: "units", value: "esriSRUnit_StatuteMile"))
    }
    if let orderByFields {
      items.append(URLQueryItem(name: "orderByFields", value: orderByFields))
    }
    components?.queryItems = items

    guard let url = components?.url else { return nil }

    var request = URLRequest(url: url)
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    request.timeoutInterval = 12

    do {
      let (data, response) = try await session.data(for: request)
      guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
        return nil
      }
      let decoded = try JSONDecoder().decode(ArcGISQueryResponse.self, from: data)
      if decoded.error != nil { return nil }
      return decoded.features
    } catch {
      return nil
    }
  }

  private static func parseLSRDate(epochMs: Double?, validTime: String?) -> Date? {
    if let epochMs {
      // ArcGIS dates are ms since epoch
      if epochMs > 1_000_000_000_000 {
        return Date(timeIntervalSince1970: epochMs / 1000)
      }
      if epochMs > 1_000_000_000 {
        return Date(timeIntervalSince1970: epochMs)
      }
    }
    guard let validTime, !validTime.isEmpty else { return nil }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = iso.date(from: validTime) { return d }
    iso.formatOptions = [.withInternetDateTime]
    return iso.date(from: validTime)
  }
}

// MARK: - ArcGIS JSON (tolerant)

private struct ArcGISQueryResponse: Decodable {
  let features: [ArcGISFeature]?
  let error: ArcGISErrorBody?

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    features = try c.decodeIfPresent([ArcGISFeature].self, forKey: .features)
    error = try c.decodeIfPresent(ArcGISErrorBody.self, forKey: .error)
  }

  private enum CodingKeys: String, CodingKey {
    case features, error
  }
}

private struct ArcGISErrorBody: Decodable {
  let code: Int?
  let message: String?
}

private struct ArcGISFeature: Decodable {
  let attributes: [String: ArcGISValue]
  let geometry: ArcGISGeometry?
}

private struct ArcGISGeometry: Decodable {
  let x: Double?
  let y: Double?
  let latitude: Double?
  let longitude: Double?
}

/// Heterogeneous ArcGIS attribute value.
private enum ArcGISValue: Decodable {
  case string(String)
  case int(Int)
  case double(Double)
  case bool(Bool)
  case null

  init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if c.decodeNil() {
      self = .null
      return
    }
    if let v = try? c.decode(Int.self) {
      self = .int(v)
      return
    }
    if let v = try? c.decode(Double.self) {
      self = .double(v)
      return
    }
    if let v = try? c.decode(Bool.self) {
      self = .bool(v)
      return
    }
    if let v = try? c.decode(String.self) {
      self = .string(v)
      return
    }
    self = .null
  }
}

extension Dictionary where Key == String, Value == ArcGISValue {
  fileprivate func stringValue(_ key: String) -> String? {
    guard let value = self[key] else { return nil }
    switch value {
    case .string(let s): return s
    case .int(let i): return String(i)
    case .double(let d): return String(d)
    case .bool(let b): return b ? "true" : "false"
    case .null: return nil
    }
  }

  fileprivate func intValue(_ key: String) -> Int? {
    guard let value = self[key] else { return nil }
    switch value {
    case .int(let i): return i
    case .double(let d): return Int(d)
    case .string(let s): return Int(s)
    default: return nil
    }
  }

  fileprivate func doubleValue(_ key: String) -> Double? {
    guard let value = self[key] else { return nil }
    switch value {
    case .double(let d): return d
    case .int(let i): return Double(i)
    case .string(let s): return Double(s)
    default: return nil
    }
  }
}
