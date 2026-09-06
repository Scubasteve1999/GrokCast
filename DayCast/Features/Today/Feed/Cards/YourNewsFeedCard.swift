import SwiftUI

/// Today host for the shared Your News rail. Empty items + pending → placeholder.
struct YourNewsFeedCard: View {
  let items: [LocalBriefingItem]
  var sitsInSheet: Bool = false
  var isPending: Bool = false

  var body: some View {
    LocalBriefingSection(
      items: items,
      accessibilityID: DayCastAccessibility.Today.yourNews,
      sitsInSheet: sitsInSheet,
      isPending: isPending
    )
  }
}
