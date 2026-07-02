import CoreLocation
import Foundation

// MARK: - DEAD (legacy fallback provider)
// IEM (NWS via Iowa Environmental Mesonet) was previously a live radar fallback.
// NOW mode is Xweather-only; this is no longer called for live radar.
// Kept for reference / potential future use. Do not use for active NOW path.

/// Service for fetching recent NEXRAD radar frames from IEM (Iowa Environmental Mesonet)
/// and producing tile URLs for Mapbox / tile renderers.
/// Uses RIDGE cached TMS for reliable, official NWS-sourced imagery (US-focused, better fidelity).
struct IEMRadarFrame: Equatable {
  let time: Int
  let path: String
}

final class IEMRadarService {

  static let fallbackSite = "USCOMP"  // National mosaic; good default overview. Site-specific e.g. "NQA" for local.
  private static let baseTileHost = "https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0"

  /// Load recent past frames (approx last 2 hours @ ~5 min cadence).
  /// Uses synthetic recent timestamps rounded to 5-minute boundaries (IEM composites update ~every 5 min).
  /// Non-fatal: returns empty on any issue (caller falls back).
  static func loadRecentFrames(
    product: NWSRadarProduct = .reflectivity,
    site: String = fallbackSite,
    maxFrames: Int = 24
  ) async -> [IEMRadarFrame] {
    let now = Date()
    let interval: TimeInterval = 5 * 60

    // Round down to last 5-min mark (UTC for IEM)
    let calendar = Calendar(identifier: .gregorian)
    var components = calendar.dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: now)
    let minute = components.minute ?? 0
    components.minute = (minute / 5) * 5
    components.second = 0
    guard let roundedNow = calendar.date(from: components) else {
      return []
    }

    var frames: [IEMRadarFrame] = []
    for i in 0..<maxFrames {
      let frameDate = roundedNow.addingTimeInterval(-Double(i) * interval)
      let ts = Self.iemTimestamp(from: frameDate)  // YYYYMMDDHHmm
      // Layer format: ridge::SITE-PRODUCT-TIMESTAMP   (use 0 for latest if wanted, but timestamp for past)
      let layer = "ridge::\(site)-\(product.rawValue)-\(ts)"
      let path = "/\(layer)"  // The "path" here encodes the full layer for URL builder
      frames.append(IEMRadarFrame(time: Int(frameDate.timeIntervalSince1970), path: path))
    }

    // Return in chronological order (oldest first) so playback makes sense; UI often reverses or uses last as "now"
    return frames.reversed()
  }

  /// Build the full tile URL template (or concrete for a baked time) for use in Mapbox RasterSource.
  /// When used as template, caller typically bakes the specific frame's layer/time into a concrete URL per frame change.
  static func tileURLTemplate(layerOrPath: String) -> String {
    // layerOrPath is expected to be like "/ridge::USCOMP-N0Q-202606271430"
    // or the caller can pass the full baked layer segment.
    "\(baseTileHost)\(layerOrPath)/{z}/{x}/{y}.png"
  }

  /// Convenience: given an IEMRadarFrame whose .path holds the IEM layer segment, produce a ready-to-use tile URL (no {z} etc).
  /// Used when we commit specific frames (similar to rainviewer normalized path).
  static func tileURL(for framePath: String) -> String {
    // framePath already starts with /ridge::...
    "\(baseTileHost)\(framePath)/{z}/{x}/{y}.png"
  }

  private static func iemTimestamp(from date: Date) -> String {
    let f = DateFormatter()
    f.timeZone = TimeZone(secondsFromGMT: 0)!
    f.dateFormat = "yyyyMMddHHmm"
    return f.string(from: date)
  }
}

// MARK: - /DEAD (legacy IEM provider)
