import SwiftUI
import UIKit

struct ActivityViewRepresentable: UIViewControllerRepresentable {
  let items: [Any]
  var activities: [UIActivity]? = nil

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: activities)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
