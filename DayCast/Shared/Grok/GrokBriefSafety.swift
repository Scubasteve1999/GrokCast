import CryptoKit
import Foundation

/// Persisted 4.7 block controls for Today's Take: hide one brief, or turn the feature off.
@MainActor
@Observable
final class GrokBriefSafety {
  static let shared = GrokBriefSafety()

  static let featureHiddenKey = "grok_brief_feature_hidden"
  static let hiddenBriefHashesKey = "grok_brief_hidden_hashes"
  static let maxHiddenHashes = 50

  private let defaults: UserDefaults

  var isFeatureHidden: Bool {
    didSet { defaults.set(isFeatureHidden, forKey: Self.featureHiddenKey) }
  }

  private var hiddenHashes: [String] {
    didSet { defaults.set(hiddenHashes, forKey: Self.hiddenBriefHashesKey) }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    isFeatureHidden = defaults.bool(forKey: Self.featureHiddenKey)
    hiddenHashes = defaults.stringArray(forKey: Self.hiddenBriefHashesKey) ?? []
  }

  func hideBrief(_ text: String) {
    let digest = Self.hash(text)
    var next = hiddenHashes.filter { $0 != digest }
    next.insert(digest, at: 0)
    if next.count > Self.maxHiddenHashes {
      next = Array(next.prefix(Self.maxHiddenHashes))
    }
    hiddenHashes = next
  }

  func isBriefHidden(_ text: String) -> Bool {
    hiddenHashes.contains(Self.hash(text))
  }

  static func hash(_ text: String) -> String {
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let digest = SHA256.hash(data: Data(normalized.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}
