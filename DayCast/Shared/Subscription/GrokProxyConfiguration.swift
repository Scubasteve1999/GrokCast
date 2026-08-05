import Foundation

/// Hosted Grok proxy — Pro subscribers route xAI calls through the worker in
/// `server/grok-proxy`, so the xAI key never ships in the app.
enum GrokProxyConfiguration {
  /// Base URL for the proxy, including the `/v1` suffix — callers append
  /// `chat/completions` to it. `nil` until the worker is deployed, which leaves
  /// Grok available only to users with their own Keychain key.
  static var baseURL: URL? {
    guard let custom = DayCastProConfig.grokProxyBaseURL, !custom.isEmpty,
      let url = URL(string: custom)
    else {
      return nil
    }
    return url
  }

  static var isConfigured: Bool { baseURL != nil }

  /// Coarse bearer token the proxy checks before doing real work.
  ///
  /// This ships inside the binary, so treat it as public: it deters idle scanning
  /// and nothing more. Entitlement comes from the StoreKit transaction the proxy
  /// verifies against Apple's root, which only Apple can mint.
  static var sharedSecret: String {
    DayCastProConfig.grokProxySharedSecret ?? "daycast-pro"
  }
}
