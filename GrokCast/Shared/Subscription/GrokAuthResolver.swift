import Foundation

/// Resolves whether Grok API calls go direct (BYOK) or through the hosted Pro proxy.
struct GrokAuthContext {
  let baseURL: URL
  let authorizationHeader: String
  /// Sent to the proxy as `X-GrokCast-Subscription-Id` for rate limiting / validation.
  let subscriptionTransactionID: String?

  func applying(to request: inout URLRequest) {
    request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
    if let subscriptionTransactionID {
      request.setValue(subscriptionTransactionID, forHTTPHeaderField: "X-GrokCast-Subscription-Id")
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

  static func resolve(
    configuration: GrokAPIConfiguration = GrokAPIConfiguration(),
    subscription: SubscriptionManager
  ) throws -> GrokAuthContext {
    // Prefer a real xAI key whenever available. The Pro proxy is optional and only
    // used when explicitly configured — an undeployed default host must never win
    // over a working embedded/Keychain key (that was breaking all Grok fetches).
    if configuration.hasValidDeveloperKey {
      return GrokAuthContext(
        baseURL: configuration.baseURL,
        authorizationHeader: try configuration.authHeader(),
        subscriptionTransactionID: nil
      )
    }

    if subscription.isPro, let transactionID = subscription.proAuthToken,
      let proxyBase = GrokProxyConfiguration.baseURL
    {
      return GrokAuthContext(
        baseURL: proxyBase,
        authorizationHeader: "Bearer grokcast-pro",
        subscriptionTransactionID: transactionID
      )
    }

    throw GrokAPIError.missingAPIKey
  }
}
