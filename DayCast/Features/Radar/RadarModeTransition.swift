import Foundation

/// Snapshot captured when the user requests a NOW ↔ FUTURE change.
/// Orchestration (delays, availability checks) runs in SwiftUI `.task`; this struct is data only.
struct RadarModeTransition: Equatable {
  let id: UUID
  let targetIsFuture: Bool
  let savedIndex: Int
  let savedWasFuture: Bool
  let savedForecastAvailability: RadarTileAvailability
}