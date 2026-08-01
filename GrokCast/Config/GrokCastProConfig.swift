import Foundation

/// Production configuration for SpotterCast Pro hosted services.
///
/// Both values are set once, at deploy time — see `server/grok-proxy/README.md`.
/// While `grokProxyBaseURL` is `nil`, Pro cannot unlock AI and only users with
/// their own Keychain xAI key can reach Grok.
enum GrokCastProConfig {
  /// The deployed worker, **including the `/v1` suffix**:
  /// `"https://spottercast-grok-proxy.<subdomain>.workers.dev/v1"`.
  /// Must be a live host, never a placeholder.
  static let grokProxyBaseURL: String? = nil

  /// Must match the worker's `PROXY_SECRET`. Not a secret in any meaningful
  /// sense — it ships in the binary — so it is fine to keep in tracked source.
  /// Real entitlement is the StoreKit transaction the proxy verifies.
  static let grokProxySharedSecret: String? = nil
}
