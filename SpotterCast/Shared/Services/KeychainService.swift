import Foundation
import Security

enum KeychainError: Error {
  case duplicateItem
  case itemNotFound
  case unexpectedStatus(OSStatus)
  case encodingError
}

/// Supported API key types for multi-key Keychain storage.
/// Allows separate secure storage for the main xAI key (weather Grok chat/vision)
/// and a distinct Grok Build key (for the grok-build-0.1 model / in-app code features).
enum APIKeyType {
  case xai
  case grokBuild
}

final class KeychainService {
  static let shared = KeychainService()
  private init() {}

  private let service = "com.grokcast.GrokCast.xai"

  private func account(for type: APIKeyType) -> String {
    switch type {
    case .xai: return "xai_api_key"
    case .grokBuild: return "grok_build_api_key"
    }
  }

  func save(_ key: String) throws {
    try saveAPIKey(key, for: .xai)
  }

  func saveAPIKey(_ key: String, for type: APIKeyType) throws {
    guard let data = key.data(using: .utf8) else { throw KeychainError.encodingError }

    // Delete existing first (upsert pattern)
    try? delete(for: type)

    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account(for: type),
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw KeychainError.unexpectedStatus(status)
    }
  }

  func load() throws -> String {
    return try load(for: .xai)
  }

  private func load(for type: APIKeyType) throws -> String {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account(for: type),
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    guard status == errSecSuccess else {
      if status == errSecItemNotFound {
        throw KeychainError.itemNotFound
      }
      throw KeychainError.unexpectedStatus(status)
    }

    guard let data = item as? Data,
      let key = String(data: data, encoding: .utf8)
    else {
      throw KeychainError.encodingError
    }
    return key
  }

  /// Returns the API key for the given type, or nil if not present / load fails.
  /// This is the entry point used by GrokBuildService (and future multi-key consumers).
  func getAPIKey(for type: APIKeyType) -> String? {
    do {
      return try load(for: type)
    } catch {
      return nil
    }
  }

  func delete() throws {
    try delete(for: .xai)
  }

  func delete(for type: APIKeyType) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account(for: type),
    ]

    let status = SecItemDelete(query as CFDictionary)
    if status != errSecSuccess && status != errSecItemNotFound {
      throw KeychainError.unexpectedStatus(status)
    }
  }

  func hasKey() -> Bool {
    return hasKey(for: .xai)
  }

  func hasKey(for type: APIKeyType) -> Bool {
    return getAPIKey(for: type) != nil
  }
}
