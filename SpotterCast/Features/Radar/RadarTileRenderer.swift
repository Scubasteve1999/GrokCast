import MapKit

/// Lightweight MKTileOverlayRenderer subclass to support dynamic, live alpha/opacity
/// updates for the radar overlay via the opacity slider.
///
/// The stock MKTileOverlayRenderer 'alpha' can be set at creation but live changes
/// after the overlay is added to the map (e.g. during slider drag or anim frame)
/// are unreliable without subclassing + explicit setNeedsDisplay().
/// This keeps control minimal, contained, and radar-specific (no impact on pins/user location/other overlays).
final class RadarTileRenderer: MKTileOverlayRenderer {

  public var radarOpacity: CGFloat = 0.75 {
    didSet {
      if alpha != radarOpacity {
        alpha = radarOpacity
        setNeedsDisplay()
      }
    }
  }

  // ✅ Required initializer
  override init(overlay: MKOverlay) {
    super.init(overlay: overlay)
    self.alpha = radarOpacity
  }

  // Keep this too (for convenience)
  override init(tileOverlay: MKTileOverlay) {
    super.init(tileOverlay: tileOverlay)
    self.alpha = radarOpacity
  }
}
