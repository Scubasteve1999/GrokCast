import SwiftUI

struct WidgetEmptyStateView: View {
  let reason: WidgetEmptyReason
  let style: WidgetStyle

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: iconName)
        .font(.title2)
        .foregroundStyle(style.secondaryText)
      Text(title)
        .font(.headline.weight(.semibold))
        .foregroundStyle(style.primaryText)
      Text(message)
        .font(.caption2)
        .foregroundStyle(style.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(14)
  }

  private var iconName: String {
    switch reason {
    case .locationMismatch: "mappin.slash"
    case .noData: "cloud.sun"
    case .none: "cloud.sun"
    }
  }

  private var title: String {
    switch reason {
    case .locationMismatch: "Open SpotterCast"
    case .noData: "Open SpotterCast"
    case .none: "Open SpotterCast"
    }
  }

  private var message: String {
    switch reason {
    case .locationMismatch(let name):
      "Select \(name) in the app to update this widget."
    case .noData:
      "Refresh weather in the app to update this widget."
    case .none:
      "Refresh weather in the app to update this widget."
    }
  }
}
