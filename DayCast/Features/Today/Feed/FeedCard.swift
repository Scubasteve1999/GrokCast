import SwiftUI

/// Metadata contract for home feed cards. Concrete views live under `Feed/Cards/`.
protocol FeedCard {
  static var item: FeedItem { get }
  static func shouldShow(in snapshot: FeedSnapshot) -> Bool
  static func accessibilitySummary(snapshot: FeedSnapshot, weather: DayCastWeather?) -> String
}

extension FeedCard {
  static func shouldShow(in snapshot: FeedSnapshot) -> Bool {
    FeedAssembler.shouldShow(item, in: snapshot)
  }
}

/// Shared chrome for feed cards (solid data surface).
struct FeedCardChrome<Content: View>: View {
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    content
      .padding(DesignTokens.Spacing.space16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .cardStyle()
  }
}
