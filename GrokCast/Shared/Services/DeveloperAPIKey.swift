import Foundation

/// Embedded API keys for development and TestFlight builds.
/// 
/// **Production builds should leave these as `nil` and rely on user-entered keys in Settings.**
///
/// For TestFlight or internal testing:
/// - Add your xAI developer key here as a temporary measure
/// - Never commit real keys to version control
/// - Use `.gitignore` to exclude this file if needed
struct DeveloperAPIKey {
    /// Embedded xAI API key for weather chat and vision features.
    /// Falls back to Keychain if `nil`.
    static let xai: String? = nil
    
    /// Embedded Grok Build API key for code generation features.
    /// Falls back to Keychain if `nil`.
    static let grokBuild: String? = nil
}
