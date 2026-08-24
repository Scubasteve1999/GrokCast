import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest

@testable import DayCast

final class IEMSiteReflectivityPaintTests: XCTestCase {
  func testProcessesOnlyIEMN0BTileURLs() {
    XCTAssertTrue(
      IEMSiteReflectivityPaint.shouldProcess(
        url:
          "https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/ridge::TWX-N0B-202608211620/8/59/97.png"
      ))
    XCTAssertFalse(
      IEMSiteReflectivityPaint.shouldProcess(
        url:
          "https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/ridge::TWX-N0S-202608211620/8/59/97.png"
      ))
    XCTAssertFalse(
      IEMSiteReflectivityPaint.shouldProcess(
        url:
          "https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/ridge::USCOMP-N0Q-202608211620/5/7/12.png"
      ))
    XCTAssertFalse(
      IEMSiteReflectivityPaint.shouldProcess(
        url: "https://api.mapbox.com/v4/mapbox.satellite/8/59/97.webp"))
  }

  func testKeysCyanBlueAndDustyClearAirKeepsPrecip() {
    // NWS 16-level: 0/5/10 dBZ cyan-blue are clutter. 15 dBZ green is rain.
    XCTAssertTrue(clutter(0x00, 0xEC, 0xEC))  // 0 dBZ cyan
    XCTAssertTrue(clutter(0x01, 0xA0, 0xF6))  // 5 dBZ blue
    XCTAssertTrue(clutter(0x00, 0x00, 0xF6))  // 10 dBZ blue
    XCTAssertTrue(clutter(0x57, 0x6D, 0xA4))  // IEM slate clear-air
    XCTAssertTrue(clutter(0x4F, 0x67, 0xA2))
    XCTAssertTrue(clutter(0x60, 0xB4, 0xD4))  // IEM cyan
    XCTAssertTrue(clutter(0xB0, 0xB6, 0xB4))  // dusty khaki floor
    XCTAssertTrue(clutter(0xA3, 0xA0, 0x68))  // site-circle khaki (sat ~36)
    XCTAssertTrue(clutter(0xB0, 0xAF, 0x7E))
    XCTAssertTrue(clutter(0x59, 0xD6, 0xB3))  // 8-bit teal-cyan toward 10 dBZ
    XCTAssertTrue(clutter(0x52, 0xD6, 0xA2))
    XCTAssertTrue(clutter(0x43, 0xD6, 0x7E))
    XCTAssertTrue(clutter(0x3C, 0xD6, 0x6D))

    XCTAssertFalse(clutter(0x00, 0xFF, 0x00))  // 15 dBZ green
    XCTAssertFalse(clutter(0x00, 0xC8, 0x00))  // 20 dBZ
    XCTAssertFalse(clutter(0x11, 0xD5, 0x18))  // IEM bright green
    XCTAssertFalse(clutter(0x35, 0xD6, 0x5B))
    XCTAssertFalse(clutter(0xFF, 0xFF, 0x00))  // yellow
    XCTAssertFalse(clutter(0xFF, 0x90, 0x00))  // orange
    XCTAssertFalse(clutter(0xFF, 0x00, 0x00))  // red
    XCTAssertFalse(clutter(0xFF, 0x00, 0xFF))  // magenta
    XCTAssertFalse(clutter(0xFF, 0xFF, 0xFF))  // white core
  }

  func testDoesNotTreatTransparentAsClutter() {
    XCTAssertFalse(
      IEMSiteReflectivityPaint.isClutterStop(red: 0, green: 0, blue: 0, alpha: 0))
  }

  func testKeysIsolatedGreenGateKeepsOrganizedRain() {
    // 8x8: isolated green speckle, 3x3 rain cell, cyan haze, yellow core.
    var pixels = [UInt8](repeating: 0, count: 8 * 8 * 4)
    func set(_ x: Int, _ y: Int, r: UInt8, g: UInt8, b: UInt8) {
      let o = (y * 8 + x) * 4
      pixels[o] = r
      pixels[o + 1] = g
      pixels[o + 2] = b
      pixels[o + 3] = 255
    }
    set(1, 1, r: 0x11, g: 0xD5, b: 0x18)  // isolated light gate
    for y in 4...6 {
      for x in 4...6 {
        set(x, y, r: 0x11, g: 0xD5, b: 0x18)
      }
    }
    set(0, 0, r: 0x01, g: 0xA0, b: 0xF6)  // cyan clutter
    set(7, 0, r: 0x57, g: 0x6D, b: 0xA4)  // slate clutter
    set(3, 5, r: 0xFF, g: 0xFF, b: 0x00)  // yellow attached to the 3x3

    let png = makePNG(width: 8, height: 8, rgba: pixels)
    let keyed = IEMSiteReflectivityPaint.keyClutter(in: png)
    let out = readRGBA(png: keyed, width: 8, height: 8)

    func alpha(_ x: Int, _ y: Int) -> UInt8 { out[(y * 8 + x) * 4 + 3] }
    func rgb(_ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8) {
      let o = (y * 8 + x) * 4
      return (out[o], out[o + 1], out[o + 2])
    }

    XCTAssertEqual(alpha(1, 1), 0, "isolated green gate must drop")
    XCTAssertEqual(alpha(0, 0), 0, "cyan clutter must drop")
    XCTAssertEqual(alpha(7, 0), 0, "slate clutter must drop")
    XCTAssertEqual(alpha(5, 5), 255, "organized green rain must stay")
    XCTAssertEqual(rgb(5, 5).1, 0xD5)
    XCTAssertEqual(alpha(3, 5), 255, "organized yellow must stay")
    XCTAssertEqual(rgb(3, 5).0, 0xFF)
  }

  func testKeysKhakiLeakAndTealFringeKeepsOrganizedFifteenGreen() {
    var pixels = [UInt8](repeating: 0, count: 8 * 8 * 4)
    func set(_ x: Int, _ y: Int, r: UInt8, g: UInt8, b: UInt8) {
      let o = (y * 8 + x) * 4
      pixels[o] = r
      pixels[o + 1] = g
      pixels[o + 2] = b
      pixels[o + 3] = 255
    }
    // Organized 15 dBZ green cell.
    for y in 4...6 {
      for x in 4...6 {
        set(x, y, r: 0x11, g: 0xD5, b: 0x18)
      }
    }
    set(5, 3, r: 0x35, g: 0xD6, b: 0x5B)  // IEM bright green attached
    set(5, 4, r: 0xFF, g: 0xFF, b: 0x00)  // yellow core — 15 dBZ fringe stays
    set(1, 1, r: 0xA3, g: 0xA0, b: 0x68)  // khaki leak
    set(2, 1, r: 0xB0, g: 0xAF, b: 0x7E)
    set(0, 6, r: 0x59, g: 0xD6, b: 0xB3)  // teal fringe
    set(1, 6, r: 0x3C, g: 0xD6, b: 0x6D)
    set(7, 7, r: 0xFF, g: 0x90, b: 0x00)  // isolated orange — speckle drops

    let png = makePNG(width: 8, height: 8, rgba: pixels)
    let keyed = IEMSiteReflectivityPaint.keyClutter(in: png)
    let out = readRGBA(png: keyed, width: 8, height: 8)

    func alpha(_ x: Int, _ y: Int) -> UInt8 { out[(y * 8 + x) * 4 + 3] }
    func rgb(_ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8) {
      let o = (y * 8 + x) * 4
      return (out[o], out[o + 1], out[o + 2])
    }

    XCTAssertEqual(alpha(1, 1), 0, "khaki leak must drop")
    XCTAssertEqual(alpha(2, 1), 0, "khaki leak must drop")
    XCTAssertEqual(alpha(0, 6), 0, "teal fringe must drop")
    XCTAssertEqual(alpha(1, 6), 0, "mint-teal fringe must drop")
    XCTAssertEqual(alpha(7, 7), 0, "isolated orange gate must drop")
    XCTAssertEqual(alpha(5, 5), 255, "organized 15 dBZ green must stay")
    XCTAssertEqual(rgb(5, 5).1, 0xD5)
    XCTAssertEqual(alpha(5, 3), 255, "organized IEM bright green must stay")
    XCTAssertEqual(rgb(5, 3).1, 0xD6)
  }

  func testKeysBiologicalGreenMixedIntoClearAirKeepsOrganizedRain() {
    // 16×16 cyan sweep (IEM clear-air) with a 4×4 15 dBZ green bloom in
    // the middle — that is KNQA biological, not rain. A 3×3 green cell on
    // transparent air in the corner is light rain and must stay.
    let side = 16
    var pixels = [UInt8](repeating: 0, count: side * side * 4)
    func set(_ x: Int, _ y: Int, r: UInt8, g: UInt8, b: UInt8) {
      let o = (y * side + x) * 4
      pixels[o] = r
      pixels[o + 1] = g
      pixels[o + 2] = b
      pixels[o + 3] = 255
    }
    // Right half: cyan clear-air + 4×4 biological green.
    for y in 0..<side {
      for x in 8..<side {
        set(x, y, r: 0x60, g: 0xB4, b: 0xD4)
      }
    }
    for y in 6...9 {
      for x in 10...13 {
        set(x, y, r: 0x11, g: 0xD5, b: 0x18)
      }
    }
    // Left half stays transparent with an organized 3×3 rain cell + yellow core.
    for y in 1...3 {
      for x in 1...3 {
        set(x, y, r: 0x11, g: 0xD5, b: 0x18)
      }
    }
    set(2, 2, r: 0xFF, g: 0xFF, b: 0x00)

    let png = makePNG(width: side, height: side, rgba: pixels)
    let keyed = IEMSiteReflectivityPaint.keyClutter(in: png)
    let out = readRGBA(png: keyed, width: side, height: side)
    func alpha(_ x: Int, _ y: Int) -> UInt8 { out[(y * side + x) * 4 + 3] }

    XCTAssertEqual(alpha(11, 7), 0, "biological 15 dBZ green in cyan bloom must drop")
    XCTAssertEqual(alpha(10, 6), 0, "bloom edge green must drop")
    XCTAssertEqual(alpha(1, 1), 255, "15 dBZ green attached to a yellow core must stay")
    XCTAssertEqual(alpha(2, 2), 255, "yellow storm core must stay")
    XCTAssertFalse(
      IEMSiteReflectivityPaint.isClutterStop(red: 0x11, green: 0xD5, blue: 0x18, alpha: 255),
      "do not invent a dBZ < 20 chroma cutoff"
    )
    XCTAssertFalse(
      IEMSiteReflectivityPaint.isStormCore(red: 0x11, green: 0xD5, blue: 0x18, alpha: 255))
    XCTAssertTrue(
      IEMSiteReflectivityPaint.isStormCore(red: 0xFF, green: 0xFF, blue: 0x00, alpha: 255))
  }

  func testRefinesOverzoomedGatesWithoutMixingBins() {
    // 32×32 nearest-upsampled 2×2 gates (IEM z10). Organized 15 dBZ green
    // with a yellow core. Interiors stay discrete; rain/clear edges AA.
    let side = 32
    var pixels = [UInt8](repeating: 0, count: side * side * 4)
    func set(_ x: Int, _ y: Int, r: UInt8, g: UInt8, b: UInt8) {
      let o = (y * side + x) * 4
      pixels[o] = r
      pixels[o + 1] = g
      pixels[o + 2] = b
      pixels[o + 3] = 255
    }
    for y in 8..<24 {
      for x in 8..<24 {
        set(x, y, r: 0x11, g: 0xD5, b: 0x18)
      }
    }
    for y in 14..<18 {
      for x in 14..<18 {
        set(x, y, r: 0xFF, g: 0xFF, b: 0x00)
      }
    }

    let png = makePNG(width: side, height: side, rgba: pixels)
    let keyed = IEMSiteReflectivityPaint.keyClutter(in: png)
    let out = readRGBA(png: keyed, width: side, height: side)

    func pixel(_ x: Int, _ y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
      let o = (y * side + x) * 4
      return (out[o], out[o + 1], out[o + 2], out[o + 3])
    }

    let core = pixel(16, 16)
    XCTAssertEqual(core.a, 255)
    XCTAssertEqual(core.r, 0xFF)
    XCTAssertEqual(core.g, 0xFF)
    XCTAssertEqual(core.b, 0x00)

    let green = pixel(10, 10)
    XCTAssertEqual(green.a, 255)
    XCTAssertEqual(green.r, 0x11)
    XCTAssertEqual(green.g, 0xD5)
    XCTAssertEqual(green.b, 0x18)

    var edgeAA = false
    var lime = false
    for y in 0..<side {
      for x in 0..<side {
        let p = pixel(x, y)
        if p.a > 0 && p.a < 255 { edgeAA = true }
        // Green+yellow mix that is not either stop.
        let isGreen = p.r == 0x11 && p.g == 0xD5 && p.b == 0x18
        let isYellow = p.r == 0xFF && p.g == 0xFF && p.b == 0x00
        if p.a == 255 && !isGreen && !isYellow {
          lime = true
        }
      }
    }
    XCTAssertTrue(edgeAA, "rain/clear boundary must anti-alias")
    XCTAssertFalse(lime, "must not paint pastel smear between 15 and 30 dBZ")
  }

  func testDoesNotRefineNativeOnePixelGates() {
    let side = 32
    var pixels = [UInt8](repeating: 0, count: side * side * 4)
    func set(_ x: Int, _ y: Int, r: UInt8, g: UInt8, b: UInt8) {
      let o = (y * side + x) * 4
      pixels[o] = r
      pixels[o + 1] = g
      pixels[o + 2] = b
      pixels[o + 3] = 255
    }
    for y in 8...20 {
      for x in 8...20 {
        set(x, y, r: 0x11, g: 0xD5, b: 0x18)
      }
    }
    set(14, 14, r: 0xFF, g: 0xFF, b: 0x00)

    let png = makePNG(width: side, height: side, rgba: pixels)
    let keyed = IEMSiteReflectivityPaint.keyClutter(in: png)
    let out = readRGBA(png: keyed, width: side, height: side)
    func alpha(_ x: Int, _ y: Int) -> UInt8 { out[(y * side + x) * 4 + 3] }

    XCTAssertEqual(alpha(8, 8), 255)
    XCTAssertEqual(alpha(7, 8), 0, "native 1px outline must stay hard at overview")
    XCTAssertEqual(alpha(14, 14), 255)
  }

  func testLiveDefaultStaysNearestSiteN0B() {
    XCTAssertEqual(RadarProduct.defaultLive, .superResReflectivity)
    XCTAssertEqual(RadarProduct.defaultLive.iemCode, "N0B")
    XCTAssertTrue(RadarProduct.defaultLive.isSiteProduct)
    XCTAssertEqual(RadarProduct.defaultLive.displayName, "Site Doppler")
  }

  func testOrganizedPrecipCountIgnoresClutterAndKeepsCells() {
    var dry = [UInt8](repeating: 0, count: 8 * 8 * 4)
    func setDry(_ x: Int, _ y: Int, r: UInt8, g: UInt8, b: UInt8) {
      let o = (y * 8 + x) * 4
      dry[o] = r
      dry[o + 1] = g
      dry[o + 2] = b
      dry[o + 3] = 255
    }
    setDry(1, 1, r: 0x01, g: 0xA0, b: 0xF6)
    setDry(2, 2, r: 0x57, g: 0x6D, b: 0xA4)
    let dryPNG = makePNG(width: 8, height: 8, rgba: dry)
    XCTAssertEqual(IEMSiteReflectivityPaint.organizedPrecipPixelCount(in: dryPNG), 0)
    XCTAssertFalse(IEMSiteReflectivityPaint.hasOrganizedPrecip(in: dryPNG, minPixels: 6))

    var green = [UInt8](repeating: 0, count: 8 * 8 * 4)
    func setGreen(_ x: Int, _ y: Int, r: UInt8, g: UInt8, b: UInt8) {
      let o = (y * 8 + x) * 4
      green[o] = r
      green[o + 1] = g
      green[o + 2] = b
      green[o + 3] = 255
    }
    for y in 2...5 {
      for x in 2...5 {
        setGreen(x, y, r: 0x11, g: 0xD5, b: 0x18)
      }
    }
    setGreen(3, 3, r: 0xFF, g: 0xFF, b: 0x00)
    let greenPNG = makePNG(width: 8, height: 8, rgba: green)
    XCTAssertLessThan(
      IEMSiteReflectivityPaint.organizedPrecipPixelCount(in: greenPNG), 6,
      "post–clutter-key 15 dBZ green does not count as wet; one yellow speckle is not a cell")
    XCTAssertFalse(IEMSiteReflectivityPaint.hasOrganizedPrecip(in: greenPNG, minPixels: 6))

    var wet = [UInt8](repeating: 0, count: 8 * 8 * 4)
    func setWet(_ x: Int, _ y: Int, r: UInt8, g: UInt8, b: UInt8) {
      let o = (y * 8 + x) * 4
      wet[o] = r
      wet[o + 1] = g
      wet[o + 2] = b
      wet[o + 3] = 255
    }
    for y in 3...5 {
      for x in 3...5 {
        setWet(x, y, r: 0xFF, g: 0xFF, b: 0x00)
      }
    }
    let wetPNG = makePNG(width: 8, height: 8, rgba: wet)
    XCTAssertGreaterThanOrEqual(
      IEMSiteReflectivityPaint.organizedPrecipPixelCount(in: wetPNG), 6)
    XCTAssertTrue(IEMSiteReflectivityPaint.hasOrganizedPrecip(in: wetPNG, minPixels: 6))
  }

  private func clutter(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> Bool {
    IEMSiteReflectivityPaint.isClutterStop(red: r, green: g, blue: b, alpha: 255)
  }

  private func makePNG(width: Int, height: Int, rgba: [UInt8]) -> Data {
    var pixels = rgba
    let destData = NSMutableData()
    let image: CGImage = pixels.withUnsafeMutableBytes { raw in
      let ctx = CGContext(
        data: raw.baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      return ctx.makeImage()!
    }
    let destination = CGImageDestinationCreateWithData(
      destData, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return destData as Data
  }

  private func readRGBA(png: Data, width: Int, height: Int) -> [UInt8] {
    let source = CGImageSourceCreateWithData(png as CFData, nil)!
    let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)!
    var out = [UInt8](repeating: 0, count: width * height * 4)
    out.withUnsafeMutableBytes { raw in
      let ctx = CGContext(
        data: raw.baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return out
  }
}
