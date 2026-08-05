import Foundation
import SwiftData

/// Lightweight SwiftData persistence model for Grok AI chat messages.
/// Persists role + content + timestamp + generated image URLs (for Grok AI image gen results).
/// Storm-specific fields (imageData, notes) remain transient.
@Model
final class ChatMessageEntity {
  var id: UUID
  var role: String
  var content: String
  var timestamp: Date
  var generatedImageURLString: String?  // stored as String for simplicity / Codable

  init(
    id: UUID = UUID(),
    role: String,
    content: String,
    timestamp: Date = Date(),
    generatedImageURLString: String? = nil
  ) {
    self.id = id
    self.role = role
    self.content = content
    self.timestamp = timestamp
    self.generatedImageURLString = generatedImageURLString
  }

  convenience init(from message: ChatMessage) {
    self.init(
      id: message.id,
      role: message.role.rawValue,
      content: message.content,
      timestamp: message.timestamp,
      generatedImageURLString: message.generatedImageURL?.absoluteString
    )
  }

  func toChatMessage() -> ChatMessage {
    let parsedRole = ChatMessage.Role(rawValue: role) ?? .assistant
    let url = generatedImageURLString.flatMap { URL(string: $0) }
    return ChatMessage(
      id: id,
      role: parsedRole,
      content: content,
      timestamp: timestamp,
      generatedImageURL: url
    )
  }
}
