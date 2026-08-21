import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// IEM RIDGE N0B is 8-bit reflectivity, including clear-air. Tiles bake every
/// echo at alpha 255 — cyan/blue/slate and dusty khaki are not rain, they are
/// the -32 to ~10 dBZ floor plus biological/ground clutter. MapsGL already
/// zeros the 0 dBZ cyan stop; this keys the matching baked pixels to
/// transparent on the PNG before Mapbox paints. Isolated leftover gates
/// (speckle) drop. Organized green/yellow/orange/red stays.
///
/// Not a dBZ < 20 cutoff: 15 dBZ NWS green (`#00FF00` / IEM `#11D518`) keeps.
/// Not opacity, blur, glow, or sat/hue retint.
enum IEMSiteReflectivityPaint {
  /// 8-neighbor count at or below this is an isolated gate, not a rain cell.
  static let speckleMaxNeighbors = 1

  static func shouldProcess(url: String) -> Bool {
    url.contains("ridge::") && url.contains("-N0B-")
  }

  /// True when the baked N0B color is clear-air / cyan-blue clutter, not precip.
  static func isClutterStop(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)
    -> Bool
  {
    if alpha == 0 { return false }
    let (hue, sat, val) = hsv(red: red, green: green, blue: blue)
    // Near-white 70 dBZ cores (sat near 0, val high).
    if val >= 88 && sat <= 20 { return false }
    // Dusty khaki/gray 8-bit floor — not saturated precip.
    if sat < 28 && val < 88 { return true }
    // Magenta / purple hail (and high-end N0B).
    if hue > 260 && hue < 340 && sat >= 20 { return false }
    // Red / orange / yellow.
    if hue < 70 || hue >= 340 { return false }
    // Green through teal-green (NWS 15 dBZ and the 8-bit approach to it).
    if hue >= 70 && hue < 175 { return false }
    // Remaining: cyan / blue / slate (NWS 0–10 dBZ + clear-air).
    return true
  }

  static func keyClutter(in png: Data) -> Data {
    guard let source = CGImageSourceCreateWithData(png as CFData, nil),
      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return png }

    let width = cgImage.width
    let height = cgImage.height
    guard width > 0, height > 0 else { return png }

    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    return pixels.withUnsafeMutableBytes { raw -> Data in
      guard
        let context = CGContext(
          data: raw.baseAddress,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: bytesPerRow,
          space: colorSpace,
          bitmapInfo: bitmapInfo)
      else { return png }

      context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
      guard let buffer = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
        return png
      }

      let count = width * height
      var keep = [UInt8](repeating: 0, count: count)
      for i in 0..<count {
        let o = i * bytesPerPixel
        let r = buffer[o]
        let g = buffer[o + 1]
        let b = buffer[o + 2]
        let a = buffer[o + 3]
        if a > 0 && !isClutterStop(red: r, green: g, blue: b, alpha: a) {
          keep[i] = 1
        }
      }

      var filtered = keep
      if width >= 2 && height >= 2 {
        for y in 0..<height {
          for x in 0..<width {
            let i = y * width + x
            if keep[i] == 0 { continue }
            var neighbors = 0
            let y0 = max(y - 1, 0)
            let y1 = min(y + 1, height - 1)
            let x0 = max(x - 1, 0)
            let x1 = min(x + 1, width - 1)
            for ny in y0...y1 {
              for nx in x0...x1 {
                if nx == x && ny == y { continue }
                if keep[ny * width + nx] == 1 { neighbors += 1 }
              }
            }
            if neighbors <= speckleMaxNeighbors {
              filtered[i] = 0
            }
          }
        }
      }

      for i in 0..<count where filtered[i] == 0 {
        let o = i * bytesPerPixel
        buffer[o] = 0
        buffer[o + 1] = 0
        buffer[o + 2] = 0
        buffer[o + 3] = 0
      }

      guard let outImage = context.makeImage() else { return png }
      let destData = NSMutableData()
      guard
        let destination = CGImageDestinationCreateWithData(
          destData, UTType.png.identifier as CFString, 1, nil)
      else { return png }
      CGImageDestinationAddImage(destination, outImage, nil)
      guard CGImageDestinationFinalize(destination) else { return png }
      return destData as Data
    }
  }

  /// HSV matching Python `colorsys.rgb_to_hsv`. Hue 0..<360, sat/val 0...100.
  static func hsv(red: UInt8, green: UInt8, blue: UInt8) -> (
    hue: Double, sat: Double, val: Double
  ) {
    let r = Double(red) / 255
    let g = Double(green) / 255
    let b = Double(blue) / 255
    let maxc = max(r, g, b)
    let minc = min(r, g, b)
    let val = maxc * 100
    let delta = maxc - minc
    if delta == 0 {
      return (0, 0, val)
    }
    let sat = (delta / maxc) * 100
    let rc = (maxc - r) / delta
    let gc = (maxc - g) / delta
    let bc = (maxc - b) / delta
    let h6: Double
    if r == maxc {
      h6 = bc - gc
    } else if g == maxc {
      h6 = 2 + rc - bc
    } else {
      h6 = 4 + gc - rc
    }
    var hue = (h6 / 6).truncatingRemainder(dividingBy: 1)
    if hue < 0 { hue += 1 }
    return (hue * 360, sat, val)
  }
}
