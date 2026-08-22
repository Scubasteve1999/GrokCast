import CoreGraphics
import CoreLocation
import ImageIO
import XCTest

@testable import DayCast

final class RadarLiveCameraPolicyTests: XCTestCase {
  private let oliveBranch = CLLocationCoordinate2D(latitude: 34.9618, longitude: -89.8295)

  func testWetOrPinnedKeepsLocalZoom() {
    XCTAssertEqual(
      RadarLiveCameraPolicy.cameraZoom(
        presentingNationalBecauseDry: false,
        userPinnedSiteDoppler: false,
        nearestPrecipMeters: 1_100_000,
        latitude: oliveBranch.latitude),
      RadarLiveCameraPolicy.localZoom
    )
    XCTAssertEqual(
      RadarLiveCameraPolicy.cameraZoom(
        presentingNationalBecauseDry: true,
        userPinnedSiteDoppler: true,
        nearestPrecipMeters: 1_100_000,
        latitude: oliveBranch.latitude),
      RadarLiveCameraPolicy.localZoom
    )
  }

  func testUnknownPrecipUsesConusFrame() {
    XCTAssertEqual(
      RadarLiveCameraPolicy.zoomToFit(
        nearestPrecipMeters: nil, latitude: oliveBranch.latitude),
      RadarLiveCameraPolicy.conusZoom
    )
    XCTAssertLessThan(
      RadarLiveCameraPolicy.conusZoom, RadarLiveCameraPolicy.localZoom)
  }

  func testNearerPrecipZoomsOutLessThanConus() {
    let regional = RadarLiveCameraPolicy.zoomToFit(
      nearestPrecipMeters: 400_000, latitude: oliveBranch.latitude)
    let florida = RadarLiveCameraPolicy.zoomToFit(
      nearestPrecipMeters: 1_100_000, latitude: oliveBranch.latitude)
    XCTAssertLessThan(regional, RadarLiveCameraPolicy.localZoom)
    XCTAssertGreaterThan(regional, florida)
    XCTAssertGreaterThanOrEqual(florida, RadarLiveCameraPolicy.conusZoom)
    XCTAssertLessThanOrEqual(florida, RadarLiveCameraPolicy.localZoom)
  }

  func testPrecipInsideLocalRadiusDoesNotYankToConus() {
    XCTAssertEqual(
      RadarLiveCameraPolicy.zoomToFit(
        nearestPrecipMeters: 80_000, latitude: oliveBranch.latitude),
      RadarLiveCameraPolicy.localZoom
    )
  }

  func testDryNationalNeverKeepsEmptyLocalZoom() {
    let zoom = RadarLiveCameraPolicy.cameraZoom(
      presentingNationalBecauseDry: true,
      userPinnedSiteDoppler: false,
      nearestPrecipMeters: 71_000,
      latitude: oliveBranch.latitude)
    XCTAssertLessThan(zoom, RadarLiveCameraPolicy.localZoom)
    XCTAssertLessThanOrEqual(zoom, RadarLiveCameraPolicy.dryNationalMaxZoom)
    XCTAssertGreaterThanOrEqual(zoom, RadarLiveCameraPolicy.conusZoom)
  }

  func testLocalVisibleRadiusIsAboutAHundredMiles() {
    let radius = RadarLiveCameraPolicy.visibleRadiusMeters(
      zoom: RadarLiveCameraPolicy.localZoom, latitude: oliveBranch.latitude)
    XCTAssertGreaterThan(radius, 150_000)
    XCTAssertLessThan(radius, 450_000)
  }

  func testMosaicPNGDetectsChromaRainNotClear() {
    let clear = [UInt8](repeating: 0, count: 8 * 8 * 4)
    let clearPNG = makePNG(width: 8, height: 8, rgba: clear)
    XCTAssertFalse(IEMRadarService.mosaicPNGHasPrecip(clearPNG, minPixels: 6))

    var rain = [UInt8](repeating: 0, count: 8 * 8 * 4)
    for y in 2...5 {
      for x in 2...5 {
        let o = (y * 8 + x) * 4
        rain[o] = 0x00
        rain[o + 1] = 0xE0
        rain[o + 2] = 0x20
        rain[o + 3] = 255
      }
    }
    let rainPNG = makePNG(width: 8, height: 8, rgba: rain)
    XCTAssertTrue(IEMRadarService.mosaicPNGHasPrecip(rainPNG, minPixels: 6))
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
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )!
      return ctx.makeImage()!
    }
    let dest = CGImageDestinationCreateWithData(
      destData, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    return destData as Data
  }
}
