import Foundation
import UIKit

final class XAIService {
  private let configuration: GrokAPIConfiguration

  init(configuration: GrokAPIConfiguration) {
    self.configuration = configuration
  }

  func hasAPIKey() -> Bool {
    configuration.hasValidDeveloperKey
  }

  var hasValidKey: Bool {
    configuration.hasValidDeveloperKey
  }

  var isUsingEmbeddedDeveloperKey: Bool {
    guard let key = DeveloperAPIKey.xai, !key.isEmpty else { return false }
    return true
  }

  var maskedAPIKey: String {
    guard let key = configuration.developerAPIKey, key.count > 8 else { return "••••••••" }
    return "\(key.prefix(7))••••••\(key.suffix(4))"
  }

  func buildWeatherSystemPrompt(for weather: GrokCastWeather) -> String {
    let temp = Int(round(weather.currentTemp))
    let feels = Int(round(weather.feelsLike))
    return """
      You are Grok, a witty and knowledgeable AI weather assistant built into GrokCast. \
      You have access to the current weather data for \(weather.location.name).

      Current conditions:
      - Temperature: \(temp)°F (feels like \(feels)°F)
      - Conditions: \(weather.conditionText)
      - Humidity: \(weather.humidity)%
      - Wind: \(Int(round(weather.windSpeed))) mph
      - Precipitation chance: \(weather.precipitationChance)%
      - UV Index: \(String(format: "%.1f", weather.uvIndex))
      - High: \(Int(round(weather.high)))°F / Low: \(Int(round(weather.low)))°F

      Respond in a helpful, engaging, and occasionally witty manner. Keep responses concise.
      """
  }

  func sendMessage(messages: [ChatMessage], context: String?) async throws -> String {
    let authHeader = try configuration.authHeader()

    var apiMessages: [[String: String]] = []
    if let context {
      apiMessages.append(["role": "system", "content": context])
    }
    for message in messages where message.role != .system {
      apiMessages.append(["role": message.role.rawValue, "content": message.content])
    }

    let body: [String: Any] = [
      "model": configuration.defaultModel,
      "messages": apiMessages,
      "max_tokens": 512,
    ]

    return try await performChatRequest(body: body, authHeader: authHeader)
  }

  func performAdvancedStormAnalysis(
    imageData: Data, weather: GrokCastWeather?, alerts: [NWSAlert]? = nil,
    nearestStationObservation: NWSObservation? = nil, userNotes: String?
  ) async throws -> String {
    let authHeader = try configuration.authHeader()
    let body = try buildStormAnalysisBody(
      imageData: imageData, weather: weather, alerts: alerts,
      nearestStationObservation: nearestStationObservation, userNotes: userNotes, stream: false)
    return try await performChatRequest(body: body, authHeader: authHeader)
  }

  /// Streaming variant of storm photo analysis (grok-4.3 vision + SSE tokens).
  func streamAdvancedStormAnalysis(
    imageData: Data, weather: GrokCastWeather?, alerts: [NWSAlert]? = nil,
    nearestStationObservation: NWSObservation? = nil, userNotes: String?
  ) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
      Task {
        do {
          let authHeader = try configuration.authHeader()
          let body = try buildStormAnalysisBody(
            imageData: imageData, weather: weather, alerts: alerts,
            nearestStationObservation: nearestStationObservation, userNotes: userNotes,
            stream: true)

          var request = URLRequest(url: configuration.chatURL)
          request.httpMethod = "POST"
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          request.setValue(authHeader, forHTTPHeaderField: "Authorization")
          request.httpBody = try JSONSerialization.data(withJSONObject: body)
          request.timeoutInterval = 120

          let (bytes, response) = try await URLSession.shared.bytes(for: request)

          guard let http = response as? HTTPURLResponse else {
            continuation.finish(throwing: GrokAPIError.networkError(URLError(.badServerResponse)))
            return
          }

          guard http.statusCode == 200 else {
            var errorData = Data()
            for try await byte in bytes {
              errorData.append(byte)
            }
            if let json = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String
            {
              continuation.finish(throwing: GrokAPIError.apiError(statusCode: http.statusCode, message: message))
            } else {
              let bodyString = String(data: errorData, encoding: .utf8) ?? ""
              continuation.finish(
                throwing: GrokAPIError.apiError(statusCode: http.statusCode, message: bodyString))
            }
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

  private func buildStormAnalysisBody(
    imageData: Data, weather: GrokCastWeather?, alerts: [NWSAlert]?,
    nearestStationObservation: NWSObservation?, userNotes: String?, stream: Bool
  ) throws -> [String: Any] {
    var systemContent = GrokPrompts.stormSpotterSystemPrompt
    if let weather {
      systemContent +=
        "\n\n"
        + GrokPrompts.buildTechnicalStormContext(
          for: weather, alerts: alerts ?? [], nearestStationObservation: nearestStationObservation,
          userNotes: userNotes)
    }

    let compressedData = imageData.compressedForVision() ?? imageData
    let base64 = compressedData.base64EncodedString()

    let userContent: [[String: Any]] = [
      [
        "type": "text",
        "text": "Analyze the attached sky or storm photograph using the provided context.",
      ],
      ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]],
    ]

    var body: [String: Any] = [
      "model": "grok-4.3",
      "messages": [
        ["role": "system", "content": systemContent],
        ["role": "user", "content": userContent],
      ],
      "max_tokens": 1024,
    ]
    if stream {
      body["stream"] = true
    }
    return body
  }

  func generateDayImage(prompt: String) async throws -> URL {
    let authHeader = try configuration.authHeader()

    let body: [String: Any] = [
      "model": configuration.imageModel,
      "prompt": prompt,
      "n": 1,
      "response_format": "url",
    ]

    var request = URLRequest(url: configuration.imageGenerationURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(authHeader, forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    request.timeoutInterval = 60

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let http = response as? HTTPURLResponse else {
      throw GrokAPIError.networkError(URLError(.badServerResponse))
    }

    guard http.statusCode == 200 else {
      if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let error = json["error"] as? [String: Any],
        let message = error["message"] as? String
      {
        throw GrokAPIError.apiError(statusCode: http.statusCode, message: message)
      }
      let bodyString = String(data: data, encoding: .utf8) ?? ""
      throw GrokAPIError.apiError(statusCode: http.statusCode, message: bodyString)
    }

    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let dataArray = json["data"] as? [[String: Any]],
      let first = dataArray.first,
      let urlString = first["url"] as? String,
      let url = URL(string: urlString)
    else {
      throw GrokAPIError.decodingError
    }

    return url
  }

  private func performChatRequest(body: [String: Any], authHeader: String) async throws -> String {
    var request = URLRequest(url: configuration.chatURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(authHeader, forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    request.timeoutInterval = GrokAPIConfiguration.requestTimeout

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let http = response as? HTTPURLResponse else {
      throw GrokAPIError.networkError(URLError(.badServerResponse))
    }

    guard http.statusCode == 200 else {
      if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let error = json["error"] as? [String: Any],
        let message = error["message"] as? String
      {
        throw GrokAPIError.apiError(statusCode: http.statusCode, message: message)
      }
      let bodyString = String(data: data, encoding: .utf8) ?? ""
      throw GrokAPIError.apiError(statusCode: http.statusCode, message: bodyString)
    }

    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let choices = json["choices"] as? [[String: Any]],
      let first = choices.first,
      let message = first["message"] as? [String: Any],
      let content = message["content"] as? String
    else {
      throw GrokAPIError.decodingError
    }

    return content
  }
}

// MARK: - Vision Image Helpers

extension Data {
  /// Compresses image data for vision API calls (resizes to max 1024px, JPEG quality 0.75)
  /// to avoid huge payloads and potential 422/400 errors from oversized base64.
  /// Also usable for small thumbnails (call with smaller maxDimension).
  func compressedForVision(maxDimension: CGFloat = 1024, quality: CGFloat = 0.75) -> Data? {
    guard let image = UIImage(data: self) else { return nil }

    let size = image.size
    let scale = Swift.min(maxDimension / Swift.max(size.width, size.height), 1.0)
    let newSize = CGSize(width: size.width * scale, height: size.height * scale)

    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
    image.draw(in: CGRect(origin: .zero, size: newSize))
    let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return resizedImage?.jpegData(compressionQuality: quality)
  }
}
