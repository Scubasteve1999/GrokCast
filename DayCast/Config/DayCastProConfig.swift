import Foundation

/// Production configuration for DayCast Pro hosted services.
///
/// Secrets-free by design, like `GrokAPIConfiguration`. The live Grok proxy URL
/// is committed here so Release / TestFlight are not hostage to gitignored
/// `DeveloperAPIKey.swift`. That file remains an optional local override
/// (simulator / staging). Shared secret still falls back to `"daycast-pro"`
/// in `GrokProxyConfiguration` when the override is nil.
///
/// Setup: `server/grok-proxy/README.md`, `DEPLOYMENT.md`.
enum DayCastProConfig {
  /// Live production worker, including the `/v1` suffix callers append to
  /// (`chat/completions`, `images/generations`, `status`, `health`).
  static let productionGrokProxyBaseURL =
    "https://daycast-grok-proxy.stephendev.workers.dev/v1"

  /// The deployed worker, including the `/v1` suffix.
  /// `DeveloperAPIKey.grokProxyBaseURL` overrides when set; otherwise production.
  static let grokProxyBaseURL: String? = {
    if let custom = DeveloperAPIKey.grokProxyBaseURL, !custom.isEmpty {
      return custom
    }
    return productionGrokProxyBaseURL
  }()

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
