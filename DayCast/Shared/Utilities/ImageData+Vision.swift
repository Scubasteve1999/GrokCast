import UIKit

extension Data {
  /// Resizes for vision API calls (default max 1024px, JPEG 0.75) so base64
  /// payloads stay under typical 422/400 limits. Sky Check chat thumbs use
  /// 150px / 0.6 via `SkyCheckPersistedThumbnail` (that JPEG is what SwiftData stores).
  func compressedForVision(maxDimension: CGFloat = 1024, quality: CGFloat = 0.75) -> Data? {
    guard let image = UIImage(data: self) else { return nil }

    let size = image.size
    let scale = Swift.min(maxDimension / Swift.max(size.width, size.height), 1.0)
    let newSize = CGSize(width: size.width * scale, height: size.height * scale)

    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
    image.draw(in: CGRect(origin: .zero, size: newSize))
    let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return resizedImage?.jpegData(compressionQuality: quality)
  }
}
