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
  /// Dusty khaki at the site circle is sat 28–38, not the old sat < 28 floor.
  static let dustyMaxSaturation: Double = 42
  /// IEM 15 dBZ green is hue ~122 (`#11D518`); `#35D65B` is ~134. Hue 138+
  /// is the 8-bit teal-cyan ramp toward 10 dBZ, not organized light rain.
  static let precipHueEnd: Double = 138
  /// Biological bloom is 15 dBZ green mixed into the cyan/blue clear-air
  /// sweep. A 5×5 neighborhood with more chroma-clutter than precip is not a
  /// rain cell. Not a dBZ < 20 cutoff — 15 dBZ green attached to a cell stays.
  static let bloomMixRadius = 2
  static let bloomEatPasses = 3
  /// True yellow/orange/red. IEM olive 25 dBZ (~hue 66–70) is not a cell core.
  static let stormCoreHueEnd: Double = 65

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
    if sat < dustyMaxSaturation && val < 88 { return true }
    // Magenta / purple hail (and high-end N0B).
    if hue > 260 && hue < 340 && sat >= 20 { return false }
    // Red / orange / yellow.
    if hue < 70 || hue >= 340 { return false }
    // Green through IEM `#35D65B`. Teal-cyan 8-bit floor is clutter.
    if hue >= 70 && hue < precipHueEnd { return false }
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
      var clutter = [UInt8](repeating: 0, count: count)
      for i in 0..<count {
        let o = i * bytesPerPixel
        let r = buffer[o]
        let g = buffer[o + 1]
        let b = buffer[o + 2]
        let a = buffer[o + 3]
        if a == 0 { continue }
        if isClutterStop(red: r, green: g, blue: b, alpha: a) {
          clutter[i] = 1
        } else {
          keep[i] = 1
        }
      }

      eatClearAirBloom(
        keep: &keep, clutter: &clutter, width: width, height: height)

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

      dropBloomCoresWithoutStorm(
        filtered: &filtered, buffer: buffer, width: width, height: height,
        bytesPerPixel: bytesPerPixel)

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

  /// Drop 15 dBZ greens whose neighborhood is the clear-air sweep, not a cell.
  /// Each pass treats eaten greens as clutter so bloom cores shrink; storm
  /// interiors (green/yellow surrounded by precip) keep.
  private static func eatClearAirBloom(
    keep: inout [UInt8], clutter: inout [UInt8], width: Int, height: Int
  ) {
    guard width > 1, height > 1 else { return }
    let radius = bloomMixRadius
    for _ in 0..<bloomEatPasses {
      var next = keep
      for y in 0..<height {
        for x in 0..<width {
          let i = y * width + x
          if keep[i] == 0 { continue }
          var clutterN = 0
          var precipN = 0
          let y0 = max(y - radius, 0)
          let y1 = min(y + radius, height - 1)
          let x0 = max(x - radius, 0)
          let x1 = min(x + radius, width - 1)
          for ny in y0...y1 {
            for nx in x0...x1 {
              if nx == x && ny == y { continue }
              let j = ny * width + nx
              if clutter[j] == 1 {
                clutterN += 1
              } else if keep[j] == 1 {
                precipN += 1
              }
            }
          }
          if clutterN > precipN {
            next[i] = 0
          }
        }
      }
      for i in 0..<keep.count where keep[i] == 1 && next[i] == 0 {
        clutter[i] = 1
      }
      keep = next
    }
  }

  /// IEM N0B biological cores are organized 15 dBZ green with no yellow.
  /// NWS MEG / CONUS N0Q stay dry. A cell has yellow/orange/red; 15 dBZ
  /// green attached to that cell stays. Green-only blobs are not precip.
  private static func dropBloomCoresWithoutStorm(
    filtered: inout [UInt8],
    buffer: UnsafeMutablePointer<UInt8>,
    width: Int,
    height: Int,
    bytesPerPixel: Int
  ) {
    let count = width * height
    var seen = [UInt8](repeating: 0, count: count)
    var stack = [Int]()
    var cells = [Int]()
    for start in 0..<count {
      if filtered[start] == 0 || seen[start] == 1 { continue }
      stack.removeAll(keepingCapacity: true)
      cells.removeAll(keepingCapacity: true)
      stack.append(start)
      seen[start] = 1
      var hasCore = false
      while let i = stack.popLast() {
        cells.append(i)
        let o = i * bytesPerPixel
        if isStormCore(
          red: buffer[o], green: buffer[o + 1], blue: buffer[o + 2], alpha: buffer[o + 3])
        {
          hasCore = true
        }
        let y = i / width
        let x = i % width
        let y0 = max(y - 1, 0)
        let y1 = min(y + 1, height - 1)
        let x0 = max(x - 1, 0)
        let x1 = min(x + 1, width - 1)
        for ny in y0...y1 {
          for nx in x0...x1 {
            let j = ny * width + nx
            if filtered[j] == 1 && seen[j] == 0 {
              seen[j] = 1
              stack.append(j)
            }
          }
        }
      }
      if !hasCore {
        for i in cells { filtered[i] = 0 }
      }
    }
  }

  static func isStormCore(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) -> Bool {
    if alpha == 0 { return false }
    let (hue, sat, val) = hsv(red: red, green: green, blue: blue)
    if val >= 88 && sat <= 20 { return true }
    if sat < 20 { return false }
    return hue < stormCoreHueEnd || hue >= 340
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
