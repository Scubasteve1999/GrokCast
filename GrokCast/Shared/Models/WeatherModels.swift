import Foundation

struct ChatMessage: Identifiable, Equatable {
  let id: UUID
  let role: Role
  let content: String
  let timestamp: Date
  let imageData: Data?  // optional thumbnail for photo-based user messages (e.g. Storm Spotter); full data for API call + on assistant storm messages for regeneration (UI thumbnail only for .user)
  let isStormSpotterAnalysis: Bool
  let originalNotes: String?
  let generatedImageURL: URL?  // for Grok image generation results shown in chat

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
}

enum QuickPrompt: String, CaseIterable, Identifiable {
  case grokTake = "Grok's Take"
  case outfit = "What to Wear"
  case activity = "Good for a Walk?"
  case weekend = "Weekend Outlook"
  case fun = "Fun Weather Fact"

  var id: String { rawValue }
  var icon: String {
    switch self {
    case .grokTake: "sparkles"
    case .outfit: "tshirt"
    case .activity: "figure.walk"
    case .weekend: "calendar"
    case .fun: "lightbulb"
    }
  }
  var prompt: String {
    switch self {
    case .grokTake: "Give me a short, witty Grok-style summary of today's weather and vibe."
    case .outfit:
      "Based on the current weather, temperature, wind, and UV, recommend what I should wear today. Be specific and fun."
    case .activity:
      "Is today a good day for an outdoor walk or hike? Consider temperature, precipitation chance, wind, and air quality if available. Give a yes/no with reason."
    case .weekend: "Summarize the weekend forecast in 2-3 sentences with activity suggestions."
    case .fun:
      "Tell me one interesting or surprising fact about today's weather or season in this location."
    }
  }
}
