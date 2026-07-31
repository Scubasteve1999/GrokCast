import CoreLocation
import Foundation

enum NIFCFireServiceError: Error {
  case badResponse
}

/// NIFC WFIGS FeatureServer queries — tight envelope + `resultOffset` pagination.
enum NIFCFireService {
  private static let locationsURL =
    "https://services3.arcgis.com/T4QMspbfLg3qTGWY/arcgis/rest/services/WFIGS_Incident_Locations_Current/FeatureServer/0/query"
  private static let perimetersURL =
    "https://services3.arcgis.com/T4QMspbfLg3qTGWY/arcgis/rest/services/WFIGS_Interagency_Perimeters_Current/FeatureServer/0/query"

  private static let pageSize = 1000
  private static let maxPages = 10
  /// Same regional window as FIRMS by default.
  static let defaultHalfSpanDegrees = 1.5

  private static let browserHeaders: [String: String] = [
    "User-Agent":
      "SpotterCast/1.0 (iOS; weather; +https://github.com/Scubasteve1999/GrokCast)",
    "Accept": "application/geo+json, application/json",
  ]

  static func fetchIncidents(
    around center: CLLocationCoordinate2D,
    session: URLSession = .shared
  ) async throws -> [FireIncident] {
    let bounds = GeographicBounds.square(around: center, halfSpanDegrees: defaultHalfSpanDegrees)
    let features = try await fetchAllGeoJSONFeatures(
      baseURL: locationsURL,
      bounds: bounds,
      outFields:
        "IncidentName,UniqueFireIdentifier,POOLatitude,POOLongitude,IncidentSize,PercentContained,FireCause,FireDiscoveryDateTime,ModifiedOnDateTime_dt,IrwinID",
      session: session
    )
    return features.compactMap(NIFCGeoJSONParser.incident(from:))
  }

  static func fetchPerimeters(
    around center: CLLocationCoordinate2D,
    session: URLSession = .shared
  ) async throws -> [FirePerimeter] {
    let bounds = GeographicBounds.square(around: center, halfSpanDegrees: defaultHalfSpanDegrees)
    let features = try await fetchAllGeoJSONFeatures(
      baseURL: perimetersURL,
      bounds: bounds,
      outFields:
        "poly_IncidentName,poly_GISAcres,attr_PercentContained,attr_FireDiscoveryDateTime,poly_DateCurrent,GlobalID,OBJECTID",
      session: session
    )
    return features.compactMap(NIFCGeoJSONParser.perimeter(from:))
  }

  private static func fetchAllGeoJSONFeatures(
    baseURL: String,
    bounds: GeographicBounds,
    outFields: String,
    session: URLSession
  ) async throws -> [[String: Any]] {
    var offset = 0
    var all: [[String: Any]] = []

    for _ in 0..<maxPages {
      guard var components = URLComponents(string: baseURL) else { break }
      components.queryItems = [
        URLQueryItem(name: "where", value: "1=1"),
        URLQueryItem(name: "geometry", value: "\(bounds.west),\(bounds.south),\(bounds.east),\(bounds.north)"),
        URLQueryItem(name: "geometryType", value: "esriGeometryEnvelope"),
        URLQueryItem(name: "inSR", value: "4326"),
        URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
        URLQueryItem(name: "outFields", value: outFields),
        URLQueryItem(name: "returnGeometry", value: "true"),
        URLQueryItem(name: "outSR", value: "4326"),
        URLQueryItem(name: "geometryPrecision", value: "4"),
        URLQueryItem(name: "f", value: "geojson"),
        URLQueryItem(name: "resultRecordCount", value: "\(pageSize)"),
        URLQueryItem(name: "resultOffset", value: "\(offset)"),
      ]
      guard let url = components.url else { break }

      var request = URLRequest(url: url)
      for (key, value) in browserHeaders {
        request.setValue(value, forHTTPHeaderField: key)
      }

      let (data, response) = try await session.data(for: request)
      if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        throw NIFCFireServiceError.badResponse
      }

      guard
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let features = root["features"] as? [[String: Any]]
      else {
        throw NIFCFireServiceError.badResponse
      }

      all.append(contentsOf: features)
      if features.count < pageSize { break }
      offset += features.count
    }

    return all
  }
}

enum NIFCGeoJSONParser {
  static func incident(from feature: [String: Any]) -> FireIncident? {
    let props = feature["properties"] as? [String: Any] ?? [:]
    let geometry = feature["geometry"] as? [String: Any]
    let coords = geometry?["coordinates"] as? [Any]

    let lat =
      double(props["POOLatitude"])
      ?? (coords?.count == 2 ? double(coords?[1]) : nil)
    let lon =
      double(props["POOLongitude"])
      ?? (coords?.count == 2 ? double(coords?[0]) : nil)

    let irwin = string(props["IrwinID"]) ?? string(props["UniqueFireIdentifier"])
    let name = string(props["IncidentName"])
    let id =
      irwin
      ?? name.map { "name:\($0)" }
      ?? "incident-\(lat ?? 0)-\(lon ?? 0)"

    return FireIncident(
      id: id,
      name: name,
      latitude: lat,
      longitude: lon,
      acres: double(props["IncidentSize"]),
      percentContained: double(props["PercentContained"]),
      cause: string(props["FireCause"]),
      discoveryDate: date(props["FireDiscoveryDateTime"]),
      updatedAt: date(props["ModifiedOnDateTime_dt"]),
      irwinID: irwin
    )
  }

  static func perimeter(from feature: [String: Any]) -> FirePerimeter? {
    guard let geometry = feature["geometry"] as? [String: Any],
      let geometryData = try? JSONSerialization.data(withJSONObject: geometry)
    else { return nil }

    let props = feature["properties"] as? [String: Any] ?? [:]
    let id =
      string(props["GlobalID"])
      ?? string(props["OBJECTID"]).map { "object-\($0)" }
      ?? UUID().uuidString

    return FirePerimeter(
      id: id,
      incidentName: string(props["poly_IncidentName"]),
      acres: double(props["poly_GISAcres"]),
      percentContained: double(props["attr_PercentContained"]),
      updatedAt: date(props["poly_DateCurrent"]) ?? date(props["attr_FireDiscoveryDateTime"]),
      geometryJSONData: geometryData
    )
  }

  private static func string(_ value: Any?) -> String? {
    if let s = value as? String {
      let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
      return t.isEmpty ? nil : t
    }
    if let n = value as? NSNumber { return n.stringValue }
    return nil
  }

  private static func double(_ value: Any?) -> Double? {
    if let d = value as? Double { return d }
    if let i = value as? Int { return Double(i) }
    if let n = value as? NSNumber { return n.doubleValue }
    if let s = value as? String { return Double(s) }
    return nil
  }

  private static func date(_ value: Any?) -> Date? {
    if let ms = double(value), ms > 1_000_000_000_000 {
      return Date(timeIntervalSince1970: ms / 1000)
    }
    if let s = string(value) {
      let iso = ISO8601DateFormatter()
      iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      if let d = iso.date(from: s) { return d }
      iso.formatOptions = [.withInternetDateTime]
      return iso.date(from: s)
    }
    return nil
  }
}
