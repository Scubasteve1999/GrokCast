import CoreLocation
import Foundation

enum FIRMSServiceError: Error {
  case missingKey
  case quotaExceeded
  case badResponse
}

/// NASA FIRMS area CSV — bbox only (never `world`). Quiet on missing key / quota.
enum FIRMSService {
  static let dayRange = 2
  /// ~150 km half-span at mid-latitudes — enough for regional context without burning MAP_KEY quota.
  static let defaultHalfSpanDegrees = 1.5

  private static let sources = [
    "VIIRS_NOAA20_NRT",
    "VIIRS_SNPP_NRT",
    "MODIS_NRT",
  ]

  static func fetchHotspots(
    around center: CLLocationCoordinate2D,
    mapKey: String?,
    session: URLSession = .shared
  ) async throws -> [FireHotspot] {
    guard let mapKey, !mapKey.isEmpty else { throw FIRMSServiceError.missingKey }

    let bounds = GeographicBounds.square(around: center, halfSpanDegrees: defaultHalfSpanDegrees)
    var merged: [String: FireHotspot] = [:]

    for source in sources {
      let urlString =
        "https://firms.modaps.eosdis.nasa.gov/api/area/csv/\(mapKey)/\(source)/\(bounds.firmsAreaCoordinates)/\(dayRange)"
      guard let url = URL(string: urlString) else { continue }

      let (data, response): (Data, URLResponse)
      do {
        (data, response) = try await session.data(from: url)
      } catch {
        continue
      }

      if let http = response as? HTTPURLResponse {
        if http.statusCode == 429 || http.statusCode == 403 {
          throw FIRMSServiceError.quotaExceeded
        }
        guard (200..<300).contains(http.statusCode) else { continue }
      }

      let text = String(data: data, encoding: .utf8) ?? ""
      if text.localizedCaseInsensitiveContains("Invalid MAP_KEY")
        || text.localizedCaseInsensitiveContains("MAP_KEY")
          && text.localizedCaseInsensitiveContains("transaction")
      {
        throw FIRMSServiceError.quotaExceeded
      }

      for hotspot in FIRMSCSVParser.parse(csv: text, satellite: source) {
        merged[hotspot.id] = hotspot
      }
    }

    return Array(merged.values)
  }
}

enum FIRMSCSVParser {
  static func parse(csv: String, satellite: String) -> [FireHotspot] {
    let lines = csv.split(whereSeparator: \.isNewline).map(String.init)
    guard let headerLine = lines.first else { return [] }
    let headers = splitCSV(headerLine).map { $0.lowercased() }
    guard headers.contains("latitude"), headers.contains("longitude") else { return [] }

    func index(_ name: String) -> Int? { headers.firstIndex(of: name) }

    let latI = index("latitude")
    let lonI = index("longitude")
    let brightI = index("bright_ti4") ?? index("brightness")
    let frpI = index("frp")
    let confI = index("confidence")
    let dateI = index("acq_date")
    let timeI = index("acq_time")
    let satI = index("satellite")

    var out: [FireHotspot] = []
    out.reserveCapacity(max(0, lines.count - 1))

    for line in lines.dropFirst() {
      let cols = splitCSV(line)
      guard let latI, let lonI,
        latI < cols.count, lonI < cols.count,
        let lat = Double(cols[latI]), let lon = Double(cols[lonI])
      else { continue }

      let acqDate = dateI.flatMap { $0 < cols.count ? cols[$0] : nil }
      let acqTime = timeI.flatMap { $0 < cols.count ? cols[$0] : nil }
      let detectedAt = parseAcquisition(date: acqDate, time: acqTime)
      let conf = confI.flatMap { $0 < cols.count ? cols[$0] : nil }
      let frp = frpI.flatMap { $0 < cols.count ? Double(cols[$0]) : nil }
      let bright = brightI.flatMap { $0 < cols.count ? Double(cols[$0]) : nil }
      let sat = satI.flatMap { $0 < cols.count ? cols[$0] : nil } ?? satellite

      let id = [
        String(format: "%.4f", lat),
        String(format: "%.4f", lon),
        acqDate ?? "",
        acqTime ?? "",
        sat,
      ].joined(separator: "|")

      out.append(
        FireHotspot(
          id: id,
          latitude: lat,
          longitude: lon,
          brightness: bright,
          frp: frp,
          confidence: conf,
          acqDate: acqDate,
          acqTime: acqTime,
          satellite: sat,
          detectedAt: detectedAt
        )
      )
    }
    return out
  }

  private static func splitCSV(_ line: String) -> [String] {
    line.split(separator: ",", omittingEmptySubsequences: false).map {
      String($0).trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }

  private static func parseAcquisition(date: String?, time: String?) -> Date? {
    guard let date, !date.isEmpty else { return nil }
    let timePart = (time ?? "0000").padding(toLength: 4, withPad: "0", startingAt: 0)
    let combined = "\(date) \(timePart)"
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd HHmm"
    return formatter.date(from: combined)
  }
}
