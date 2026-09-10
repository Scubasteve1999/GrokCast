import Foundation

/// Shared city-pick path for Locations and Today's chip-bar search.
/// Decision is always `CitySearch.selectionDecision` + `EntitlementChecker.canAddLocation`.
enum LocationSearchFlow {
  static func candidate(from result: CitySearchResult) -> SavedLocation {
    SavedLocation(
      name: result.name,
      latitude: result.latitude,
      longitude: result.longitude
    )
  }

  /// Same gate Locations already used. Today must not invent another.
  static func decision(
    for result: CitySearchResult,
    saved: [SavedLocation],
    isPro: Bool
  ) -> (candidate: SavedLocation, selection: LocationSearchSelection) {
    let candidate = candidate(from: result)
    let canAdd = EntitlementChecker.canAddLocation(locations: saved, isPro: isPro)
    return (
      candidate,
      CitySearch.selectionDecision(candidate: candidate, saved: saved, canAdd: canAdd)
    )
  }

  /// Persist through `WeatherStore` (no Today-only save path). Calls
  /// `presentPaywall` on `.paywall` or when `addLocation` refuses.
  @MainActor
  @discardableResult
  static func apply(
    result: CitySearchResult,
    store: WeatherStore,
    isPro: Bool,
    presentPaywall: () -> Void
  ) -> LocationSearchSelection {
    let (candidate, selection) = decision(
      for: result,
      saved: store.savedLocations,
      isPro: isPro
    )
    switch selection {
    case .selectExisting(let existing):
      store.selectLocation(existing)
    case .add:
      guard store.addLocation(candidate) else {
        presentPaywall()
        return .paywall
      }
      store.selectLocation(candidate)
    case .replace(let current):
      store.removeLocation(current)
      guard store.addLocation(candidate) else {
        presentPaywall()
        return .paywall
      }
      store.selectLocation(candidate)
    case .paywall:
      presentPaywall()
    }
    return selection
  }
}
