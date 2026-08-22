#if DEBUG
import Foundation

/// Debug-only flags for development and testing.
/// These have no effect in Release builds.
enum DebugFlags {
  /// Live National paint override. Auto (default) uses MRMS tiles when the
  /// local worker/CDN is fresh, else MapsGL rain. Chrome never says MRMS.
  enum NationalPaint: String, CaseIterable, Identifiable {
    case auto
    case forceTiles = "tiles"
    case forceMapsGL = "mapsgl"

    var id: String { rawValue }

    var debugLabel: String {
      switch self {
      case .auto: "Auto"
      case .forceTiles: "Force National tiles"
      case .forceMapsGL: "Force MapsGL rain"
      }
    }
  }

  private static let nationalPaintKey = "radar.debug.nationalPaint"

  static var nationalPaint: NationalPaint {
    get {
      let raw = UserDefaults.standard.string(forKey: nationalPaintKey) ?? ""
      return NationalPaint(rawValue: raw) ?? .auto
    }
    set { UserDefaults.standard.set(newValue.rawValue, forKey: nationalPaintKey) }
  }
}
#endif
