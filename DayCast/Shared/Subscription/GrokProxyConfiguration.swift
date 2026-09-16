import Foundation

/// Hosted Grok proxy — Pro subscribers route xAI calls through the worker in
/// `server/grok-proxy`, so the xAI key never ships in the app.
enum GrokProxyConfiguration {
  /// Base URL for the proxy, including the `/v1` suffix — callers append
  /// `chat/completions` to it. Uses the committed production worker when
  /// `DeveloperAPIKey.grokProxyBaseURL` is nil so Pro AI claims stay true.
  static var baseURL: URL? {
    if let custom = DayCastProConfig.grokProxyBaseURL, !custom.isEmpty,
      let url = URL(string: custom)
    {
      return url
    }
    return URL(string: DayCastProConfig.productionGrokProxyBaseURL)
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
