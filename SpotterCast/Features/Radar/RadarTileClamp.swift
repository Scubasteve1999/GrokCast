import MapKit
import UIKit

/// Remaps high-zoom tile requests to parent tiles and crops the correct subsection.
/// MapKit may request z>maximumZ while zooming; returning the full parent tile in each
/// child slot breaks display — crop + upscale to 256×256 keeps precip visible when zoomed in.
enum RadarTileClamp {
  static func clamped(_ path: MKTileOverlayPath, toMaxZ maxZ: Int) -> MKTileOverlayPath {
    guard path.z > maxZ else { return path }
    var clamped = path
    let shift = path.z - maxZ
    clamped.z = maxZ
    clamped.x = path.x >> shift
    clamped.y = path.y >> shift
    return clamped
  }

  /// Loads a tile, cropping from the nearest parent when `path.z` exceeds `maxZ`.
  static func loadTile(
    on overlay: MKTileOverlay,
    at path: MKTileOverlayPath,
    maxZ: Int,
    fetchParent: (MKTileOverlayPath, @escaping (Data?, Error?) -> Void) -> Void,
    result: @escaping (Data?, Error?) -> Void
  ) {
    guard path.z > maxZ else {
      fetchParent(path, result)
      return
    }

    let parentPath = clamped(path, toMaxZ: maxZ)
    fetchParent(parentPath) { data, error in
      if let error {
        result(nil, error)
        return
      }
      guard let data, !data.isEmpty else {
        result(
          nil,
          NSError(
            domain: "RadarTileClamp", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Empty parent tile at z=\(parentPath.z)"]))
        return
      }
      result(cropChildTile(from: data, childPath: path, maxZ: maxZ), nil)
    }
  }

  private static func cropChildTile(
    from parentData: Data, childPath: MKTileOverlayPath, maxZ: Int
  ) -> Data? {
    guard let image = UIImage(data: parentData), let cgImage = image.cgImage else {
      return parentData
    }

    let shift = childPath.z - maxZ
    let scale = 1 << shift
    let tilePixels = max(Int(image.size.width), 1)
    let cell = tilePixels / scale
    let localX = childPath.x % scale
    let localY = childPath.y % scale

    let cropRect = CGRect(
      x: CGFloat(localX * cell) * image.scale,
      y: CGFloat(localY * cell) * image.scale,
      width: CGFloat(cell) * image.scale,
      height: CGFloat(cell) * image.scale
    )

    guard let cropped = cgImage.cropping(to: cropRect) else { return parentData }

    let outputSize = CGSize(width: tilePixels, height: tilePixels)
    let renderer = UIGraphicsImageRenderer(size: outputSize)
    let upscaled = renderer.image { _ in
      UIImage(cgImage: cropped).draw(in: CGRect(origin: .zero, size: outputSize))
    }
    return upscaled.pngData()
  }
}
