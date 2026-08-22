#if DEBUG
import Foundation

/// Debug-only flags for development and testing.
/// These have no effect in Release builds.
enum DebugFlags {
  /// Spike: paint Mac-generated NOAA composite overlay instead of MapsGL rain
  /// on Live National. Off = today's National unchanged. Never a Live default.
  /// Simulator reads the PNG from the local scratch path; the phone does not
  /// download GRIB2.
  private static let nationalOverlayKey = "radar.debug.nationalOverlay"

  static var nationalOverlay: Bool {
    get { UserDefaults.standard.bool(forKey: nationalOverlayKey) }
    set { UserDefaults.standard.set(newValue, forKey: nationalOverlayKey) }
  }
}
#endif
