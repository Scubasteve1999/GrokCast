import Foundation
import SwiftData

/// Whether Briefing Studio must swap the visible thread.
/// Same selected-city identity keeps the thread; a new identity does not inherit it.
enum BriefingThreadScope {
  static func shouldReplace(boundLocationID: UUID?, selectedLocationID: UUID?) -> Bool {
    boundLocationID != selectedLocationID
  }
}

/// Dedicated SwiftData store for persisting Grok AI conversation history.
/// Threads are keyed by selected `SavedLocation.id`. In-memory history in the
/// ViewModel remains the source of truth at runtime for the bound city.
final class GrokAIConversationStore {
  private let modelContainer: ModelContainer
  private let modelContext: ModelContext

  convenience init() {
    self.init(inMemory: false)
  }

  init(inMemory: Bool) {
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

      let configuration = inMemory
        ? ModelConfiguration(isStoredInMemoryOnly: true)
        : ModelConfiguration(url: storeURL)
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

  /// Loads messages for one selected city. Legacy rows with no location are dropped.
  func loadHistory(for locationID: UUID?) throws -> [ChatMessage] {
    try discardUnscopedMessages()
    guard let locationID else { return [] }
    let descriptor = FetchDescriptor<ChatMessageEntity>(
      predicate: #Predicate { $0.locationID == locationID },
      sortBy: [SortDescriptor(\.timestamp, order: .forward)]
    )
    let entities = try modelContext.fetch(descriptor)
    return entities.map { $0.toChatMessage() }
  }

  /// Replaces the persisted thread for one city. Other cities are left intact.
  func saveHistory(_ messages: [ChatMessage], for locationID: UUID) throws {
    try discardUnscopedMessages()
    try deleteAllPersisted(for: locationID, withoutSaving: true)

    for message in messages {
      modelContext.insert(ChatMessageEntity(from: message, locationID: locationID))
    }
    try modelContext.save()
  }

  /// Append a single message (used optionally for incremental saves).
  func append(_ message: ChatMessage, locationID: UUID) throws {
    let entity = ChatMessageEntity(from: message, locationID: locationID)
    modelContext.insert(entity)
    try modelContext.save()
  }

  /// Clears the persisted thread for one city.
  func deleteAll(for locationID: UUID) throws {
    try deleteAllPersisted(for: locationID, withoutSaving: false)
  }

  private func discardUnscopedMessages() throws {
    let descriptor = FetchDescriptor<ChatMessageEntity>()
    let entities = try modelContext.fetch(descriptor)
    let unscoped = entities.filter { $0.locationID == nil }
    guard !unscoped.isEmpty else { return }
    for entity in unscoped {
      modelContext.delete(entity)
    }
    try modelContext.save()
  }

  private func deleteAllPersisted(for locationID: UUID, withoutSaving: Bool) throws {
    let descriptor = FetchDescriptor<ChatMessageEntity>(
      predicate: #Predicate { $0.locationID == locationID }
    )
    let entities = try modelContext.fetch(descriptor)
    for entity in entities {
      modelContext.delete(entity)
    }
    if !withoutSaving {
      try modelContext.save()
    }
  }
}
