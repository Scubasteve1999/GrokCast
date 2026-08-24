import Foundation
import SwiftData

/// Lightweight SwiftData persistence model for Grok AI chat messages.
/// Persists role + content + timestamp + generated image URLs (for Grok AI image gen results).
/// Sky Check photo turns persist a small JPEG `thumbnailData` only — never the
/// camera/library original. Legacy rows with nil thumb load as text.
@Model
final class ChatMessageEntity {
  var id: UUID
  var role: String
  var content: String
  var timestamp: Date
  var generatedImageURLString: String?  // stored as String for simplicity / Codable
  /// Selected city this turn belongs to. Nil = legacy unscoped row; discarded on load.
  var locationID: UUID?
  /// Capped JPEG thumb for a Sky Check user photo turn. Nil = text-only.
  var thumbnailData: Data?

  init(
    id: UUID = UUID(),
    role: String,
    content: String,
    timestamp: Date = Date(),
    generatedImageURLString: String? = nil,
    locationID: UUID? = nil,
    thumbnailData: Data? = nil
  ) {
    self.id = id
    self.role = role
    self.content = content
    self.timestamp = timestamp
    self.generatedImageURLString = generatedImageURLString
    self.locationID = locationID
    self.thumbnailData = thumbnailData
  }

  /// `thumbnailData` must already be the policy-approved JPEG (or nil).
  /// Do not pass `message.imageData` blindly — it may be a full-res original.
  convenience init(from message: ChatMessage, locationID: UUID, thumbnailData: Data?) {
    self.init(
      id: message.id,
      role: message.role.rawValue,
      content: message.content,
      timestamp: message.timestamp,
      generatedImageURLString: message.generatedImageURL?.absoluteString,
      locationID: locationID,
      thumbnailData: thumbnailData
    )
  }

  func toChatMessage() -> ChatMessage {
    let parsedRole = ChatMessage.Role(rawValue: role) ?? .assistant
    let url = generatedImageURLString.flatMap { URL(string: $0) }
    let thumb: Data?
    if let thumbnailData,
      thumbnailData.count <= SkyCheckPersistedThumbnail.maxBytes,
      thumbnailData.count >= 2
    {
      thumb = thumbnailData
    } else {
      thumb = nil
    }
    return ChatMessage(
      id: id,
      role: parsedRole,
      content: content,
      timestamp: timestamp,
      imageData: thumb,
      generatedImageURL: url
    )
  }
}
