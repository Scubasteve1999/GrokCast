import Foundation
import MapKit

/// MKTileOverlay for NWS ridge radar imagery via the IEM tile service (US-focused, latest frame).
final class NWSRadarOverlay: MKTileOverlay {
  let product: NWSRadarProduct
  let siteID: String
  private let effectiveMaxZ: Int

  init(product: NWSRadarProduct, siteID: String) {
    self.product = product
    self.siteID = siteID
    // Live probes: USCOMP-N0Q has real data through z=8; z=9+ returns empty tiles.
    self.effectiveMaxZ = product.usesUSComposite ? 8 : 12
    let layer = Self.layerName(siteID: siteID, product: product)
    let template =
      "https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/ridge::\(layer)/{z}/{x}/{y}.png"
    super.init(urlTemplate: template)
    canReplaceMapContent = false
    minimumZ = 0
    maximumZ = effectiveMaxZ
  }

  /// IEM ridge TMS layer name, e.g. `USCOMP-N0Q-0` or `NQA-N0U-0`.
  static func layerName(siteID: String, product: NWSRadarProduct) -> String {
    "\(siteID)-\(product.iemProductCode)-0"
  }

  var layerLabel: String {
    Self.layerName(siteID: siteID, product: product)
  }

  override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
    RadarTileClamp.loadTile(
      on: self,
      at: path,
      maxZ: effectiveMaxZ,
      fetchParent: { parentPath, parentResult in
        super.loadTile(at: parentPath, result: parentResult)
      },
      result: result
    )
  }
}
