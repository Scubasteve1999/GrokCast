import SwiftUI
import UIKit

struct ActivityViewRepresentable: UIViewControllerRepresentable {
  let items: [Any]
  var activities: [UIActivity]? = nil
  /// Reported with `share_completed` so completions can be attributed to the
  /// surface that produced them. Nil skips tracking.
  var surface: ShareAttribution.Surface? = nil

  func makeUIViewController(context: Context) -> UIActivityViewController {
    let controller = UIActivityViewController(
      activityItems: items, applicationActivities: activities)

    if let surface {
      controller.completionWithItemsHandler = { activityType, completed, _, _ in
        // Only completed shares count. A dismissed sheet is not a share, and
        // counting it as one is how a share loop looks healthier than it is.
        guard completed else { return }
        Analytics.track(
          .shareCompleted,
          parameters: [
            "surface": surface.rawValue,
            "destination": activityType?.rawValue ?? "unknown",
          ]
        )
      }
    }

    return controller
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
