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

    return AsyncThrowingStream { continuation in
      Task {
        do {
          let url = configuration.baseURL.appendingPathComponent("chat/completions")

          var request = URLRequest(url: url)
          request.httpMethod = "POST"
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          auth.applying(to: &request)

          let body = GrokBuildRequest(
            model: configuration.model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
            stream: true
          )

          request.httpBody = try JSONEncoder().encode(body)
          // POST /chat/completions (log removed)

          let (bytes, response) = try await session.bytes(for: request)

          if let httpResponse = response as? HTTPURLResponse,
            !(200...299).contains(httpResponse.statusCode)
          {
            // HTTP error (log removed)
            // Best-effort extract error body for actionable message (e.g. model not allowed, auth)
            var errorData = Data()
            for try await byte in bytes {
              errorData.append(byte)
            }
            let bodyStr = String(data: errorData, encoding: .utf8) ?? ""
            if let json = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
              let err = json["error"] as? [String: Any],
              let message = err["message"] as? String
            {
              continuation.finish(
                throwing: GrokBuildError.apiError(
                  statusCode: httpResponse.statusCode, message: message))
            } else {
              continuation.finish(
                throwing: GrokBuildError.apiError(
                  statusCode: httpResponse.statusCode,
                  message: bodyStr.isEmpty ? "No details" : bodyStr))
            }
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
            } else if let message = Self.streamErrorMessage(from: data) {
              // The stream opened 200 but emitted an error event mid-stream (e.g. rate
              // limit). Surface it instead of silently ending as an empty success.
              continuation.finish(
                throwing: GrokBuildError.apiError(statusCode: 200, message: message))
              return
            }
          }

          continuation.finish()

        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
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
      if lower.contains("spottercast pro") {
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
      if (500...599).contains(code) {
        return "AI service temporarily unavailable. Please try again later."
      }
      return "AI request couldn’t be completed. Please try again."
    }
  }
}
