import Foundation

enum XAIError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case networkError(Error)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "No xAI API key set. Add it in Settings."
        case .invalidResponse: "Invalid response from xAI."
        case .networkError(let err): "Network error: \(err.localizedDescription)"
        case .apiError(let msg): msg
        }
    }
}

struct XAIChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
    let error: APIError?

    struct APIError: Decodable {
        let message: String
    }
}

@Observable
final class XAIService {
    var apiKey: String = ""
    var isLoading = false
    var lastError: String?

    private let baseURL = URL(string: "https://api.x.ai/v1")!
    private let model = "grok-3-mini" // or "grok-3" for more powerful

    init() {
        // Key is now loaded via WeatherStore from Keychain. This is fallback.
    }

    func saveAPIKey(_ key: String) {
        apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        // Note: Primary storage moved to KeychainService in WeatherStore
    }

    func hasAPIKey() -> Bool {
        !apiKey.isEmpty
    }

    func sendMessage(messages: [ChatMessage], context: String? = nil) async throws -> String {
        guard !apiKey.isEmpty else { throw XAIError.missingAPIKey }

        isLoading = true
        lastError = nil

        var allMessages = messages
        if let context = context, !context.isEmpty {
            // Prepend context as system if not already present
            let systemContext = ChatMessage(role: .system, content: context)
            allMessages.insert(systemContext, at: 0)
        }

        let payload: [String: Any] = [
            "model": model,
            "messages": allMessages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "temperature": 0.7,
            "max_tokens": 600
        ]

        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw XAIError.invalidResponse
            }

            if http.statusCode == 401 {
                throw XAIError.apiError("Invalid xAI API key. Check Settings.")
            }

            let decoded = try JSONDecoder().decode(XAIChatResponse.self, from: data)

            if let apiErr = decoded.error {
                throw XAIError.apiError(apiErr.message)
            }

            guard let content = decoded.choices.first?.message.content else {
                throw XAIError.invalidResponse
            }

            isLoading = false
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch let error as XAIError {
            isLoading = false
            lastError = error.localizedDescription
            throw error
        } catch {
            isLoading = false
            lastError = error.localizedDescription
            throw XAIError.networkError(error)
        }
    }

    // Helper to build a rich system prompt with current weather (updated for new models)
    func buildWeatherSystemPrompt(for weather: GrokCastWeather) -> String {
        let temp = Int(round(weather.currentTemp))
        let feels = Int(round(weather.feelsLike))
        let high = Int(round(weather.high))
        let low = Int(round(weather.low))
        let condition = weather.conditionText
        let precip = weather.precipitationChance
        let loc = weather.location.name
        let aqi = weather.airQualityIndex.map { "AQI: \($0)" } ?? ""
        let pollen = weather.pollenLevel.map { "Pollen: \($0)" } ?? ""

        return """
        You are Grok, built by xAI — tactical weather intelligence for GrokCast.

        Location: \(loc)
        Current: \(temp)°F (feels \(feels)°F) • \(condition)
        High/Low: \(high)° / \(low)°
        Precip: \(precip)% • UV: \(Int(weather.uvIndex)) • \(aqi) \(pollen)

        Respond with precision, dark humor when appropriate, and actionable life-impact predictions (commute, outdoor plans, health, gear). Keep most answers to 3-6 sentences.
        """
    }

    // MARK: - Grok Vision (Sky Photo Analysis)
    func analyzeSkyPhoto(base64Image: String, forecastContext: String) async throws -> String {
        guard !apiKey.isEmpty else { throw XAIError.missingAPIKey }

        isLoading = true
        lastError = nil

        let visionModel = "grok-4.3" // or current vision-capable model

        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    [
                        "type": "input_image",
                        "image_url": "data:image/jpeg;base64,\(base64Image)"
                    ],
                    [
                        "type": "input_text",
                        "text": "Analyze this sky photo in detail. Compare it to the current forecast: \(forecastContext). Does the sky match the forecast? Any signs of incoming severe weather the models might have missed? Be tactical and specific."
                    ]
                ]
            ]
        ]

        let payload: [String: Any] = [
            "model": visionModel,
            "messages": messages,
            "max_tokens": 800
        ]

        return try await performChatRequest(payload: payload, endpoint: "chat/completions")
    }

    // MARK: - Grok Imagine (Image Generation)
    func generateDayImage(prompt: String) async throws -> URL {
        guard !apiKey.isEmpty else { throw XAIError.missingAPIKey }

        isLoading = true
        lastError = nil

        let url = baseURL.appendingPathComponent("images/generations")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "grok-imagine-image-quality",
            "prompt": prompt,
            "n": 1,
            "size": "1024x1024"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw XAIError.invalidResponse
        }

        // Parse response (xAI returns { data: [{ url: "..." }] } similar to OpenAI)
        struct ImageResponse: Decodable {
            struct Data: Decodable { let url: String }
            let data: [Data]
        }

        let decoded = try JSONDecoder().decode(ImageResponse.self, from: data)
        guard let firstURL = decoded.data.first?.url, let result = URL(string: firstURL) else {
            throw XAIError.invalidResponse
        }

        isLoading = false
        return result
    }

    private func performChatRequest(payload: [String: Any], endpoint: String = "chat/completions") async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw XAIError.invalidResponse }
        if http.statusCode == 401 { throw XAIError.apiError("Invalid xAI API key") }

        let decoded = try JSONDecoder().decode(XAIChatResponse.self, from: data)
        if let apiErr = decoded.error { throw XAIError.apiError(apiErr.message) }

        guard let content = decoded.choices.first?.message.content else {
            throw XAIError.invalidResponse
        }

        isLoading = false
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}