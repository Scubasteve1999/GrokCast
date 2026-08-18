import Foundation

enum AppLinks {
  // Pages are hosted from the GrokCast repo (docs/), not a separate DayCast repo.
  static let privacyPolicy = URL(
    string: "https://scubasteve1999.github.io/GrokCast/privacy.html")!
  static let termsOfUse = URL(
    string: "https://scubasteve1999.github.io/GrokCast/terms.html")!
  static let support = URL(string: "https://scubasteve1999.github.io/GrokCast/support.html")!
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
    static let root = "daycast.moreHub.root"
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

  enum Alerts {
    static let retry = "daycast.alerts.retry"
  }

  enum Locations {
    static let searchField = "daycast.locations.searchField"
    static let searchSubmit = "daycast.locations.searchSubmit"
    static func result(_ name: String) -> String { "daycast.locations.result.\(name)" }
  }
}
