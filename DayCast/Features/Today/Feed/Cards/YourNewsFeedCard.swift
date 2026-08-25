import SwiftUI

/// Today host for the shared Your News rail. Hide when `items` is empty.
struct YourNewsFeedCard: View {
  let items: [LocalBriefingItem]
  var sitsInSheet: Bool = false

  var body: some View {
    LocalBriefingSection(
      items: items,
      accessibilityID: DayCastAccessibility.Today.yourNews,
      sitsInSheet: sitsInSheet
    )
  }
}
