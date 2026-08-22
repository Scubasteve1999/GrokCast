import CoreGraphics
import CoreLocation
import ImageIO
import XCTest

@testable import DayCast

final class Level3N0BTests: XCTestCase {
  func testDigitalRefLUTMapsOfficialStops() {
    let lut = Level3N0BDecoder.dbzLUT(minValTenths: -320, incrementTenths: 5, numLevels: 254)
    XCTAssertTrue(lut[0].isNaN)
    XCTAssertTrue(lut[1].isNaN)
    XCTAssertEqual(lut[2], -32, accuracy: 0.01)
    XCTAssertEqual(lut[86], 10, accuracy: 0.01)
    XCTAssertEqual(lut[96], 15, accuracy: 0.01)
    XCTAssertEqual(lut[126], 30, accuracy: 0.01)
    XCTAssertEqual(lut[146], 40, accuracy: 0.01)
  }

  func testClearAirBytesAreTransparentAnd15GreenStays() {
    let lut = Level3N0BDecoder.dbzLUT(minValTenths: -320, incrementTenths: 5, numLevels: 254)
    let rgba = Level3N0BDecoder.rgbaLUT(from: lut)
    XCTAssertEqual(rgba[86].3, 0, "10 dBZ cyan floor must not paint")
    XCTAssertEqual(rgba[2].3, 0)
    let a15 = MapsGLRadarPalette.polarUnderlayAlpha(forDbz: 15)
    XCTAssertEqual(rgba[96].3, UInt8((a15 * 255).rounded()), "15 dBZ green stays, underlay alpha")
    XCTAssertEqual(rgba[96].0, 0)
    XCTAssertEqual(rgba[96].1, UInt8((255 * a15).rounded()), "15 dBZ is premul NWS #00FF00")
    let a40 = MapsGLRadarPalette.polarUnderlayAlpha(forDbz: 40)
    XCTAssertEqual(rgba[146].0, UInt8((255 * a40).rounded()), "40 dBZ is premul NWS #FF9000")
    XCTAssertEqual(rgba[146].1, UInt8((144 * a40).rounded()))
    XCTAssertEqual(rgba[146].3, UInt8((a40 * 255).rounded()))
  }

  func testPolarSampleFollowsAzimuthNotMercatorSquare() {
    let sweep = Self.spokeSweep(azimuth: 90, byte: 146)
    // ~5 km due east of TWX is inside the 40 dBZ spoke.
    XCTAssertEqual(sweep.gateByte(rangeMeters: 5_000, azimuth: 90), 146)
    XCTAssertEqual(sweep.gateByte(rangeMeters: 5_000, azimuth: 0), 0)
    XCTAssertEqual(sweep.gateByte(rangeMeters: 5_000, azimuth: 180), 0)
    XCTAssertNil(sweep.gateByte(rangeMeters: 40_000, azimuth: 90), "spoke is 20 km")
  }

  func testWedgesWidenWithRange() {
    let sweep = Self.spokeSweep(azimuth: 90, byte: 146, delta: 0.5)
    let nearWidth = Self.azimuthSpanWithData(sweep: sweep, rangeMeters: 4_000)
    let farWidth = Self.azimuthSpanWithData(sweep: sweep, rangeMeters: 18_000)
    XCTAssertEqual(nearWidth, 0.5, accuracy: 0.15)
    XCTAssertEqual(farWidth, 0.5, accuracy: 0.15)
    // Ground width in meters grows with range even though az width is 0.5°.
    let nearMeters = 4_000 * tan(nearWidth * .pi / 180)
    let farMeters = 18_000 * tan(farWidth * .pi / 180)
    XCTAssertGreaterThan(farMeters, nearMeters * 3)
  }

  func testParsesRidgeTileURLWithSeconds() {
    let url =
      "https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/ridge::TWX-N0B-20260822133944/12/1174/1960.png"
    let ref = Level3PolarTilePainter.parse(url)
    XCTAssertEqual(ref?.site, "TWX")
    XCTAssertEqual(ref?.z, 12)
    XCTAssertEqual(ref?.x, 1174)
    XCTAssertEqual(ref?.y, 1960)
    XCTAssertEqual(ref?.timestamp.timeIntervalSince1970 ?? 0, 1_787_405_984, accuracy: 0.5)
    let minuteURL =
      "https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/ridge::TWX-N0B-202608221339/8/59/97.png"
    XCTAssertEqual(Level3PolarTilePainter.parse(minuteURL)?.site, "TWX")
    XCTAssertEqual(Level3PolarTilePainter.parse(minuteURL)?.z, 8)
  }

  func testS3ListXMLExtractsKeys() {
    let xml = """
      <ListBucketResult><Contents><Key>TWX_N0B_2026_08_22_13_39_44</Key></Contents>\
      <Contents><Key>TWX_N0B_2026_08_22_13_42_10</Key></Contents></ListBucketResult>
      """
    XCTAssertEqual(
      Level3N0BService.keys(fromListXML: xml),
      ["TWX_N0B_2026_08_22_13_39_44", "TWX_N0B_2026_08_22_13_42_10"])
    XCTAssertEqual(
      Level3N0BService.stamp(fromObjectKey: "TWX_N0B_2026_08_22_13_39_44"),
      "2026_08_22_13_39_44")
  }

  func testHourPrefixesCoverLookback() {
    let from = Date(timeIntervalSince1970: 1_787_405_984)  // 13:39:44Z
    let prefixes = Level3N0BService.hourPrefixes(
      site: "TWX", from: from.addingTimeInterval(-3600), to: from)
    XCTAssertTrue(prefixes.contains("TWX_N0B_2026_08_22_12"))
    XCTAssertTrue(prefixes.contains("TWX_N0B_2026_08_22_13"))
  }

  func testDecodesUncompressedMiniProduct() throws {
    let data = Self.miniN0B(site: "TWX", azimuths: [90], gates: [146, 146, 96, 86, 0])
    let sweep = try XCTUnwrap(Level3N0BDecoder.decode(data, siteHint: "TWX"))
    XCTAssertEqual(sweep.siteID, "TWX")
    XCTAssertEqual(sweep.binCount, 5)
    XCTAssertEqual(sweep.radials.count, 1)
    XCTAssertEqual(sweep.gateByte(rangeMeters: 100, azimuth: 90), 146)
    XCTAssertEqual(sweep.rgbaLUT[Int(86)].3, 0)
    XCTAssertGreaterThan(sweep.rgbaLUT[Int(96)].3, 0)
    XCTAssertLessThan(sweep.rgbaLUT[Int(96)].3, 255, "15 dBZ underlay is not fully opaque")
    XCTAssertGreaterThan(sweep.rgbaLUT[Int(96)].3, 190, "15 dBZ fill is saturated")
  }

  func testDecodesLiveAWSFileIfPresent() throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let file = root.appendingPathComponent(
      "scratch/radar-site-level3-2026-08-22/src/TWX_N0B_2026_08_22_13_39_44")
    guard FileManager.default.fileExists(atPath: file.path) else { return }
    let data = try Data(contentsOf: file)
    let sweep = try XCTUnwrap(Level3N0BDecoder.decode(data, siteHint: "TWX"))
    XCTAssertEqual(sweep.siteID, "TWX")
    XCTAssertEqual(sweep.binCount, 1840)
    XCTAssertEqual(sweep.radials.count, 720)
    XCTAssertEqual(sweep.gateWidthMeters, 250, accuracy: 1)
    XCTAssertEqual(sweep.latitude, 38.997, accuracy: 0.01)
    XCTAssertEqual(sweep.longitude, -96.232, accuracy: 0.01)
    XCTAssertTrue(sweep.hasOrganizedPrecip)
    XCTAssertEqual(sweep.timestamp.timeIntervalSince1970, 1_787_405_984, accuracy: 1)
    XCTAssertEqual(sweep.azIndex.count, 720)
    XCTAssertFalse(sweep.azIndex.contains(0xFFFF), "every 0.5° slot maps to a radial")
    XCTAssertEqual(
      Set(sweep.azIndex.map { Int($0) }).count, sweep.radials.count,
      "0.4/0.5/0.6 delta jitter must not drop radials")
  }

  func testAzIndexSlotCentersKeepJitteredRadials() {
    // N0B Super-Res: 0.4° then 0.5° then 0.6° — the 0.4° radial used to lose
    // its only 0.5° slot to the next start.
    let radials = [
      Level3N0BSweep.Radial(startAzimuth: 120.0, deltaAzimuth: 0.4, gates: [146]),
      Level3N0BSweep.Radial(startAzimuth: 120.4, deltaAzimuth: 0.5, gates: [96]),
      Level3N0BSweep.Radial(startAzimuth: 120.9, deltaAzimuth: 0.6, gates: [126]),
    ]
    let idx = Level3N0BDecoder.buildAzIndex(radials)
    XCTAssertFalse(idx.contains(0xFFFF))
    XCTAssertEqual(Set(idx).count, 3)
    XCTAssertEqual(idx[240], 0, "slot 120.0–120.5 center 120.25 is the 0.4° radial")
    XCTAssertEqual(idx[241], 1, "slot 120.5–121.0 center 120.75 is the 0.5° radial")
    XCTAssertEqual(idx[242], 2, "slot 121.0–121.5 center 121.25 is the 0.6° radial")
  }

  func testPaintByteClosesKeyedOutCracksThroughPrecip() {
    let sweep = Self.spokeSweep(azimuth: 90, byte: 146, holeAzimuth: 90.5, holeByte: 86)
    XCTAssertEqual(sweep.gateByte(rangeMeters: 5_000, azimuth: 90.5), 86)
    XCTAssertEqual(
      sweep.paintByte(rangeMeters: 5_000, azimuth: 90.5), 146,
      "10 dBZ crack between 40 dBZ neighbors must paint as a hard neighbor bin")
    XCTAssertEqual(sweep.paintByte(rangeMeters: 5_000, azimuth: 90), 146)
  }

  func testPaintByteDoesNotGrowPrecipIntoClearAir() {
    let sweep = Self.spokeSweep(azimuth: 90, byte: 146)
    XCTAssertEqual(sweep.paintByte(rangeMeters: 5_000, azimuth: 90), 146)
    XCTAssertEqual(sweep.paintByte(rangeMeters: 5_000, azimuth: 0), 0)
    XCTAssertEqual(
      sweep.paintByte(rangeMeters: 5_000, azimuth: 89.5), 0,
      "one-sided edge must stay clear — no AccuWeather dilation")
  }

  func testPolarPaintHasNoAzimuthSeamsThroughPrecip() {
    let sweep = Self.spokeSweep(azimuth: 90, byte: 146, holeAzimuth: 90.5, holeByte: 86)
    let z = 12
    let dest = Self.destination(
      lat: sweep.latitude, lon: sweep.longitude, azimuth: 90.5, rangeMeters: 6_000)
    let tile = IEMRadarService.webMercatorTile(lat: dest.lat, lon: dest.lon, zoom: z)
    let png = Level3PolarTilePainter.paint(sweep: sweep, z: z, x: tile.x, y: tile.y)
    XCTAssertEqual(
      Self.sandwichedTransparentPixels(in: png), 0,
      "no 1px map-colored ray through precip after azimuth hole-fill")
    XCTAssertTrue(IEMSiteReflectivityPaint.hasOrganizedPrecip(in: png, minPixels: 1))
  }

  func testInterceptorReturnsNilWithoutSweep() {
    Level3N0BSweepStore.shared.removeAll()
    let url =
      "https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/ridge::TWX-N0B-20260822133944/8/59/97.png"
    XCTAssertNil(Level3PolarTilePainter.png(forTileURL: url))
  }

  func testPolarPaintEmitsWedgePixels() {
    let sweep = Self.spokeSweep(azimuth: 90, byte: 146)
    Level3N0BSweepStore.shared.replace([sweep])
    defer { Level3N0BSweepStore.shared.removeAll() }

    let z = 9
    let tile = IEMRadarService.webMercatorTile(
      lat: sweep.latitude, lon: sweep.longitude + 0.08, zoom: z)
    let png = Level3PolarTilePainter.paint(sweep: sweep, z: z, x: tile.x, y: tile.y)
    XCTAssertGreaterThan(png.count, 100)
    XCTAssertTrue(IEMSiteReflectivityPaint.hasOrganizedPrecip(in: png, minPixels: 1))
  }

  func testPolarUnderlayAlphasKeepHardHexAndTranslucentLightBins() {
    XCTAssertFalse(MapsGLRadarPalette.interpolatesStops)
    XCTAssertFalse(MapsGLRadarPalette.interpolatesSamples)
    XCTAssertEqual(MapsGLRadarPalette.sampleSmoothing, 0)
    XCTAssertEqual(MapsGLRadarPalette.polarUnderlayAlpha(forDbz: 10), 0)
    XCTAssertEqual(MapsGLRadarPalette.polarUnderlayAlpha(forDbz: 15), 0.80, accuracy: 0.0001)
    XCTAssertEqual(MapsGLRadarPalette.polarUnderlayAlpha(forDbz: 20), 0.86, accuracy: 0.0001)
    XCTAssertEqual(MapsGLRadarPalette.polarUnderlayAlpha(forDbz: 30), 0.93, accuracy: 0.0001)
    XCTAssertEqual(MapsGLRadarPalette.polarUnderlayAlpha(forDbz: 35), 0.95, accuracy: 0.0001)
    XCTAssertEqual(MapsGLRadarPalette.polarUnderlayAlpha(forDbz: 45), 0.97, accuracy: 0.0001)
    XCTAssertEqual(MapsGLRadarPalette.polarUnderlayAlpha(forDbz: 70), 1, accuracy: 0.0001)
    XCTAssertLessThan(
      MapsGLRadarPalette.polarUnderlayAlpha(forDbz: 15),
      MapsGLRadarPalette.reflectivityStops.first { $0.dbz == 15 }?.alpha ?? 1)
    XCTAssertEqual(
      MapsGLRadarPalette.reflectivityStops.first { $0.dbz == 15 }?.alpha ?? -1,
      0.99,
      accuracy: 0.0001,
      "National / MapsGL stays near-opaque")
    XCTAssertEqual(MapsGLRadarPalette.reflectivityStops.first { $0.dbz == 20 }?.alpha, 1)
    XCTAssertEqual(MapsGLRadarPalette.reflectivityStops.first { $0.dbz == 15 }?.hex, "#00FF00")
    XCTAssertEqual(MapsGLRadarPalette.reflectivityStops.first { $0.dbz == 45 }?.hex, "#FF0000")

    let lut = Level3N0BDecoder.dbzLUT(minValTenths: -320, incrementTenths: 5, numLevels: 254)
    let rgba = Level3N0BDecoder.rgbaLUT(from: lut)
    XCTAssertEqual(rgba[96].3, UInt8((0.80 * 255).rounded()))
    XCTAssertGreaterThan(rgba[96].3, 190, "15 dBZ fill is saturated vs the faded 0.42 underlay")
    XCTAssertLessThan(rgba[96].3, 255, "15 dBZ is not a fully solid sheet")
    let a45 = MapsGLRadarPalette.polarUnderlayAlpha(forDbz: 45)
    XCTAssertGreaterThan(a45, 0.9)
    let byte45 = 156
    XCTAssertEqual(lut[byte45], 45, accuracy: 0.01)
    XCTAssertEqual(rgba[byte45].3, UInt8((a45 * 255).rounded()))
    XCTAssertEqual(rgba[byte45].0, UInt8((255 * a45).rounded()), "45 dBZ stays hard red")
    XCTAssertEqual(rgba[byte45].1, 0)
  }

  func testPolarPremulTimesGlobalOpacityStaysPremul() {
    let stopAlpha = MapsGLRadarPalette.polarUnderlayAlpha(forDbz: 15)
    let global = RadarPreferences.defaultRadarOpacity
    let premulG = (255.0 * stopAlpha).rounded()
    let premulA = (stopAlpha * 255).rounded()
    let outG = premulG * global
    let outA = premulA * global
    XCTAssertGreaterThan(outA, 0)
    let unpremulG = outG / outA * 255
    XCTAssertEqual(unpremulG, 255, accuracy: 2, "no wash / white rays from opacity multiply")
    XCTAssertLessThan(outA / 255, 0.90, "15 dBZ * default slider still shows some underlay")
    XCTAssertGreaterThan(outA / 255, 0.70, "15 dBZ fill stays strong after slider")

    let coreAlpha = MapsGLRadarPalette.polarUnderlayAlpha(forDbz: 45)
    let coreA = (coreAlpha * 255).rounded() * global
    XCTAssertGreaterThan(coreA / 255, 0.85, "red cores stay strong after slider")
  }

  func testPolarResamplingStaysNearestAtStreetZoom() {
    XCTAssertEqual(MapsGLRadarPalette.level3DisplayMaxZoom, 14, accuracy: 0.0001)
    XCTAssertTrue(
      MapsGLRadarPalette.usesNearestResampling(
        provider: .iem, isFuture: false, cameraZoom: 12, paintsPolarRadials: true))
    XCTAssertFalse(
      MapsGLRadarPalette.usesNearestResampling(
        provider: .iem, isFuture: false, cameraZoom: 12, paintsPolarRadials: false))
    XCTAssertEqual(
      MapsGLRadarPalette.displayMaxZoom(provider: .iem, paintsPolarRadials: true),
      14,
      accuracy: 0.0001)
    XCTAssertEqual(
      MapsGLRadarPalette.displayMaxZoom(provider: .iem, paintsPolarRadials: false),
      MapsGLRadarPalette.iemDisplayMaxZoom,
      accuracy: 0.0001)
  }

  func testGateIndexedPaintByteClosesKeyedCracks() {
    let cracked = Self.spokeSweep(azimuth: 90, byte: 146, holeAzimuth: 90.5, holeByte: 86)
    let holeRadial = Int((90.5 / 0.5).rounded(.down))
    XCTAssertEqual(cracked.radials[holeRadial].gates[10], 86)
    XCTAssertEqual(
      cracked.paintByte(radialIndex: holeRadial, gateIndex: 10), 146,
      "discrete hole-fill must close 5–14 dBZ cracks for trapezoid paint")
    let spoke = Self.spokeSweep(azimuth: 90, byte: 146)
    XCTAssertEqual(spoke.paintByte(radialIndex: 0, gateIndex: 10), 0)
  }

  func testMetalMeshEmitsWideningTrapezoidsNotMercatorSquares() {
    XCTAssertEqual(MemoryLayout<Level3PolarVertex>.offset(of: \.r), 8)
    let sweep = Self.spokeSweep(azimuth: 45, byte: 146, bins: 80)
    let mesh = Level3PolarGateMesh.build(sweep: sweep)
    XCTAssertGreaterThan(mesh.triangleCount, 0)
    XCTAssertEqual(mesh.vertices.count % 3, 0)

    var inner = 0.0
    var outer = 0.0
    var i = 0
    while i + 5 < mesh.vertices.count {
      inner = max(inner, Self.groundMeters(mesh.vertices[i], mesh.vertices[i + 1]))
      outer = max(outer, Self.groundMeters(mesh.vertices[i + 2], mesh.vertices[i + 5]))
      i += 6
    }
    XCTAssertGreaterThan(outer, 50, "far-range 0.5° gate must be tens of meters wide")
    XCTAssertGreaterThan(outer, inner * 2.5, "far-range gates must be wider wedges")
  }

  func testMetalMeshSkipsClearAirAndKeeps15Green() {
    let sweep = Self.spokeSweep(azimuth: 90, byte: 96, bins: 40)
    let mesh = Level3PolarGateMesh.build(sweep: sweep)
    XCTAssertGreaterThan(mesh.vertices.count, 0)
    let a15 = UInt8((MapsGLRadarPalette.polarUnderlayAlpha(forDbz: 15) * 255).rounded())
    XCTAssertTrue(mesh.vertices.allSatisfy { $0.a == a15 })
    XCTAssertEqual(mesh.vertices.first?.r, 0)
    XCTAssertEqual(mesh.vertices.first?.g, a15, "premul #00FF00")

    let clear = Self.spokeSweep(azimuth: 90, byte: 86, bins: 40)
    let empty = Level3PolarGateMesh.build(sweep: clear)
    XCTAssertEqual(empty.triangleCount, 0, "10 dBZ cyan floor must not emit trapezoids")
  }

  func testMetalMeshHoleFillDoesNotDilateClearAir() {
    let cracked = Self.spokeSweep(azimuth: 90, byte: 146, holeAzimuth: 90.5, holeByte: 86)
    let filled = Level3PolarGateMesh.build(sweep: cracked)
    let disk = Level3PolarGateMesh.build(
      sweep: Self.spokeSweep(azimuth: 90, byte: 146, holeAzimuth: 90.5, holeByte: 146))
    XCTAssertGreaterThan(filled.triangleCount, 0)
    XCTAssertEqual(
      filled.triangleCount, disk.triangleCount,
      "keyed crack through precip becomes a neighbor trapezoid")

    let edge = Self.spokeSweep(azimuth: 90, byte: 146)
    let mesh = Level3PolarGateMesh.build(sweep: edge)
    let cosLat = cos(edge.latitude * .pi / 180)
    let north = Level3PolarGateMesh.destination(
      lat0Deg: edge.latitude,
      lon0Deg: edge.longitude,
      metersPerDegLat: 111_320,
      metersPerDegLon: 111_320 * cosLat,
      sinAz: 0, cosAz: 1, rangeMeters: 5_000)
    let merc = Level3PolarGateMesh.mercatorXY(latitude: north.lat, longitude: north.lon)
    let hit = mesh.vertices.contains { v in
      abs(Double(v.mercX) - merc.x) < 0.00005 && abs(Double(v.mercY) - merc.y) < 0.00005
    }
    XCTAssertFalse(hit, "one-sided spoke edge must not grow north into clear air")
  }

  func testMetalMeshOverlapsNeighborGatesToKillHairlines() {
    XCTAssertGreaterThanOrEqual(Level3PolarGateMesh.azimuthPadDegrees, 0.05)
    XCTAssertLessThanOrEqual(Level3PolarGateMesh.azimuthPadDegrees, 0.15)
    XCTAssertEqual(Level3PolarGateMesh.rangePadGateFractions, 0.5, accuracy: 0.0001)

    var pattern = [UInt8](repeating: 0, count: 16)
    pattern[8] = 146
    pattern[9] = 96
    pattern[10] = 96
    let sweep = Self.spokeSweep(azimuth: 90, byte: 146, bins: 16, gatePattern: pattern)
    let mesh = Level3PolarGateMesh.build(sweep: sweep)
    XCTAssertEqual(mesh.triangleCount, 4, "same-byte 96 run still merges; 146 stays its own trap")
    XCTAssertEqual(mesh.vertices.count, 12)

    for t in 0..<2 {
      let base = t * 6
      let v0 = mesh.vertices[base]
      XCTAssertTrue(
        (0..<6).allSatisfy {
          mesh.vertices[base + $0].r == v0.r
            && mesh.vertices[base + $0].g == v0.g
            && mesh.vertices[base + $0].b == v0.b
            && mesh.vertices[base + $0].a == v0.a
        },
        "four corners of trap \(t) must stay constant-color")
    }

    let azPad = Level3PolarGateMesh.azimuthPadDegrees
    let trap0 = Array(mesh.vertices[0..<6])
    let azs = trap0.map { Self.azimuthDegrees(of: $0, sweep: sweep) }
    let azSpan = (azs.max() ?? 0) - (azs.min() ?? 0)
    XCTAssertEqual(
      azSpan, 0.5 + 2 * azPad, accuracy: 0.04,
      "neighbor radials must overlap in azimuth so GPU raster has no 1px crack")

    let gateW = sweep.gateWidthMeters
    let rangePad = gateW * Level3PolarGateMesh.rangePadGateFractions
    let ranges0 = trap0.map { Self.rangeMeters(of: $0, sweep: sweep) }
    let r0min = ranges0.min() ?? 0
    let r0max = ranges0.max() ?? 0
    XCTAssertEqual(r0min, 8 * gateW - rangePad, accuracy: 8)
    XCTAssertEqual(r0max, 9 * gateW + rangePad, accuracy: 8)

    let trap1 = Array(mesh.vertices[6..<12])
    let ranges1 = trap1.map { Self.rangeMeters(of: $0, sweep: sweep) }
    let r1min = ranges1.min() ?? 0
    XCTAssertLessThan(
      r1min, r0max,
      "consecutive range gates along a radial must overlap")
    XCTAssertGreaterThan(r0max - r1min, rangePad * 0.5)
  }

  func testPolarHostKeepsWholeLoopGPUCacheAndSnappyFade() {
    XCTAssertEqual(RadarLivePresentation.siteLoopMaxFrames, 24)
    XCTAssertEqual(
      Level3PolarMeshCache.maxEntries, RadarLivePresentation.siteLoopMaxFrames + 4)
    XCTAssertEqual(Level3PolarCrossfade.playDurationSeconds, 0.20, accuracy: 0.0001)
    XCTAssertEqual(Level3PolarCrossfade.stillDurationSeconds, 0.32, accuracy: 0.0001)
  }

  func testMetalMeshBuildsLiveAWSFileIfPresent() throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let file = root.appendingPathComponent(
      "scratch/radar-site-level3-2026-08-22/src/TWX_N0B_2026_08_22_13_39_44")
    guard FileManager.default.fileExists(atPath: file.path) else { return }
    let data = try Data(contentsOf: file)
    let sweep = try XCTUnwrap(Level3N0BDecoder.decode(data, siteHint: "TWX"))
    let mesh = Level3PolarGateMesh.build(sweep: sweep)
    XCTAssertGreaterThan(mesh.triangleCount, 1_000)
    XCTAssertLessThan(
      mesh.buildMilliseconds, 400,
      "mesh build must stay inside a 2x playback budget on CI")
    XCTAssertTrue(mesh.vertices.allSatisfy { $0.a > 0 })
  }

  func testPolarFrameTileKeyDistinctFromIEM() {
    let ts = Date(timeIntervalSince1970: 1_787_405_984)
    let iem = RadarFrame(
      provider: .iem,
      kind: .livePrecipitation,
      tileEpoch: Int(ts.timeIntervalSince1970),
      timestamp: ts,
      tileURLTemplates: ["https://example.com/ridge::TWX-N0B-202608221339/{z}/{x}/{y}.png"])
    let polar = RadarFrame(
      provider: .iem,
      kind: .livePrecipitation,
      tileEpoch: Int(ts.timeIntervalSince1970),
      timestamp: ts,
      tileURLTemplates: ["https://example.com/ridge::TWX-N0B-20260822133944/{z}/{x}/{y}.png"],
      paintsPolarRadials: true)
    XCTAssertFalse(polar.tileKey.contains(iem.tileKey))
    XCTAssertTrue(polar.tileKey.contains("p:"))
    XCTAssertFalse(iem.paintsPolarRadials)
  }

  func testPolarCrossfadeIsSnappyWhilePlaying() {
    XCTAssertEqual(
      Level3PolarCrossfade.durationSeconds(isAnimating: true), 0.20, accuracy: 0.0001)
    XCTAssertEqual(
      Level3PolarCrossfade.durationSeconds(isAnimating: false), 0.32, accuracy: 0.0001)
    XCTAssertEqual(
      MapsGLRadarPalette.liveRasterFadeDurationMs(
        provider: .iem, isAnimating: true, isFuture: false),
      700,
      accuracy: 0.0001,
      "IEM PNG fallback keeps the 700 ms raster fade")
    XCTAssertLessThan(
      Level3PolarCrossfade.durationSeconds(isAnimating: true) / 0.72,
      0.40,
      "2x hold is 720 ms; polar play fade must not dual-draw the whole interval")
    XCTAssertEqual(Level3PolarCrossfade.progress(elapsed: 0, duration: 0.2), 0)
    XCTAssertEqual(
      Level3PolarCrossfade.progress(elapsed: 0.1, duration: 0.2), 0.5, accuracy: 0.001)
    XCTAssertEqual(Level3PolarCrossfade.progress(elapsed: 1, duration: 0.2), 1)
    XCTAssertEqual(Level3PolarCrossfade.progress(elapsed: 0.1, duration: 0), 1)
    let mid = Level3PolarCrossfade.layerOpacities(progress: 0.5, global: 1)
    XCTAssertEqual(mid.outgoing, 0.5, accuracy: 0.001)
    XCTAssertEqual(mid.incoming, 0.5, accuracy: 0.001)
    let start = Level3PolarCrossfade.layerOpacities(progress: 0, global: 0.8)
    XCTAssertEqual(start.outgoing, 0.8, accuracy: 0.001)
    XCTAssertEqual(start.incoming, 0, accuracy: 0.001)
    let end = Level3PolarCrossfade.layerOpacities(progress: 1, global: 0.8)
    XCTAssertEqual(end.outgoing, 0, accuracy: 0.001)
    XCTAssertEqual(end.incoming, 0.8, accuracy: 0.001)
    let settled = Level3PolarCrossfade.drawOpacities(
      progress: 1, global: 0.8, isFading: false)
    XCTAssertEqual(settled.front, 0.8, accuracy: 0.001)
    XCTAssertEqual(settled.back, 0, accuracy: 0.001)
    let fading = Level3PolarCrossfade.drawOpacities(
      progress: 0.5, global: 1, isFading: true)
    XCTAssertEqual(fading.front, 0.5, accuracy: 0.001)
    XCTAssertEqual(fading.back, 0.5, accuracy: 0.001)
  }

  func testMeshCacheCoversLiveLoopAndStaysWarm() {
    XCTAssertGreaterThanOrEqual(
      Level3PolarMeshCache.maxEntries, RadarLivePresentation.siteLoopMaxFrames)
    let cache = Level3PolarMeshCache.shared
    cache.removeAll()
    defer { cache.removeAll() }

    var sweeps: [Level3N0BSweep] = []
    let base = Date(timeIntervalSince1970: 1_787_405_984)
    for i in 0..<22 {
      sweeps.append(
        Self.spokeSweep(
          azimuth: 90, byte: 146, bins: 4,
          timestamp: base.addingTimeInterval(Double(i * 180))))
    }
    cache.warmPlayLoop(sweeps)
    XCTAssertEqual(cache.stats().count, 22)
    cache.resetStats()
    for sweep in sweeps {
      _ = cache.mesh(for: sweep)
    }
    let after = cache.stats()
    XCTAssertEqual(after.misses, 0, "full-loop warm must keep Play on cache hits")
    XCTAssertEqual(after.hits, 22)
  }

  func testMeshCacheKeepOnlyDropsOtherVolumes() {
    let cache = Level3PolarMeshCache.shared
    cache.removeAll()
    defer { cache.removeAll() }
    let a = Self.spokeSweep(
      azimuth: 90, byte: 146, bins: 4,
      timestamp: Date(timeIntervalSince1970: 1_787_405_984))
    let b = Self.spokeSweep(
      azimuth: 90, byte: 146, bins: 4,
      timestamp: Date(timeIntervalSince1970: 1_787_406_164))
    _ = cache.mesh(for: a)
    _ = cache.mesh(for: b)
    cache.keepOnly(keys: [Level3N0BSweepStore.exactKey(site: a.siteID, timestamp: a.timestamp)])
    XCTAssertNotNil(cache.cached(site: a.siteID, timestamp: a.timestamp))
    XCTAssertNil(cache.cached(site: b.siteID, timestamp: b.timestamp))
  }

  func testWarmPendingCompletesAndWakesWaiters() async {
    let cache = Level3PolarMeshCache.shared
    cache.removeAll()
    defer { cache.removeAll() }
    XCTAssertTrue(cache.isWarmComplete)
    cache.markWarmPending()
    XCTAssertFalse(cache.isWarmComplete)
    let sweep = Self.spokeSweep(azimuth: 90, byte: 146, bins: 4)
    await cache.warmPlayLoopConcurrent([sweep])
    XCTAssertTrue(cache.isWarmComplete)
    XCTAssertNotNil(cache.cached(site: sweep.siteID, timestamp: sweep.timestamp))
  }

  func testMeshCacheCoalescesConcurrentBuilds() {
    let cache = Level3PolarMeshCache.shared
    cache.removeAll()
    defer { cache.removeAll() }
    let sweep = Self.spokeSweep(azimuth: 90, byte: 146, bins: 8)
    cache.resetStats()
    DispatchQueue.concurrentPerform(iterations: 4) { _ in
      _ = cache.mesh(for: sweep)
    }
    let stats = cache.stats()
    XCTAssertEqual(stats.misses, 1)
    XCTAssertEqual(stats.hits, 3)
    XCTAssertEqual(stats.count, 1)
  }

  // MARK: - Fixtures

  private static func spokeSweep(
    azimuth: Double, byte: UInt8, delta: Double = 0.5, bins: Int = 80,
    holeAzimuth: Double? = nil, holeByte: UInt8 = 86,
    timestamp: Date = Date(timeIntervalSince1970: 1_787_405_984),
    gatePattern: [UInt8]? = nil
  ) -> Level3N0BSweep {
    var radials: [Level3N0BSweep.Radial] = []
    for i in 0..<720 {
      let az = Double(i) * 0.5
      let gates: [UInt8]
      let inHole =
        holeAzimuth.map { min(abs(az - $0), 360 - abs(az - $0)) < 0.26 } ?? false
      let inSpoke = min(abs(az - azimuth), 360 - abs(az - azimuth)) < delta / 2 + 0.01
      if inHole {
        gates = [UInt8](repeating: holeByte, count: bins)
      } else if holeAzimuth != nil || inSpoke {
        if let gatePattern {
          gates = gatePattern
        } else {
          gates = [UInt8](repeating: byte, count: bins)
        }
      } else {
        gates = [UInt8](repeating: 0, count: bins)
      }
      radials.append(
        Level3N0BSweep.Radial(startAzimuth: az, deltaAzimuth: 0.5, gates: gates))
    }
    let lut = Level3N0BDecoder.dbzLUT(minValTenths: -320, incrementTenths: 5, numLevels: 254)
    return Level3N0BSweep(
      siteID: "TWX",
      timestamp: timestamp,
      latitude: 38.997,
      longitude: -96.232,
      gateWidthMeters: 250,
      binCount: bins,
      radials: radials,
      azIndex: Level3N0BDecoder.buildAzIndex(radials),
      dbzLUT: lut,
      rgbaLUT: Level3N0BDecoder.rgbaLUT(from: lut),
      hasOrganizedPrecip: true)
  }

  private static func latLon(of v: Level3PolarVertex) -> (lat: Double, lon: Double) {
    mercatorToLatLon(x: Double(v.mercX), y: Double(v.mercY))
  }

  private static func azimuthDegrees(of v: Level3PolarVertex, sweep: Level3N0BSweep) -> Double {
    let ll = latLon(of: v)
    let dLat = (ll.lat - sweep.latitude) * .pi / 180
    let dLon = (ll.lon - sweep.longitude) * .pi / 180
    let lat0 = sweep.latitude * .pi / 180
    let x = dLon * cos(lat0)
    let y = dLat
    var az = atan2(x, y) * 180 / .pi
    if az < 0 { az += 360 }
    return az
  }

  private static func rangeMeters(of v: Level3PolarVertex, sweep: Level3N0BSweep) -> Double {
    let site = Level3PolarGateMesh.mercatorXY(
      latitude: sweep.latitude, longitude: sweep.longitude)
    return groundMeters(
      Level3PolarVertex(
        mercX: Float(site.x), mercY: Float(site.y), r: 0, g: 0, b: 0, a: 0),
      v)
  }

  private static func groundMeters(_ a: Level3PolarVertex, _ b: Level3PolarVertex) -> Double {
    let aLL = mercatorToLatLon(x: Double(a.mercX), y: Double(a.mercY))
    let bLL = mercatorToLatLon(x: Double(b.mercX), y: Double(b.mercY))
    let lat1 = aLL.lat * .pi / 180
    let lat2 = bLL.lat * .pi / 180
    let dLat = lat2 - lat1
    let dLon = (bLL.lon - aLL.lon) * .pi / 180
    let h =
      sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
    return 2 * 6_371_000 * asin(min(1, sqrt(h)))
  }

  private static func mercatorToLatLon(x: Double, y: Double) -> (lat: Double, lon: Double) {
    let lon = x * 360 - 180
    let lat = atan(sinh(.pi * (1 - 2 * y))) * 180 / .pi
    return (lat, lon)
  }

  private static func azimuthSpanWithData(sweep: Level3N0BSweep, rangeMeters: Double) -> Double
  {
    var first: Double?
    var last: Double?
    var az = 0.0
    while az < 360 {
      if sweep.gateByte(rangeMeters: rangeMeters, azimuth: az) == 146 {
        if first == nil { first = az }
        last = az
      }
      az += 0.05
    }
    guard let first, let last else { return 0 }
    return last - first + 0.05
  }

  /// Uncompressed N0B (product 153) with one packet-16 radial. No bzip2.
  static func miniN0B(site: String, azimuths: [Double], gates: [UInt8]) -> Data {
    var radials = Data()
    for az in azimuths {
      radials.append(beU16(UInt16(gates.count)))
      radials.append(beI16(Int16((az * 10).rounded())))
      radials.append(beI16(5))  // 0.5°
      radials.append(contentsOf: gates)
    }
    var packet = Data()
    packet.append(beU16(16))
    packet.append(beU16(0))  // first bin
    packet.append(beU16(UInt16(gates.count)))
    packet.append(beI16(0))
    packet.append(beI16(0))
    packet.append(beI16(250))
    packet.append(beU16(UInt16(azimuths.count)))
    packet.append(radials)

    var layer = Data()
    layer.append(beI16(-1))
    layer.append(beU32(UInt32(packet.count)))
    layer.append(packet)

    var sym = Data()
    sym.append(beI16(-1))
    sym.append(beI16(1))
    sym.append(beU32(UInt32(10 + layer.count)))
    sym.append(beU16(1))
    sym.append(layer)

    var pdb = Data()
    pdb.append(beI16(-1))
    pdb.append(beI32(38_997))
    pdb.append(beI32(-96_232))
    pdb.append(beI16(1415))
    pdb.append(beI16(153))
    pdb.append(beI16(2))
    pdb.append(beI16(212))
    pdb.append(beI16(1))
    pdb.append(beI16(1))
    pdb.append(beU16(20_688))
    pdb.append(beI32(49_184))
    pdb.append(beU16(20_688))
    pdb.append(beI32(49_201))
    pdb.append(beI16(0))
    pdb.append(beI16(0))
    pdb.append(beI16(1))
    pdb.append(beI16(5))
    pdb.append(beI16(-320))
    pdb.append(beI16(5))
    pdb.append(beI16(254))
    for _ in 0..<13 { pdb.append(beI16(0)) }
    for _ in 0..<7 { pdb.append(beI16(0)) }  // dep4-10, compression 0
    pdb.append(UInt8(0))
    pdb.append(UInt8(0))
    pdb.append(beU32(60))  // symbology at byte 120
    pdb.append(beU32(0))
    pdb.append(beU32(0))
    XCTAssertEqual(pdb.count, 102)

    var msg = Data()
    msg.append(beU16(153))
    msg.append(beU16(20_688))
    msg.append(beI32(49_184))
    msg.append(beU32(UInt32(18 + 102 + sym.count)))
    msg.append(beI16(0))
    msg.append(beI16(0))
    msg.append(beU16(3))
    msg.append(pdb)
    msg.append(sym)

    var file = Data("SDUS53 KTOP 221339\r\r\nN0B\(site)\r\r\n".utf8)
    file.append(msg)
    return file
  }

  private static func beU16(_ v: UInt16) -> Data {
    Data([UInt8(v >> 8), UInt8(v & 0xFF)])
  }
  private static func beI16(_ v: Int16) -> Data { beU16(UInt16(bitPattern: v)) }
  private static func beU32(_ v: UInt32) -> Data {
    Data([
      UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF),
      UInt8(v & 0xFF),
    ])
  }
  private static func beI32(_ v: Int32) -> Data { beU32(UInt32(bitPattern: v)) }

  private static func destination(
    lat: Double, lon: Double, azimuth: Double, rangeMeters: Double
  ) -> (lat: Double, lon: Double) {
    let earthR = 6_371_000.0
    let d = rangeMeters / earthR
    let az = azimuth * .pi / 180
    let lat1 = lat * .pi / 180
    let lon1 = lon * .pi / 180
    let lat2 = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(az))
    let lon2 =
      lon1 + atan2(sin(az) * sin(d) * cos(lat1), cos(d) - sin(lat1) * sin(lat2))
    return (lat2 * 180 / .pi, lon2 * 180 / .pi)
  }

  /// Transparent pixels with opaque precip on opposite sides — the white rays.
  static func sandwichedTransparentPixels(in png: Data) -> Int {
    guard let source = CGImageSourceCreateWithData(png as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return -1 }
    let w = image.width
    let h = image.height
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    let info = CGImageAlphaInfo.premultipliedLast.rawValue
    let count = pixels.withUnsafeMutableBytes { raw -> Int in
      guard
        let ctx = CGContext(
          data: raw.baseAddress,
          width: w,
          height: h,
          bitsPerComponent: 8,
          bytesPerRow: w * 4,
          space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: info),
        let buf = raw.baseAddress?.assumingMemoryBound(to: UInt8.self)
      else { return -1 }
      ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
      func opaque(_ row: Int, _ col: Int) -> Bool {
        buf[(row * w + col) * 4 + 3] > 0
      }
      var n = 0
      if w < 3 || h < 3 { return 0 }
      for row in 1..<(h - 1) {
        for col in 1..<(w - 1) {
          if opaque(row, col) { continue }
          let nB = opaque(row - 1, col)
          let sB = opaque(row + 1, col)
          let eB = opaque(row, col + 1)
          let wB = opaque(row, col - 1)
          let nw = opaque(row - 1, col - 1)
          let se = opaque(row + 1, col + 1)
          let ne = opaque(row - 1, col + 1)
          let sw = opaque(row + 1, col - 1)
          if (nB && sB) || (eB && wB) || (nw && se) || (ne && sw) {
            n += 1
          }
        }
      }
      return n
    }
    return count
  }
}
