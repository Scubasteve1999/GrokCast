import Foundation

// MARK: - Configuration
struct GrokBuildConfiguration {
  let apiKey: String
  let baseURL: URL
  let model: String

  static func make() -> GrokBuildConfiguration {
    // Prefer dedicated grokBuild key; fall back to the main xAI key so existing users
    // who saved their key via Settings immediately get a working Grok AI tab without
    // extra configuration. A separate key can still be saved under the .grokBuild slot
    // if desired (e.g. for different rate limits or accounts).
    let apiKey =
      KeychainService.shared.getAPIKey(for: .grokBuild)
      ?? KeychainService.shared.getAPIKey(for: .xai)
      ?? DeveloperAPIKey.grokBuild
      ?? DeveloperAPIKey.xai
      ?? ""

    return GrokBuildConfiguration(
      apiKey: apiKey,
      baseURL: URL(string: "https://api.x.ai/v1")!,
      model: "grok-build-0.1"
    )
  }
}

// MARK: - GrokBuildService
final class GrokBuildService {
  private let configuration: GrokBuildConfiguration
  private let session: URLSession

  init(
    configuration: GrokBuildConfiguration = .make(),
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
    temperature: Double = 0.7,
    maxTokens: Int? = nil
  ) -> AsyncThrowingStream<String, Error> {

    return AsyncThrowingStream { continuation in
      Task {
        do {
          if configuration.apiKey.isEmpty {
            continuation.finish(throwing: GrokBuildError.missingAPIKey)
            return
          }

          let url = configuration.baseURL.appendingPathComponent("chat/completions")

          var request = URLRequest(url: url)
          request.httpMethod = "POST"
          request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")

          let body = GrokBuildRequest(
            model: configuration.model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens
          )

          request.httpBody = try JSONEncoder().encode(body)

          let (bytes, response) = try await session.bytes(for: request)

          if let httpResponse = response as? HTTPURLResponse,
            !(200...299).contains(httpResponse.statusCode)
          {
            print("[GrokBuildService] HTTP \(httpResponse.statusCode) from \(url.absoluteString)")
            continuation.finish(
              throwing: GrokBuildError.invalidResponse(statusCode: httpResponse.statusCode))
            return
          }

          guard response is HTTPURLResponse else {
            continuation.finish(throwing: GrokBuildError.invalidResponse(statusCode: nil))
            return
          }

          for try await line in bytes.lines {
            if line.hasPrefix("data: ") {
              let jsonString = String(line.dropFirst(6))

              if jsonString == "[DONE]" {
                continuation.finish()
                return
              }

              guard let data = jsonString.data(using: .utf8) else { continue }

              if let chunk = try? JSONDecoder().decode(GrokBuildStreamChunk.self, from: data),
                let content = chunk.choices.first?.delta.content,
                !content.isEmpty
              {
                continuation.yield(content)
              }
            }
          }

          continuation.finish()

        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
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

  enum CodingKeys: String, CodingKey {
    case model, messages, temperature
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
      return
        "Grok Build API key is missing. The Grok AI tab uses your saved xAI key (or a separate key saved for .grokBuild). Add it in Settings → Developer Key if you haven't already."
    case .invalidResponse(let code):
      if let c = code {
        return "Invalid response from Grok Build (HTTP \(c)). Check your API key and model access."
      }
      return "Invalid response from Grok Build"
    case .apiError(let code, let msg): return "API Error (\(code)): \(msg)"
    }
  }
}
