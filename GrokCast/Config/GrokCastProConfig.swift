import Foundation

/// Production configuration for SpotterCast Pro hosted services.
/// Set `grokProxyBaseURL` only after the proxy worker is deployed (see `docs/GrokCast-Pro-Setup.md`).
/// While `nil`, Grok calls use a developer/Keychain xAI key against `api.x.ai` directly.
enum GrokCastProConfig {
  /// e.g. `"https://YOUR-WORKER.workers.dev/v1"` — must be a live host, not a placeholder.
  static let grokProxyBaseURL: String? = nil
}
