import Foundation

/// Configuration for the xAI Grok API in developer-key mode.
/// Keys are always loaded from the secure Keychain via KeychainService.
struct GrokAPIConfiguration {
  /// The operating mode for the Grok API integration.
  enum Mode: String {
    case developerKey = "developer-key"
  }

  let mode: Mode
  let baseURL: URL
  let defaultModel: String
  let chatEndpoint: String
  let imageGenerationEndpoint: String
  let imageModel: String

  /// Secure key provider. Never stores the key itself.
  private let keychain: KeychainService

  init(
    mode: Mode = .developerKey,
    keychain: KeychainService = .shared
  ) {
    self.mode = mode
    self.keychain = keychain

    // Production xAI endpoints (as of 2026)
    self.baseURL = URL(string: "https://api.x.ai/v1")!
    self.defaultModel = "grok-3-mini"
    self.chatEndpoint = "chat/completions"
    self.imageGenerationEndpoint = "images/generations"
    self.imageModel = "grok-imagine-image-quality"
  }

  // MARK: - Static convenience (matches GrokAPIConfiguration.swift.example template)
  static let baseURLString = "https://api.x.ai/v1"
  static let defaultModelName = "grok-3-mini"
  static let chatEndpointPath = "/v1/chat/completions"
  static let imageModelName = "grok-imagine-image-quality"
  static let requestTimeout: TimeInterval = 30

  // MARK: - Secure Key Access

  /// Returns the current developer API key.
  ///
  /// Priority:
  /// 1. Key stored in iOS Keychain (user-entered via Settings) — wins so Settings saves take effect
  /// 2. Embedded developer key from `Config/DeveloperAPIKey.swift` (TestFlight / internal builds)
  var developerAPIKey: String? {
    guard mode == .developerKey else { return nil }

    if let keychainKey = try? keychain.load(), !keychainKey.isEmpty {
      return keychainKey
    }

    if let embeddedKey = DeveloperAPIKey.xai, !embeddedKey.isEmpty {
      return embeddedKey
    }

    return nil
  }

  var hasValidDeveloperKey: Bool {
    guard let key = developerAPIKey, !key.isEmpty else { return false }
    // Basic developer key format check for xAI keys
    return key.hasPrefix("xai-") && key.count > 20
  }

  /// Saves a new developer key securely to the Keychain.
  func saveDeveloperKey(_ key: String) throws {
    guard mode == .developerKey else {
      throw GrokAPIError.invalidMode("Can only save keys in developer-key mode")
    }
    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("xai-") else {
      throw GrokAPIError.invalidKeyFormat
    }
    try keychain.save(trimmed)
  }

  /// Deletes the developer key from secure storage.
  func clearDeveloperKey() throws {
    try keychain.delete()
  }

  // MARK: - Request Helpers

  var chatURL: URL {
    baseURL.appendingPathComponent(chatEndpoint)
  }

  var imageGenerationURL: URL {
    baseURL.appendingPathComponent(imageGenerationEndpoint)
  }

  func authHeader() throws -> String {
    guard let key = developerAPIKey else {
      throw GrokAPIError.missingAPIKey
    }
    return "Bearer \(key)"
  }
}

// MARK: - Errors

enum GrokAPIError: Error, LocalizedError {
  case missingAPIKey
  case invalidKeyFormat
  case invalidMode(String)
  case networkError(Error)
  case apiError(statusCode: Int, message: String)
  case decodingError

  var errorDescription: String? {
    switch self {
    case .missingAPIKey:
      return "Add an xAI developer key in Settings to use AI features."
    case .invalidKeyFormat:
      return "Invalid xAI API key format. Keys must start with 'xai-'."
    case .invalidMode(let message):
      return message
    case .networkError(let error):
      if let urlError = error as? URLError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
          return "No internet connection. Check your Wi-Fi or cellular and try again."
        case .timedOut:
          return "The request timed out. The service may be busy — tap Retry in a moment."
        default:
          return "Network error. Please check your connection and try again."
        }
      }
      return "Network error: \(error.localizedDescription)"
    case .apiError(let statusCode, let message):
      let lower = message.lowercased()
      if lower.contains("incorrect api key") || lower.contains("invalid api key")
        || lower.contains("unauthorized")
      {
        return "AI key isn’t valid. Add a working xAI key in Settings (starts with xai-)."
      }
      switch statusCode {
      case 401, 403:
        return "AI key isn’t authorized. Verify it in Settings."
      case 429:
        return "Too many requests. Please wait and try again."
      case 400, 422:
        // Never surface raw JSON bodies to users / App Review.
        return "AI request couldn’t be completed. Check your key in Settings, then try again."
      case 500...599:
        return "AI service temporarily unavailable. Please try again later."
      default:
        return "AI service error. Please try again."
      }
    case .decodingError:
      return "Received an unexpected response from xAI. Please try again."
    }
  }
}
