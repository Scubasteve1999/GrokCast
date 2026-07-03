import Foundation

/// Hosted Grok proxy — Pro subscribers route xAI calls through your server (key stays server-side).
enum GrokProxyConfiguration {
  /// Base URL for the proxy (must expose xAI-compatible `/v1/chat/completions`, etc.).
  /// Set in `DeveloperAPIKey.grokProxyBaseURL` or defaults below for production.
  static var baseURL: URL? {
    if let custom = GrokCastProConfig.grokProxyBaseURL, !custom.isEmpty,
      let url = URL(string: custom)
    {
      return url
    }
    return URL(string: "https://grok-proxy.grokcast.app/v1")
  }

  static var isConfigured: Bool { baseURL != nil }
}
