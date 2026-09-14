import SafariServices
import SwiftUI

/// In-app Safari for official weather.gov PDFs and similar citations.
struct SafariView: UIViewControllerRepresentable {
  let url: URL

  func makeUIViewController(context: Context) -> SFSafariViewController {
    let controller = SFSafariViewController(url: url)
    controller.dismissButtonStyle = .done
    return controller
  }

  func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct IdentifiableURL: Identifiable {
  let url: URL
  var id: String { url.absoluteString }

  init(_ url: URL) {
    self.url = url
  }
}
