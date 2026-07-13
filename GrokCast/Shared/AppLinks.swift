import Foundation

enum AppLinks {
  // SpotterCast GitHub Pages uses clean paths (privacy/, terms/) — `.html` URLs 404.
  static let privacyPolicy = URL(
    string: "https://scubasteve1999.github.io/SpotterCast/privacy/")!
  static let termsOfUse = URL(
    string: "https://scubasteve1999.github.io/SpotterCast/terms/")!
  static let support = URL(string: "https://scubasteve1999.github.io/SpotterCast/support/")!
  static let supportEmail = URL(string: "mailto:stephenmoorecm1357@gmail.com")!
  static let xAIConsole = URL(string: "https://console.x.ai/")!
  static let openMeteo = URL(string: "https://open-meteo.com/")!
}
