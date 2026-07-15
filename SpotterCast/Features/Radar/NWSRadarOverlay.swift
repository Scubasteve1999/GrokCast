import MapKit
import Foundation
// MARK: - Fixed NWS/RainViewer Radar Overlay (Persistent + smooth animation)
final class NWSRadarOverlay: MKTileOverlay {
    var timestamp: String?   // var = can update frames for Play button

    init(timestamp: String? = nil) {
        self.timestamp = timestamp
        super.init(urlTemplate: nil)           // Dynamic URL – we override below
        self.canReplaceMapContent = false      // ← CRITICAL: keeps roads/cities visible
    }

    /// Called by Play button / timer – updates frame without removing overlay
    func updateTimestamp(_ newTS: String) {
        self.timestamp = newTS
        print("[RADAR] ✅ Updated frame → \(newTS)")
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let ts = timestamp ?? "9c66380ab050"   // fallback frame that always shows color
        let urlString = "https://tilecache.rainviewer.com/v2/radar/\(ts)/256/\(path.z)/\(path.x)/\(path.y)/2/1_1.png?v=\(Int(Date().timeIntervalSince1970))"
        
        print("[RADAR TILE] z=\(path.z) x=\(path.x) y=\(path.y) ts=\(ts)")
        return URL(string: urlString)!
    }
}
