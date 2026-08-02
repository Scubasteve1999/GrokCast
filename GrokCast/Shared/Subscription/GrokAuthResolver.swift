import Foundation

/// Resolves whether Grok API calls go through the hosted Pro proxy or direct on a
/// user-supplied key, and meters the calls we pay for.
struct GrokAuthContext {
  let baseURL: URL
  let authorizationHeader: String
  let tier: GrokAccessTier
  /// StoreKit 2 signed transaction. The proxy verifies this against Apple's root —
  /// it is the actual credential, not the shared bearer token.
  let transactionJWS: String?

  static let transactionHeader = "X-SpotterCast-Transaction"

  func applying(to request: inout URLRequest) {
    request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
    if let transactionJWS {
      request.setValue(transactionJWS, forHTTPHeaderField: Self.transactionHeader)
    }
  }
}

@MainActor
enum GrokAuthResolver {
  static func canAccessGrok(
    configuration: GrokAPIConfiguration = GrokAPIConfiguration(),
    subscription: SubscriptionManager
  ) -> Bool {
    EntitlementChecker.canUseGrokAI(
      subscription: subscription,
      hasDeveloperKey: configuration.hasValidDeveloperKey
    )
  }

  /// Resolves credentials for one call and consumes its daily allowance.
  ///
  /// Metering happens here because this is the single point every AI path passes
  /// through, so a new caller cannot accidentally skip the cap. Only calls billed
  /// to us are metered — a user on their own key is not.
  static func resolve(
    for bucket: GrokUsageBucket = .chat,
    feature: GrokFeature = .chat,
    configuration: GrokAPIConfiguration = GrokAPIConfiguration(),
    subscription: SubscriptionManager,
    limiter: GrokUsageLimiter = .shared
  ) throws -> GrokAuthContext {
    let tier = GrokAccessRules.tier(
      isPro: subscription.isPro,
      proxyConfigured: GrokProxyConfiguration.isConfigured,
      hasDeveloperKey: configuration.hasValidDeveloperKey
    )

    switch tier {
    case .pro:
      guard let proxyBase = GrokProxyConfiguration.baseURL else { throw GrokAPIError.proRequired }
      guard let transactionJWS = subscription.proTransactionJWS else {
        // Entitled, but the signed transaction hasn't loaded yet. Refusing beats
        // sending a request the proxy is certain to reject.
        throw GrokAPIError.entitlementUnavailable
      }
      guard limiter.consume(bucket) else {
        Analytics.track(
          .aiLimitReached,
          parameters: ["bucket": bucket.rawValue, "feature": feature.rawValue])
        throw GrokAPIError.dailyLimitReached(resetsAt: limiter.resetDate())
      }
      Analytics.track(
        .aiRequest,
        parameters: ["bucket": bucket.rawValue, "feature": feature.rawValue, "tier": "pro"])
      return GrokAuthContext(
        baseURL: proxyBase,
        authorizationHeader: "Bearer \(GrokProxyConfiguration.sharedSecret)",
        tier: .pro,
        transactionJWS: transactionJWS
      )

    case .developerKey:
      // Tracked too, so per-feature AI demand reflects everyone using it — but
      // tagged separately, since these calls cost us nothing.
      Analytics.track(
        .aiRequest,
        parameters: [
          "bucket": bucket.rawValue, "feature": feature.rawValue, "tier": "developer_key",
        ])
      return GrokAuthContext(
        baseURL: configuration.baseURL,
        authorizationHeader: try configuration.authHeader(),
        tier: .developerKey,
        transactionJWS: nil
      )

    case .free, .none:
      throw GrokAPIError.proRequired
    }
  }

  /// Returns an allowance after a request that never reached the model, so a
  /// network failure doesn't cost part of the user's day.
  static func refund(
    _ bucket: GrokUsageBucket,
    tier: GrokAccessTier,
    limiter: GrokUsageLimiter = .shared
  ) {
    guard tier == .pro else { return }
    limiter.refund(bucket)
  }
}
