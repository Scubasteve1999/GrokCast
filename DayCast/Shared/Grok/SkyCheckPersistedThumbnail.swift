import UIKit

/// Policy for Sky Check thumbs that ride along in SwiftData.
///
/// Persist a small JPEG only — never the camera/library original,
/// `lastStormImageData`, or vision-upload bytes. Caps are so one city
/// thread cannot balloon.
enum SkyCheckPersistedThumbnail {
  static let maxDimension: CGFloat = 150
  static let jpegQuality: CGFloat = 0.6
  /// Drop a thumb that is still larger than this after compress. Text stays.
  static let maxBytes = 32 * 1024
  /// Newest photo turns keep thumbs; older photo turns stay text-only.
  static let maxThumbsPerCity = 12

  /// Small JPEG suitable for `ChatMessageEntity.thumbnailData`.
  /// Already-small thumbs (≤150px, ≤`maxBytes`) are kept as-is so the
  /// in-memory `compressedForVision(maxDimension: 150, quality: 0.6)`
  /// bytes round-trip. Undecodable or still-oversized data is dropped.
  static func jpeg(from original: Data?) -> Data? {
    guard let original, !original.isEmpty else { return nil }
    guard let image = UIImage(data: original) else { return nil }

    let longest = max(image.size.width * image.scale, image.size.height * image.scale)
    if longest <= maxDimension + 0.5, original.count <= maxBytes {
      return original
    }

    guard let compressed = original.compressedForVision(
      maxDimension: maxDimension, quality: jpegQuality),
      compressed.count <= maxBytes,
      UIImage(data: compressed) != nil
    else {
      return nil
    }
    return compressed
  }

  /// Newest-first map of user-turn IDs to thumbs that pass the city cap.
  /// Assistant / Imagine payloads are never included.
  static func byMessageID(in messages: [ChatMessage]) -> [UUID: Data] {
    var result: [UUID: Data] = [:]
    var remaining = maxThumbsPerCity
    for message in messages.reversed() {
      guard remaining > 0, message.role == .user else { continue }
      guard let jpeg = jpeg(from: message.imageData) else { continue }
      result[message.id] = jpeg
      remaining -= 1
    }
    return result
  }
}
