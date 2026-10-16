import Foundation

/// Second opinion on a finished Grok reply from the Pro proxy's `/v1/verify`
/// (TypeSafe). It can only send DayCast back to its own local copy — it never
/// unblocks text `GrokContentFilter` rejected.
///
/// Additive, like NWS: developer-key users, network failures, timeouts, and any
/// non-200 all return `.unavailable`, and callers keep today's behavior silently.
/// Thresholds live in the proxy so they can change without an App Store release.
enum GrokOutputVerifier {
  enum Subject: Equatable {
    /// Today's Take, morning brief, alerts summary: checked for harmful advice.
    case brief(String)
    /// Explain Radar: also checked against the selected pin's forecast.
    case radar(String, location: String, condition: String, precipitationChance: Int)
  }

  enum Verdict: Equatable {
    case pass
    case block(reasons: [String])
    case unavailable

    var blocks: Bool {
      if case .block = self { return true }
      return false
    }
  }

  /// The proxy waits at most 4 s on TypeSafe; past this the reply ships as it does today.
  static let timeout: TimeInterval = 5
  /// Mirrors the proxy's limits so an over-long reply skips the round trip.
  static let maxTextLength = 4_000
  static let maxFieldLength = 120

  @MainActor
  static func verify(
    _ subject: Subject,
    subscription: SubscriptionManager = .shared,
    session: URLSession = .shared
  ) async -> Verdict {
    // Pro only: the proxy is the only place the TypeSafe key lives. A personal xAI
    // key does not unlock it, and this must never consume the Grok chat allowance.
    let tier = GrokAccessRules.tier(
      isPro: subscription.isPro,
      proxyConfigured: GrokProxyConfiguration.isConfigured,
      hasDeveloperKey: GrokAPIConfiguration().hasValidDeveloperKey
    )
    guard tier == .pro, let baseURL = GrokProxyConfiguration.baseURL,
      let transactionJWS = subscription.proTransactionJWS
    else { return .unavailable }

    let auth = GrokAuthContext(
      baseURL: baseURL,
      authorizationHeader: "Bearer \(GrokProxyConfiguration.sharedSecret)",
      tier: .pro,
      transactionJWS: transactionJWS
    )
    guard let request = request(for: subject, auth: auth) else { return .unavailable }
    do {
      let (data, response) = try await session.data(for: request)
      return verdict(statusCode: (response as? HTTPURLResponse)?.statusCode, data: data)
    } catch {
      return .unavailable
    }
  }

  /// `nil` when the subject is outside what the proxy accepts.
  static func request(for subject: Subject, auth: GrokAuthContext) -> URLRequest? {
    var body: [String: Any]
    switch subject {
    case .brief(let text):
      body = ["kind": "brief", "text": text]
    case .radar(let text, let location, let condition, let chance):
      guard (0...100).contains(chance),
        !location.isEmpty, location.count <= maxFieldLength,
        !condition.isEmpty, condition.count <= maxFieldLength
      else { return nil }
      body = [
        "kind": "radar",
        "text": text,
        "pin": ["location": location, "condition": condition, "precipitation_chance": chance],
      ]
    }
    guard let text = body["text"] as? String,
      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      text.count <= maxTextLength,
      let data = try? JSONSerialization.data(withJSONObject: body)
    else { return nil }

    var request = URLRequest(url: auth.baseURL.appendingPathComponent("verify"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = timeout
    request.httpBody = data
    auth.applying(to: &request)
    return request
  }

  static func verdict(statusCode: Int?, data: Data) -> Verdict {
    guard statusCode == 200,
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let verdict = json["verdict"] as? String
    else { return .unavailable }
    switch verdict {
    case "pass": return .pass
    case "block": return .block(reasons: json["reasons"] as? [String] ?? [])
    default: return .unavailable
    }
  }
}
