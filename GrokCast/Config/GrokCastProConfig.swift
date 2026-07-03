import Foundation

/// Production configuration for GrokCast Pro hosted services.
/// Set `grokProxyBaseURL` when your Grok proxy is deployed (see `server/grok-proxy/README.md`).
enum GrokCastProConfig {
  /// e.g. `"https://grok-proxy.grokcast.app/v1"`
  static let grokProxyBaseURL: String? = nil
}
