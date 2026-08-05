import SwiftUI

/// Presents `PaywallView` from anywhere in the app.
@MainActor
@Observable
final class PaywallCoordinator {
  static let shared = PaywallCoordinator()

  var isPresented = false
  var feature: PaywallFeature = .grokAI

  private init() {}

  func present(_ feature: PaywallFeature = .grokAI) {
    self.feature = feature
    isPresented = true
  }

  /// Opens the paywall for Grok only when Pro can actually unlock it (live proxy).
  /// Otherwise callers should send the user to Settings for a developer key.
  var canUnlockGrokViaPro: Bool {
    GrokProxyConfiguration.isConfigured
  }
}

struct PaywallPresentationModifier: ViewModifier {
  @Bindable var coordinator: PaywallCoordinator

  func body(content: Content) -> some View {
    content
      .sheet(isPresented: $coordinator.isPresented) {
        PaywallView(
          feature: coordinator.feature,
          subscription: SubscriptionManager.shared
        )
      }
  }
}

extension View {
  @MainActor
  func paywallSheet() -> some View {
    modifier(PaywallPresentationModifier(coordinator: .shared))
  }

  @MainActor
  func paywallSheet(coordinator: PaywallCoordinator) -> some View {
    modifier(PaywallPresentationModifier(coordinator: coordinator))
  }
}
