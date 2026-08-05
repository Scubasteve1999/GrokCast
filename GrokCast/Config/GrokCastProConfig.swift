import Foundation

/// Production configuration for DayCast Pro hosted services.
///
/// Secrets-free by design, like `GrokAPIConfiguration`: both values live in the
/// gitignored `DeveloperAPIKey.swift` and are forwarded here so the rest of the
/// app has one place to read them from.
///
/// While `grokProxyBaseURL` is nil, Pro cannot unlock AI and only users with
/// their own Keychain xAI key can reach Grok. Setup: `server/grok-proxy/README.md`.
enum GrokCastProConfig {
  /// The deployed worker, including the `/v1` suffix.
  static let grokProxyBaseURL: String? = DeveloperAPIKey.grokProxyBaseURL

  /// Must match the worker's `PROXY_SECRET`.
  static let grokProxySharedSecret: String? = DeveloperAPIKey.grokProxySharedSecret

  /// The deployed push agent, including the `/v1/push` suffix.
  ///
  /// While nil, `PushRegistrationService` stays inert and notifications remain
  /// local-only. Setup: `server/push-agent/README.md`.
  static let pushAgentBaseURL: String? = DeveloperAPIKey.pushAgentBaseURL

  /// Must match the push agent's `PUSH_SECRET`.
  static let pushAgentSharedSecret: String? = DeveloperAPIKey.pushAgentSharedSecret
}
