import SwiftUI

struct WidgetTacticalBackground: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Group {
      if colorScheme == .dark {
        ZStack {
          Color.black
          LinearGradient(
            colors: [Color(red: 0.05, green: 0.05, blue: 0.12), .black],
            startPoint: .top,
            endPoint: .bottom
          )
        }
      } else {
        ZStack {
          Color(red: 0.95, green: 0.96, blue: 0.98)
          LinearGradient(
            colors: [Color.white, Color(red: 0.92, green: 0.94, blue: 0.97)],
            startPoint: .top,
            endPoint: .bottom
          )
        }
      }
    }
  }
}

extension View {
  func widgetTacticalContainer() -> some View {
    containerBackground(for: .widget) {
      WidgetTacticalBackground()
    }
  }
}
