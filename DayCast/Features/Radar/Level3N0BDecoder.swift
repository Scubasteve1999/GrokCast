import Foundation

/// NEXRAD Level III Super-Res Reflectivity (N0B / product 153).
/// AWS `unidata-nexrad-level3` files: WMO/AWIPS text + PDB + bzip2 packet-16 radials.
enum Level3N0BDecoder {
  static let productCode: UInt16 = 153
  static let superResRangeKm = 460.0
  static let superResGateMeters = 250.0
  static let precipFloorDbz: Float = 15
  private static let crlfcr = Data([0x0D, 0x0D, 0x0A])
  private static let bzipMagic = Data([0x42, 0x5A, 0x68])

  static func decode(_ data: Data, siteHint: String? = nil) -> Level3N0BSweep? {
    let stripped = stripWMO(data)
    return parseProduct(stripped.body, siteHint: siteHint ?? stripped.site)
  }

  /// Digital reflectivity LUT used by N0B (ICD DigitalRefMapper).
  static func dbzLUT(minValTenths: Int16, incrementTenths: Int16, numLevels: Int16) -> [Float]
  {
    var lut = [Float](repeating: .nan, count: 256)
    let minVal = Float(minValTenths) * 0.1
    let inc = Float(incrementTenths) * 0.1
    let levels = min(max(Int(numLevels), 0), 254)
    if levels == 0 { return lut }
    for i in 0..<levels {
      let idx = i + 2
      if idx < 256 {
        lut[idx] = minVal + Float(i) * inc
      }
    }
    return lut
  }

  static func rgbaLUT(from dbzLUT: [Float]) -> [(UInt8, UInt8, UInt8, UInt8)] {
    let stops = MapsGLRadarPalette.reflectivityStops
    var table = [(UInt8, UInt8, UInt8, UInt8)](repeating: (0, 0, 0, 0), count: 256)
    for b in 0..<256 {
      let dbz = dbzLUT[b]
      if dbz.isNaN || dbz < precipFloorDbz { continue }
      let band = min(70, max(0, (Double(dbz) / 5).rounded(.down) * 5))
      if band < 15 { continue }
      guard let stop = stops.last(where: { $0.dbz <= band && $0.alpha > 0 }) else { continue }
      table[b] = premul(hex: stop.hex, alpha: MapsGLRadarPalette.polarUnderlayAlpha(forDbz: band))
    }
    return table
  }

  static func nexradDate(days: UInt16, seconds: Int32) -> Date {
    let unix = Double(Int(days) - 1) * 86_400 + Double(seconds)
    return Date(timeIntervalSince1970: unix)
  }

  // MARK: - Parse

  private struct WMOStrip {
    var body: Data
    var site: String?
  }

  private static func stripWMO(_ data: Data) -> WMOStrip {
    guard data.count > 24 else { return WMOStrip(body: data, site: nil) }
    let head = data.prefix(80)
    guard let first = head.range(of: crlfcr) else { return WMOStrip(body: data, site: nil) }
    let rest = first.upperBound..<head.endIndex
    guard let second = data.range(of: crlfcr, in: rest),
      second.upperBound <= data.index(data.startIndex, offsetBy: min(80, data.count))
    else { return WMOStrip(body: data, site: nil) }
    let awips = data[first.upperBound..<second.lowerBound]
    var site: String?
    if awips.count >= 6, let text = String(data: Data(awips), encoding: .ascii) {
      if text.hasPrefix("N0B") {
        site = String(text.dropFirst(3).prefix(3)).trimmingCharacters(in: .whitespaces)
      }
    }
    return WMOStrip(body: data.subdata(in: second.upperBound..<data.endIndex), site: site)
  }

  private static func parseProduct(_ data: Data, siteHint: String?) -> Level3N0BSweep? {
    guard data.count >= 120 else { return nil }
    var r = Level3Cursor(data: data)
    let code = r.u16()
    guard code == productCode else { return nil }
    let msgDate = r.u16()
    let msgTime = r.i32()
    r.skip(4)  // msg_len
    r.skip(2)  // src
    r.skip(2)  // dest
    r.skip(2)  // nblocks
    _ = msgDate
    _ = msgTime

    let divider = r.i16()
    guard divider == -1 else { return nil }
    let latE3 = r.i32()
    let lonE3 = r.i32()
    r.skip(2)  // height
    let pcode = r.i16()
    guard UInt16(bitPattern: pcode) == productCode else { return nil }
    r.skip(2)  // op_mode
    r.skip(2)  // vcp
    r.skip(2)  // seq
    r.skip(2)  // vol_num
    let volDate = r.u16()
    let volTime = r.i32()
    r.skip(2)  // prod_gen_date
    r.skip(4)  // prod_gen_time
    r.skip(2)  // dep1
    r.skip(2)  // dep2
    r.skip(2)  // el_num
    r.skip(2)  // dep3
    let thr1 = r.i16()
    let thr2 = r.i16()
    let thr3 = r.i16()
    r.skip(2 * 13)  // thr4-16
    r.skip(2 * 3)  // dep4-6
    r.skip(2)  // dep7
    let dep8 = r.i16()  // 1 = bzip2 symbology
    let dep9 = r.i16()
    let dep10 = r.i16()
    r.skip(1)  // version
    r.skip(1)  // spot
    let symOffHalf = r.u32()
    r.skip(4)  // graph
    r.skip(4)  // tab

    let timestamp = nexradDate(days: volDate, seconds: volTime)
    let lat = Double(latE3) * 0.001
    let lon = Double(lonE3) * 0.001
    let uncompressed = combineUnsigned(dep9, dep10)
    let compressed = dep8 != 0

    let lut = dbzLUT(minValTenths: thr1, incrementTenths: thr2, numLevels: thr3)
    let colors = rgbaLUT(from: lut)

    let symStart = Int(symOffHalf) * 2
    guard symStart >= 0, symStart < data.count else { return nil }
    var symbology = data.subdata(in: symStart..<data.count)
    if symbology.starts(with: bzipMagic) || compressed {
      guard let inflated = Level3BZip2.decompress(symbology, uncompressedSize: uncompressed)
      else { return nil }
      symbology = inflated
    }

    guard let parsed = parseSymbology(symbology) else { return nil }
    let gateWidth = parsed.binCount > 0
      ? superResRangeKm * 1000 / Double(parsed.binCount)
      : superResGateMeters
    let azIndex = buildAzIndex(parsed.radials)
    let wet = organizedPrecip(radials: parsed.radials, lut: lut)

    return Level3N0BSweep(
      siteID: siteHint ?? "",
      timestamp: timestamp,
      latitude: lat,
      longitude: lon,
      gateWidthMeters: gateWidth,
      binCount: parsed.binCount,
      radials: parsed.radials,
      azIndex: azIndex,
      dbzLUT: lut,
      rgbaLUT: colors,
      hasOrganizedPrecip: wet)
  }

  private struct ParsedRadials {
    var binCount: Int
    var radials: [Level3N0BSweep.Radial]
  }

  private static func parseSymbology(_ data: Data) -> ParsedRadials? {
    guard data.count >= 16 else { return nil }
    var r = Level3Cursor(data: data)
    let divider = r.i16()
    let blockID = r.i16()
    r.skip(4)  // block_len
    let nlayer = r.u16()
    guard divider == -1, blockID == 1, nlayer >= 1 else { return nil }
    let layerDiv = r.i16()
    let layerLen = r.u32()
    guard layerDiv == -1, layerLen > 14, r.remaining >= Int(layerLen) else { return nil }
    let packet = r.u16()
    guard packet == 16 else { return nil }
    r.skip(2)  // ind_first_bin
    let nbins = Int(r.u16())
    r.skip(2)  // i_center
    r.skip(2)  // j_center
    r.skip(2)  // scale_factor (display pixels; N0B gates are 0.25 km)
    let nrad = Int(r.u16())
    guard nrad > 0, nrad <= 1440, nbins > 0, nbins <= 4096 else { return nil }

    var radials: [Level3N0BSweep.Radial] = []
    radials.reserveCapacity(nrad)
    for _ in 0..<nrad {
      let nbytes = Int(r.u16())
      let start = Double(r.i16()) * 0.1
      let delta = Double(r.i16()) * 0.1
      guard nbytes >= 0, r.remaining >= nbytes else { return nil }
      let gates = r.bytes(nbytes)
      radials.append(
        Level3N0BSweep.Radial(
          startAzimuth: start, deltaAzimuth: delta > 0 ? delta : 0.5, gates: gates))
    }
    return ParsedRadials(binCount: nbins, radials: radials)
  }

  /// Map every 0.5° slot to the radial whose `[start, start+delta)` contains the
  /// slot center. Super-Res N0B deltas jitter 0.4/0.5/0.6 — filling
  /// `ceil(delta/0.5)` slots from `floor(start/0.5)` lets 0.5° radials steal
  /// the 0.4° neighbor's only slot (~73 unused radials on a 720-radial TWX
  /// sweep). Slot-center assignment keeps all radials and leaves no 0xFFFF holes.
  static func buildAzIndex(_ radials: [Level3N0BSweep.Radial]) -> [UInt16] {
    var table = [UInt16](repeating: 0xFFFF, count: 720)
    for (i, radial) in radials.enumerated() {
      var az = radial.startAzimuth.truncatingRemainder(dividingBy: 360)
      if az < 0 { az += 360 }
      let span = radial.deltaAzimuth > 0 ? radial.deltaAzimuth : 0.5
      let startSlot = Int((az / 0.5).rounded(.down))
      let steps = max(1, Int((span / 0.5).rounded(.up)) + 2)
      for s in -1..<steps {
        var slot = (startSlot + s) % 720
        if slot < 0 { slot += 720 }
        let mid = Double(slot) * 0.5 + 0.25
        var d = mid - az
        if d < 0 { d += 360 }
        if d < span {
          table[slot] = UInt16(i)
        }
      }
    }
    if table.contains(0xFFFF), let seed = table.first(where: { $0 != 0xFFFF }) {
      var last = seed
      for i in 0..<720 {
        if table[i] == 0xFFFF {
          table[i] = last
        } else {
          last = table[i]
        }
      }
    }
    return table
  }

  /// Wet iff any gate ≥30 dBZ. Clear-air / AP / biological 15–25 dBZ shafts do not count.
  static func organizedPrecip(
    radials: [Level3N0BSweep.Radial], lut: [Float]
  ) -> Bool {
    let coreDbz: Float = 30
    for radial in radials {
      for byte in radial.gates {
        let idx = Int(byte)
        guard idx < lut.count else { continue }
        let dbz = lut[idx]
        if dbz.isNaN { continue }
        if dbz >= coreDbz { return true }
      }
    }
    return false
  }

  private static func combineUnsigned(_ a: Int16, _ b: Int16) -> Int {
    (Int(UInt16(bitPattern: a)) << 16) | Int(UInt16(bitPattern: b))
  }

  private static func premul(hex: String, alpha: Double) -> (UInt8, UInt8, UInt8, UInt8) {
    var s = hex
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let v = UInt32(s, radix: 16) else { return (0, 0, 0, 0) }
    let r = Double((v >> 16) & 0xFF)
    let g = Double((v >> 8) & 0xFF)
    let b = Double(v & 0xFF)
    let a = min(1, max(0, alpha))
    return (
      UInt8(min(255, (r * a).rounded())),
      UInt8(min(255, (g * a).rounded())),
      UInt8(min(255, (b * a).rounded())),
      UInt8(min(255, (a * 255).rounded()))
    )
  }
}

private struct Level3Cursor {
  let data: Data
  var offset = 0

  var remaining: Int { data.count - offset }

  mutating func skip(_ n: Int) { offset += n }

  mutating func u8() -> UInt8 {
    let v = data[offset]
    offset += 1
    return v
  }

  mutating func u16() -> UInt16 {
    let v = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    offset += 2
    return v
  }

  mutating func i16() -> Int16 { Int16(bitPattern: u16()) }

  mutating func i32() -> Int32 { Int32(bitPattern: u32()) }

  mutating func u32() -> UInt32 {
    let v =
      UInt32(data[offset]) << 24
      | UInt32(data[offset + 1]) << 16
      | UInt32(data[offset + 2]) << 8
      | UInt32(data[offset + 3])
    offset += 4
    return v
  }

  mutating func bytes(_ n: Int) -> [UInt8] {
    let end = offset + n
    let slice = data[offset..<end]
    offset = end
    return Array(slice)
  }
}
