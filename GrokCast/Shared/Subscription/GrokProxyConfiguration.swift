import Foundation

/// Hosted Grok proxy — Pro subscribers route xAI calls through your server (key stays server-side).
enum GrokProxyConfiguration {
  /// Base URL for the proxy (must expose xAI-compatible `/v1/chat/completions`, etc.).
  /// Only set when the worker is actually deployed — see `docs/GrokCast-Pro-Setup.md`.
  /// Returning `nil` keeps Pro + BYOK/embedded-key builds on direct `api.x.ai`.
  static var baseURL: URL? {
    guard let custom = GrokCastProConfig.grokProxyBaseURL, !custom.isEmpty,
      let url = URL(string: custom)
    else {
      return nil
    }
    return url
  }

  static var isConfigured: Bool { baseURL != nil }
}
