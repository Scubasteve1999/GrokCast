import Foundation

enum WidgetEmptyReason: Equatable {
  case none
  case noData
  case locationMismatch(locationName: String)
  /// Home Screen / Lock Screen weather. Any Pro plan — not free.
  case requiresPro

  var iconName: String {
    switch self {
    case .locationMismatch: "mappin.slash"
    case .requiresPro: "lock.fill"
    case .noData, .none: "cloud.sun"
    }
  }

  var title: String {
    switch self {
    case .requiresPro: "Pro unlocks widgets"
    case .locationMismatch, .noData, .none: "Open DayCast"
    }
  }

  var message: String {
    switch self {
    case .requiresPro:
      "Tap to open DayCast."
    case .locationMismatch(let name):
      "Select \(name) in the app to update this widget."
    case .noData, .none:
      "Refresh weather in the app to update this widget."
    }
  }
}
