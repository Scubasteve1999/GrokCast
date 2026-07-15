import AppIntents
import Foundation

struct WidgetLocationEntity: AppEntity, Identifiable {
  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Location")
  static var defaultQuery = WidgetLocationQuery()

  let id: UUID
  let name: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(name)")
  }
}

struct WidgetLocationQuery: EntityQuery {
  func entities(for identifiers: [UUID]) async throws -> [WidgetLocationEntity] {
    let locations = WidgetDataStore.loadLocations()
    return
      locations
      .filter { identifiers.contains($0.id) }
      .map { WidgetLocationEntity(id: $0.id, name: $0.name) }
  }

  func suggestedEntities() async throws -> [WidgetLocationEntity] {
    WidgetDataStore.loadLocations().map { WidgetLocationEntity(id: $0.id, name: $0.name) }
  }
}

struct WidgetLocationSelectionIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Location"
  static var description = IntentDescription("Choose which saved location to display.")

  @Parameter(title: "Location")
  var location: WidgetLocationEntity?
}
