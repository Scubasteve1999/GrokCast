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
  /// NWS SCN 26-48 — RRFS + REFS implementation (Oct 14, 2026, 1200 UTC).
  static let nwsSCN2648 = URL(
    string:
      "https://www.weather.gov/media/notification/pdf_2026/scn26-048_Updated_RRFS_and_REFS_Implementation_aad.pdf"
  )!
  /// NWS SCN 26-47 — retire NAM, SREF, HREF, HiresW, NAM MOS.
  static let nwsSCN2647 = URL(
    string:
      "https://www.weather.gov/media/notification/pdf_2026/SCN26-47_Updated_Retire_NAM_SREF_HREF_HiresW_NAM_MOS.aab.pdf"
  )!
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
    static let updatedAt = "daycast.today.updatedAt"
    static let errorBanner = "daycast.today.errorBanner"
    static let root = "daycast.today.root"
    static let takeOptions = "daycast.today.takeOptions"
    static let getStarted = "daycast.today.getStarted"
    static let continuePermission = "daycast.today.continuePermission"
    static let enableLocation = "daycast.today.enableLocation"
    static let openSettings = "daycast.today.openSettings"
    static let statusPill = "daycast.today.statusPill"
    static let alertsSlot = "daycast.today.alertsSlot"
    static let honestyStrip = "daycast.today.honestyStrip"
    static let forecastEraNotice = "daycast.today.forecastEraNotice"
    static let forecastEraNoticeDismiss = "daycast.today.forecastEraNotice.dismiss"
    static let forecastEraNoticeCard = "daycast.today.forecastEraNotice.card"
    static let forecastEraNoticeSCN48 = "daycast.today.forecastEraNotice.scn48"
    static let forecastEraNoticeSCN47 = "daycast.today.forecastEraNotice.scn47"
    static let health = "daycast.today.health"
    static let precip = "daycast.today.precip"
    static let yourNews = "daycast.today.yourNews"
    static let addCity = "daycast.today.addCity"
    static let addCitySearch = "daycast.today.addCity.search"
    static let addCitySearchField = "daycast.today.addCity.searchField"
  }

  enum Radar {
    static let root = "daycast.radar.root"
    static let liveBadge = "daycast.radar.live"
    static let unavailableCard = "daycast.radar.unavailable"
    static let unavailableRetry = "daycast.radar.unavailableRetry"
  }

  enum Grok {
    static let stormSpotterAnalyze = "daycast.grok.stormSpotter.analyze"
    static let skyCheckCamera = "daycast.grok.skyCheck.camera"
    static let skyCheckLibrary = "daycast.grok.skyCheck.library"
    static let skyCheckCameraFail = "daycast.grok.skyCheck.cameraFail"
    static let chatField = "daycast.grok.chatField"
    static let screenTitle = "daycast.grok.screenTitle"
    static let glanceDetails = "daycast.grok.glanceDetails"
    static let glanceForecast = "daycast.grok.glanceForecast"
    static let glanceRadar = "daycast.grok.glanceRadar"
  }

  enum Settings {
    static let proEntry = "daycast.settings.pro"
    static let activePlan = "daycast.settings.pro.plan"
    static let activeUnlocks = "daycast.settings.pro.unlocks"
    static let forecastEraNotice = "daycast.settings.forecastEraNotice"
  }

  enum Alerts {
    static let retry = "daycast.alerts.retry"
    static let screenTitle = "daycast.alerts.screenTitle"
    static let authority = "daycast.alerts.authority"
    static let noActiveCaption = "daycast.alerts.noActive"
    static let localBriefing = "daycast.alerts.localBriefing"
    static let stormReports = "daycast.alerts.stormReports"
  }

  enum Locations {
    static let searchField = "daycast.locations.searchField"
    static let searchSubmit = "daycast.locations.searchSubmit"
    static let chips = "daycast.locations.chips"
    static let freeLimitChip = "daycast.locations.freeLimit"
    static let saveUnlimitedCTA = "daycast.locations.saveUnlimited"
    static func result(_ name: String) -> String { "daycast.locations.result.\(name)" }
    static func chip(_ name: String) -> String { "daycast.locations.chip.\(name)" }
    static func savedRow(_ name: String) -> String { "daycast.locations.saved.\(name)" }
    static func deleteSaved(_ name: String) -> String { "daycast.locations.delete.\(name)" }
  }
}
