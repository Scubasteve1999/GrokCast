import Foundation
import SwiftData

/// Dedicated SwiftData store for persisting Grok AI conversation history.
/// Keeps its own ModelContainer (separate from any future weather/other data).
/// In-memory history in the ViewModel remains the source of truth at runtime.
final class GrokAIConversationStore {
  private let modelContainer: ModelContainer
  private let modelContext: ModelContext

  init() {
    do {
      let schema = Schema([ChatMessageEntity.self])

      // Force the store into the *main app's* Application Support (not the app group).
      // App group containers in simulator often don't have Library/Application Support
      // pre-created or have stricter sandbox rules for write-create, causing the
      // "Sandbox access to file-write-create denied" + "No such file or directory" errors
      // even for a named store.
      let supportDir = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first!
      try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
      let storeURL = supportDir.appendingPathComponent("GrokAIConversations.store")

      let configuration = ModelConfiguration(url: storeURL)
      modelContainer = try ModelContainer(for: schema, configurations: configuration)
      modelContext = ModelContext(modelContainer)
    } catch {
      // Failed to create persistent ModelContainer, falling back to in-memory (log removed)
      let schema = Schema([ChatMessageEntity.self])
      let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
      modelContainer = try! ModelContainer(for: schema, configurations: fallbackConfig)
      modelContext = ModelContext(modelContainer)
    }
  }

  /// Loads all persisted messages, sorted chronologically.
  func loadHistory() throws -> [ChatMessage] {
    let descriptor = FetchDescriptor<ChatMessageEntity>(
      sortBy: [SortDescriptor(\.timestamp, order: .forward)]
    )
    let entities = try modelContext.fetch(descriptor)
    return entities.map { $0.toChatMessage() }
  }

  /// Persists the provided (already trimmed) history by replacing previous entries.
  /// This keeps the persisted set in sync with the current context window.
  func saveHistory(_ messages: [ChatMessage]) throws {
    // Remove all existing for this feature (lightweight n~<20)
    try deleteAllPersisted(withoutSaving: true)

    for message in messages {
      let entity = ChatMessageEntity(from: message)
      modelContext.insert(entity)
    }
    try modelContext.save()
  }

  /// Append a single message (used optionally for incremental saves).
  func append(_ message: ChatMessage) throws {
    let entity = ChatMessageEntity(from: message)
    modelContext.insert(entity)
    try modelContext.save()
  }

  /// Clears all persisted Grok AI messages.
  func deleteAll() throws {
    try deleteAllPersisted(withoutSaving: false)
  }

  private func deleteAllPersisted(withoutSaving: Bool) throws {
    let descriptor = FetchDescriptor<ChatMessageEntity>()
    let entities = try modelContext.fetch(descriptor)
    for entity in entities {
      modelContext.delete(entity)
    }
    if !withoutSaving {
      try modelContext.save()
    }
  }
}
