import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Paint one WebMercator tile by nearest-neighbor sampling polar N0B gates.
/// Far-range gates cover more pixels in azimuth — wedges, not mercator squares.
enum Level3PolarTilePainter {
  static let tileSize = 256

  struct TileRef: Equatable {
    var site: String
    var timestamp: Date
    var z: Int
    var x: Int
    var y: Int
  }

  static func png(forTileURL url: String) -> Data? {
    guard let ref = parse(url) else { return nil }
    guard let sweep = Level3N0BSweepStore.shared.sweep(site: ref.site, timestamp: ref.timestamp)
    else { return nil }
    return paint(sweep: sweep, z: ref.z, x: ref.x, y: ref.y)
  }

  static func parse(_ url: String) -> TileRef? {
    // ridge::TWX-N0B-20260822133944/12/1174/1960.png
    let url = url.split(separator: "?").first.map(String.init) ?? url
    guard let ridge = url.range(of: "ridge::") else { return nil }
    let rest = url[ridge.upperBound...]
    guard let siteEnd = rest.firstIndex(of: "-") else { return nil }
    let site = String(rest[..<siteEnd])
    let afterSite = rest[rest.index(after: siteEnd)...]
    guard afterSite.hasPrefix("N0B-") else { return nil }
    let afterProd = afterSite.dropFirst(4)
    guard let slash = afterProd.firstIndex(of: "/") else { return nil }
    let stamp = String(afterProd[..<slash])
    guard stamp.count == 12 || stamp.count == 14,
      let timestamp = parseStamp(stamp)
    else { return nil }
    let path = afterProd[afterProd.index(after: slash)...]
      .replacingOccurrences(of: ".png", with: "")
    let parts = path.split(separator: "/").compactMap { Int($0) }
    guard parts.count >= 3 else { return nil }
    return TileRef(site: site, timestamp: timestamp, z: parts[0], x: parts[1], y: parts[2])
  }

  static func paint(sweep: Level3N0BSweep, z: Int, x: Int, y: Int) -> Data {
    let size = tileSize

    let bytesPerPixel = 4
    var pixels = [UInt8](repeating: 0, count: size * size * bytesPerPixel)
    let n = Double(1 << z)
    let earthR = 6_371_000.0
    let lat0 = sweep.latitude * .pi / 180
    let lon0 = sweep.longitude * .pi / 180
    let sinLat0 = sin(lat0)
    let cosLat0 = cos(lat0)
    let maxRange = sweep.maxRangeMeters

    pixels.withUnsafeMutableBytes { raw in
      guard let buf = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
      for row in 0..<size {
        let mercY = (Double(y) + (Double(row) + 0.5) / Double(size)) / n
        let lat = atan(sinh(.pi * (1 - 2 * mercY)))
        let sinLat = sin(lat)
        let cosLat = cos(lat)
        for col in 0..<size {
          let mercX = (Double(x) + (Double(col) + 0.5) / Double(size)) / n
          let lon = mercX * 2 * .pi - .pi
          let dLon = lon - lon0
          let cosDLon = cos(dLon)
          var a =
            sinLat0 * sinLat + cosLat0 * cosLat * cosDLon
          a = min(1, max(-1, a))
          let range = earthR * acos(a)
          if range >= maxRange { continue }
          let yE = sin(dLon) * cosLat
          let xN = cosLat0 * sinLat - sinLat0 * cosLat * cosDLon
          var az = atan2(yE, xN) * 180 / .pi
          if az < 0 { az += 360 }
          guard let byte = sweep.gateByte(rangeMeters: range, azimuth: az) else { continue }
          let color = sweep.rgbaLUT[Int(byte)]
          if color.3 == 0 { continue }
          let o = (row * size + col) * bytesPerPixel
          buf[o] = color.0
          buf[o + 1] = color.1
          buf[o + 2] = color.2
          buf[o + 3] = color.3
        }
      }
    }

    return encodePNG(pixels: pixels, width: size, height: size) ?? emptyPNG
  }

  static func parseStamp(_ stamp: String) -> Date? {
    let padded = stamp.count == 12 ? stamp + "00" : stamp
    guard padded.count == 14,
      let year = Int(padded.prefix(4)),
      let month = Int(padded.dropFirst(4).prefix(2)),
      let day = Int(padded.dropFirst(6).prefix(2)),
      let hour = Int(padded.dropFirst(8).prefix(2)),
      let minute = Int(padded.dropFirst(10).prefix(2)),
      let second = Int(padded.dropFirst(12).prefix(2))
    else { return nil }
    var comps = DateComponents()
    comps.calendar = Calendar(identifier: .gregorian)
    comps.timeZone = TimeZone(secondsFromGMT: 0)
    comps.year = year
    comps.month = month
    comps.day = day
    comps.hour = hour
    comps.minute = minute
    comps.second = second
    return comps.date
  }

  private static let emptyPNG: Data = {
    encodePNG(
      pixels: [UInt8](repeating: 0, count: tileSize * tileSize * 4),
      width: tileSize, height: tileSize) ?? Data()
  }()

  static func encodePNG(pixels: [UInt8], width: Int, height: Int) -> Data? {
    let bytesPerPixel = 4
    let cfData = Data(pixels) as CFData
    guard let provider = CGDataProvider(data: cfData) else { return nil }
    guard
      let image = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * bytesPerPixel,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(
          rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent)
    else { return nil }
    let destData = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        destData, UTType.png.identifier as CFString, 1, nil)
    else { return nil }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return destData as Data
  }
}
