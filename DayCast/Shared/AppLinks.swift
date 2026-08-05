import Foundation

enum AppLinks {
  // DayCast GitHub Pages uses clean paths (privacy/, terms/) — `.html` URLs 404.
  static let privacyPolicy = URL(
    string: "https://scubasteve1999.github.io/DayCast/privacy/")!
  static let termsOfUse = URL(
    string: "https://scubasteve1999.github.io/DayCast/terms/")!
  static let support = URL(string: "https://scubasteve1999.github.io/DayCast/support/")!
  static let supportEmail = URL(string: "mailto:stephenmoorecm1357@gmail.com")!
  static let xAIConsole = URL(string: "https://console.x.ai/")!
  static let openMeteo = URL(string: "https://open-meteo.com/")!
  static let appStore = AppReviewPrompt.appStoreURL
  static let writeReview = AppReviewPrompt.writeReviewURL
}

/// Stable accessibility identifiers for XCUITest and VoiceOver.
enum DayCastAccessibility {
  /// The custom `CompactTabBar` items. The hidden system tab bar under
  /// `.tabViewStyle(.sidebarAdaptable)` still publishes buttons with the same
  /// labels ("Radar", "More", …), so tests must match on these instead.
  enum Tabs {
    static func item(_ tab: CompactTab) -> String { "daycast.tab.\(tab.rawValue)" }
  }

  /// Rows inside `MoreHubSheet`, keyed by the destination tab.
  enum MoreHub {
    static func row(_ tab: WeatherStore.Tab) -> String { "daycast.moreHub.\(tab.rawValue)" }
  }

  enum Today {
    static let location = "daycast.today.location"
    static let temperature = "daycast.today.temperature"
    static let root = "daycast.today.root"
  }

  enum Radar {
    static let root = "daycast.radar.root"
    static let liveBadge = "daycast.radar.live"
  }

  enum Grok {
    static let stormSpotterAnalyze = "daycast.grok.stormSpotter.analyze"
    static let chatField = "daycast.grok.chatField"
  }

  enum Settings {
    static let proEntry = "daycast.settings.pro"
  }
}
