import Foundation

struct ChatMessage: Identifiable, Equatable {
  let id: UUID
  let role: Role
  let content: String
  let timestamp: Date
  /// Sky Check user-turn thumbnail (small JPEG). Full camera/library bytes stay
  /// on the VM as `lastStormImageData` and are never written to SwiftData.
  let imageData: Data?
  let isStormSpotterAnalysis: Bool
  let originalNotes: String?
  let generatedImageURL: URL?  // for Grok image generation results shown in chat

  /// Sky Check assistant card: analysis markdown vs glance. One persisted flag.
  var usesSkyCheckAnalysisCard: Bool { isStormSpotterAnalysis }

  enum Role: String {
    case system
    case user
    case assistant
  }

  init(
    id: UUID = UUID(),
    role: Role,
    content: String,
    timestamp: Date = Date(),
    imageData: Data? = nil,
    isStormSpotterAnalysis: Bool = false,
    originalNotes: String? = nil,
    generatedImageURL: URL? = nil
  ) {
    self.id = id
    self.role = role
    self.content = content
    self.timestamp = timestamp
    self.imageData = imageData
    self.isStormSpotterAnalysis = isStormSpotterAnalysis
    self.originalNotes = originalNotes
    self.generatedImageURL = generatedImageURL
  }

  static func user(_ text: String) -> ChatMessage {
    ChatMessage(
      role: .user, content: text, imageData: nil, isStormSpotterAnalysis: false, originalNotes: nil,
      generatedImageURL: nil)
  }

  static func assistant(_ text: String) -> ChatMessage {
    ChatMessage(
      role: .assistant, content: text, imageData: nil, isStormSpotterAnalysis: false,
      originalNotes: nil, generatedImageURL: nil)
  }

  // For photo uploads with thumbnail (notes appended to content if provided)
  static func userWithPhoto(text: String, imageData: Data?) -> ChatMessage {
    ChatMessage(
      role: .user, content: text, imageData: imageData, isStormSpotterAnalysis: false,
      originalNotes: nil, generatedImageURL: nil)
  }

  /// Caption for a Sky Check photo turn in the city thread.
  static func stormSpotterUserCaption(locationName: String?, notes: String?) -> String {
    let place = locationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    var text = SkyCheckDeskCopy.photoTurnCaption
    if !place.isEmpty {
      text += " (\(place))"
    }
    let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !trimmedNotes.isEmpty {
      text += " — Notes: \(trimmedNotes)"
    }
    return text
  }

  /// User photo + assistant write-up for a completed Sky Check analysis.
  static func stormSpotterPhotoTurn(
    locationName: String?,
    thumbnail: Data?,
    analysis: String,
    notes: String?
  ) -> (user: ChatMessage, assistant: ChatMessage) {
    let user = userWithPhoto(
      text: stormSpotterUserCaption(locationName: locationName, notes: notes),
      imageData: thumbnail
    )
    let assistant = ChatMessage(
      role: .assistant,
      content: analysis,
      isStormSpotterAnalysis: true,
      originalNotes: notes
    )
    return (user, assistant)
  }
}

