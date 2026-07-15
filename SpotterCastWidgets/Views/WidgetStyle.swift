import SwiftUI

struct WidgetStyle {
  let colorScheme: ColorScheme

  var primaryText: Color {
    colorScheme == .dark ? .white : Color(red: 0.1, green: 0.12, blue: 0.18)
  }

  var secondaryText: Color {
    colorScheme == .dark ? .white.opacity(0.7) : Color(red: 0.35, green: 0.4, blue: 0.48)
  }

  var cardBackground: Color {
    colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
  }

  static let staleContentOpacity: Double = 0.55

  var staleContentOpacity: Double { Self.staleContentOpacity }
}
