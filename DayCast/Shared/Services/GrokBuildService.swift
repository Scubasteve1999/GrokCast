import Foundation

// MARK: - Configuration
struct GrokBuildConfiguration {
  let baseURL: URL
  let model: String

  /// The only way to build one. There used to be a `make()` that read the
  /// embedded key and hardcoded `api.x.ai`, which let Trip Planner bypass the
  /// resolver entirely — every caller now has to come through `GrokAuthResolver`.
  @MainActor
  init(auth: GrokAuthContext) {
    self.baseURL = auth.baseURL
    // grok-3-mini keeps quick prompts and free text compatible with standard
    // xAI developer keys.
    self.model = "grok-3-mini"
  }
}

// MARK: - GrokBuildService
final class GrokBuildService {
  private let configuration: GrokBuildConfiguration
  private let session: URLSession

  init(
    configuration: GrokBuildConfiguration,
    session: URLSession? = nil
  ) {
    self.configuration = configuration
    // Use a dedicated session for streaming (SSE / long-lived connections to api.x.ai).
    // .shared is fine for one-shot requests but dedicated config + connection limits
    // can reduce certain internal Network.framework noise (e.g. local endpoint queries
    // during HTTP/2 or QUIC negotiation) and keeps the shared pool clean for weather fetches.
    self.session = session ?? Self.makeStreamingSession()
  }

  private static func makeStreamingSession() -> URLSession {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 120  // generous for thinking + first token
    config.timeoutIntervalForResource = 300  // full response window
    config.waitsForConnectivity = true
    config.httpMaximumConnectionsPerHost = 2  // streaming doesn't benefit from high concurrency
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    return URLSession(configuration: config)
  }

  // MARK: - Streaming

  func streamChat(
    messages: [GrokBuildMessage],
    auth: GrokAuthContext,
    temperature: Double = 0.7,
    maxTokens: Int? = nil
  ) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
      Task {
        do {
          var request = Self.chatRequest(baseURL: configuration.baseURL, auth: auth)
          request.httpBody = try JSONEncoder().encode(
            GrokBuildRequest(
              model: configuration.model,
              messages: messages,
              temperature: temperature,
              maxTokens: maxTokens,
              stream: true
            ))
          try await Self.pumpSSE(session: session, request: request, into: continuation)
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }

  func streamVision(
    system: String,
    userText: String,
    imageJPEG: Data,
    auth: GrokAuthContext,
    model: String = "grok-4.3",
    maxTokens: Int = 1024
  ) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
      Task {
        do {
          var request = Self.chatRequest(baseURL: configuration.baseURL, auth: auth)
          request.timeoutInterval = 120
          let base64 = imageJPEG.base64EncodedString()
          let body: [String: Any] = [
            "model": model,
            "stream": true,
            "max_tokens": maxTokens,
            "messages": [
              ["role": "system", "content": system],
              [
                "role": "user",
                "content": [
                  ["type": "text", "text": userText],
                  ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]],
                ],
              ],
            ],
          ]
          request.httpBody = try JSONSerialization.data(withJSONObject: body)
          try await Self.pumpSSE(session: session, request: request, into: continuation)
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }

  func generateImage(prompt: String, auth: GrokAuthContext, model: String) async throws -> URL {
    var request = URLRequest(url: configuration.baseURL.appendingPathComponent("images/generations"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    auth.applying(to: &request)
    request.timeoutInterval = 60
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "model": model,
      "prompt": prompt,
      "n": 1,
      "response_format": "url",
    ])

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw GrokBuildError.invalidResponse(statusCode: nil)
    }
    guard http.statusCode == 200 else {
      throw GrokBuildError.apiError(statusCode: http.statusCode, message: Self.apiErrorMessage(in: data))
    }
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let dataArray = json["data"] as? [[String: Any]],
      let urlString = dataArray.first?["url"] as? String,
      let url = URL(string: urlString)
    else {
      throw GrokBuildError.invalidResponse(statusCode: http.statusCode)
    }
    return url
  }

  /// Resolve + stream in one hop so callers cannot skip the entitlement meter.
  @MainActor
  static func stream(
    messages: [GrokBuildMessage],
    feature: GrokFeature,
    bucket: GrokUsageBucket = .chat,
    maxTokens: Int? = nil
  ) throws -> AsyncThrowingStream<String, Error> {
    let auth = try GrokAuthResolver.resolve(
      for: bucket, feature: feature, subscription: SubscriptionManager.shared)
    let service = GrokBuildService(configuration: GrokBuildConfiguration(auth: auth))
    return service.streamChat(messages: messages, auth: auth, maxTokens: maxTokens)
  }

  @MainActor
  static func streamStormPhoto(
    imageData: Data,
    weather: DayCastWeather?,
    alerts: [NWSAlert]?,
    severeContext: SevereWeatherContext?,
    shortTermContext: ShortTermPrecipContext?,
    observation: NWSObservation?,
    userNotes: String?
  ) throws -> AsyncThrowingStream<String, Error> {
    let jpeg = imageData.compressedForVision() ?? imageData
    var system = GrokPrompts.stormSpotterSystemPrompt
    if let weather {
      system +=
        "\n\n"
        + GrokPrompts.buildTechnicalStormContext(
          for: weather,
          alerts: alerts ?? [],
          severeContext: severeContext,
          shortTermContext: shortTermContext,
          nearestStationObservation: observation,
          userNotes: userNotes)
    }
    let auth = try GrokAuthResolver.resolve(
      for: .chat, feature: .stormPhoto, subscription: SubscriptionManager.shared)
    let service = GrokBuildService(configuration: GrokBuildConfiguration(auth: auth))
    return service.streamVision(
      system: system,
      userText: "Analyze the attached sky or storm photograph using the provided context.",
      imageJPEG: jpeg,
      auth: auth
    )
  }

  @MainActor
  static func generateImage(prompt: String) async throws -> URL {
    let auth = try GrokAuthResolver.resolve(
      for: .image, feature: .imagine, subscription: SubscriptionManager.shared)
    let service = GrokBuildService(configuration: GrokBuildConfiguration(auth: auth))
    return try await service.generateImage(
      prompt: prompt, auth: auth, model: GrokAPIConfiguration.imageModelName)
  }

  @MainActor
  static func complete(
    messages: [GrokBuildMessage],
    feature: GrokFeature,
    maxTokens: Int
  ) async throws -> String {
    var result = ""
    for try await token in try stream(messages: messages, feature: feature, maxTokens: maxTokens) {
      result += token
    }
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func chatRequest(baseURL: URL, auth: GrokAuthContext) -> URLRequest {
    var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    auth.applying(to: &request)
    return request
  }

  private static func pumpSSE(
    session: URLSession,
    request: URLRequest,
    into continuation: AsyncThrowingStream<String, Error>.Continuation
  ) async throws {
    let (bytes, response) = try await session.bytes(for: request)

    if let httpResponse = response as? HTTPURLResponse,
      !(200...299).contains(httpResponse.statusCode)
    {
      var errorData = Data()
      for try await byte in bytes {
        errorData.append(byte)
      }
      continuation.finish(
        throwing: GrokBuildError.apiError(
          statusCode: httpResponse.statusCode,
          message: apiErrorMessage(in: errorData)))
      return
    }

    guard response is HTTPURLResponse else {
      continuation.finish(throwing: GrokBuildError.invalidResponse(statusCode: nil))
      return
    }

    for try await line in bytes.lines {
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      guard trimmed.hasPrefix("data: ") else { continue }
      let jsonString = String(trimmed.dropFirst(6)).trimmingCharacters(
        in: .whitespacesAndNewlines)
      if jsonString == "[DONE]" {
        continuation.finish()
        return
      }
      guard let data = jsonString.data(using: .utf8) else { continue }
      if let chunk = try? JSONDecoder().decode(GrokBuildStreamChunk.self, from: data) {
        if let content = chunk.choices.first?.delta.content, !content.isEmpty {
          continuation.yield(content)
        }
      } else if let message = streamErrorMessage(from: data) {
        continuation.finish(throwing: GrokBuildError.apiError(statusCode: 200, message: message))
        return
      }
    }
    continuation.finish()
  }

  private static func apiErrorMessage(in data: Data) -> String {
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let err = json["error"] as? [String: Any],
      let message = err["message"] as? String
    {
      return message
    }
    let body = String(data: data, encoding: .utf8) ?? ""
    return body.isEmpty ? "No details" : body
  }

  /// Extracts an `{"error": {"message": ...}}` envelope from an SSE data chunk that
  /// failed to decode as a delta, so mid-stream errors aren't swallowed.
  private static func streamErrorMessage(from data: Data) -> String? {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
      return message
    }
    if let message = json["error"] as? String {
      return message
    }
    return nil
  }
}

// MARK: - Supporting Models
struct GrokBuildMessage: Codable {
  let role: String
  let content: String
}

struct GrokBuildRequest: Codable {
  let model: String
  let messages: [GrokBuildMessage]
  let temperature: Double?
  let maxTokens: Int?
  let stream: Bool?

  enum CodingKeys: String, CodingKey {
    case model, messages, temperature, stream
    case maxTokens = "max_tokens"
  }
}

struct GrokBuildStreamChunk: Codable {
  let choices: [StreamChoice]

  struct StreamChoice: Codable {
    let delta: Delta

    struct Delta: Codable {
      let content: String?
    }
  }
}

enum GrokBuildError: Error, LocalizedError {
  case missingAPIKey
  case invalidResponse(statusCode: Int?)
  case apiError(statusCode: Int, message: String)

  var errorDescription: String? {
    switch self {
    case .missingAPIKey:
      return "DayCast Pro unlocks AI features."
    case .invalidResponse(let code):
      if let c = code {
        return "Invalid response from AI service (HTTP \(c)). Check your API key and try again."
      }
      return "Invalid response from AI service"
    case .apiError(let code, let msg):
      let lower = msg.lowercased()
      // Responses from our own proxy, which speaks the same error shape as xAI.
      if lower.contains("daycast pro") {
        return "DayCast Pro unlocks AI features."
      }
      if lower.contains("limit reached") || code == 429 {
        return "AI limit reached for today. Resets at midnight UTC."
      }
      if lower.contains("temporarily unavailable") {
        return "AI is temporarily unavailable. Please try again later."
      }
      if lower.contains("incorrect api key") || lower.contains("invalid api key")
        || code == 401 || code == 403
      {
        return "AI key isn’t valid. Add a working xAI key in Settings (starts with xai-)."
      }
      if code == 404 {
        return "AI service is offline. Try again later."
      }
      if (500...599).contains(code) {
        return "AI service temporarily unavailable. Please try again later."
      }
      return "AI request couldn’t be completed. Please try again."
    }
  }
}
