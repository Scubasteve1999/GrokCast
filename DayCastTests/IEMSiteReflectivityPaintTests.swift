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

  func testLiveDefaultStaysNearestSiteN0B() {
    XCTAssertEqual(RadarProduct.defaultLive, .superResReflectivity)
    XCTAssertEqual(RadarProduct.defaultLive.iemCode, "N0B")
    XCTAssertTrue(RadarProduct.defaultLive.isSiteProduct)
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
