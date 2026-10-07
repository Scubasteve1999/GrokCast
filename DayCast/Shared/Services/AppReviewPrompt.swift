import StoreKit
import SwiftUI
import UIKit

/// Soft App Store review prompts (system dialog) plus a Settings deep-link to write a review.
///
/// Apple limits how often the system dialog appears; we only *ask* StoreKit after meaningful
/// use and at most once per marketing version. Settings always offers a direct Rate link.
enum AppReviewPrompt {
  private static let sessionsKey = "daycast.review.meaningfulSessions"
  private static let lastVersionKey = "daycast.review.lastVersionPrompted"

  /// Sessions with a successful weather load before we ask StoreKit.
  private static let minimumSessions = 4

  /// Process-lifetime guards (not persisted).
  @MainActor private static var recordedSessionThisLaunch = false
  @MainActor private static var requestedReviewThisLaunch = false

  static var appStoreURL: URL {
    URL(string: "https://apps.apple.com/app/id\(ShareAttribution.appStoreID)")!
  }

  static var writeReviewURL: URL {
    URL(string: "https://apps.apple.com/app/id\(ShareAttribution.appStoreID)?action=write-review")!
  }

  /// Call after weather has loaded successfully (once per app launch).
  @MainActor
  static func recordMeaningfulSessionIfNeeded() {
    guard !isMarketingScreenshotLaunch else { return }
    guard !recordedSessionThisLaunch else { return }
    recordedSessionThisLaunch = true
    let defaults = UserDefaults.standard
    defaults.set(defaults.integer(forKey: sessionsKey) + 1, forKey: sessionsKey)
  }

  /// Hourly-curve hours a user scrubbed through this launch.
  @MainActor private static var inspectedHourIndexes = Set<Int>()
  /// Distinct hours scrubbed before the curve counts as a positive action.
  static let hourlyInspectionThreshold = 3
  /// Continuous seconds on Radar before it counts as a positive action.
  static let radarDwellSeconds = 30

  /// Set by `AppReviewPromptModifier` so positive actions anywhere in the app can ask.
  @MainActor static var requestReviewAction: RequestReviewAction?

  /// The user scrubbed the hourly curve to `index`. Three distinct hours is engagement.
  @MainActor
  static func recordHourInspected(index: Int) {
    inspectedHourIndexes.insert(index)
    guard inspectedHourIndexes.count >= hourlyInspectionThreshold else { return }
    considerRequestingReview()
  }

  /// The user stayed on Radar for `radarDwellSeconds`.
  @MainActor
  static func recordRadarDwell() {
    considerRequestingReview()
  }

  @MainActor
  static func considerRequestingReview() {
    guard let requestReview = requestReviewAction else { return }
    guard
      shouldPrompt(
        sessions: UserDefaults.standard.integer(forKey: sessionsKey),
        lastVersionPrompted: UserDefaults.standard.string(forKey: lastVersionKey),
        currentVersion: currentMarketingVersion,
        requestedThisLaunch: requestedReviewThisLaunch,
        arguments: ProcessInfo.processInfo.arguments)
    else { return }

    requestedReviewThisLaunch = true
    UserDefaults.standard.set(currentMarketingVersion, forKey: lastVersionKey)
    requestReview()
  }

  /// Pure gate. Never prompts under UI tests or marketing screenshots.
  static func shouldPrompt(
    sessions: Int,
    lastVersionPrompted: String?,
    currentVersion: String,
    requestedThisLaunch: Bool,
    arguments: [String]
  ) -> Bool {
    guard !arguments.contains(PostHogAnalytics.uiTestLaunchArgument) else { return false }
    guard !arguments.contains(marketingScreenshotArgument) else { return false }
    guard !requestedThisLaunch else { return false }
    guard sessions >= minimumSessions else { return false }
    return lastVersionPrompted != currentVersion
  }

  static func openWriteReview() {
    UIApplication.shared.open(writeReviewURL)
  }

  private static var currentMarketingVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
  }

  private static let marketingScreenshotArgument = "-MarketingScreenshot"

  private static var isMarketingScreenshotLaunch: Bool {
    ProcessInfo.processInfo.arguments.contains(marketingScreenshotArgument)
  }
}

/// Records sessions and hands StoreKit's review action to `AppReviewPrompt`. It never asks
/// on its own: the prompt waits for a positive action (see `recordHourInspected`).
struct AppReviewPromptModifier: ViewModifier {
  @Environment(\.requestReview) private var requestReview
  @Environment(WeatherStore.self) private var store
  @Environment(\.scenePhase) private var scenePhase

  func body(content: Content) -> some View {
    content
      .onChange(of: store.currentWeather?.fetchedAt) { _, fetchedAt in
        guard fetchedAt != nil else { return }
        AppReviewPrompt.recordMeaningfulSessionIfNeeded()
      }
      .onChange(of: scenePhase) { _, phase in
        guard phase == .active, store.currentWeather != nil else { return }
        AppReviewPrompt.recordMeaningfulSessionIfNeeded()
      }
      .task {
        AppReviewPrompt.requestReviewAction = requestReview
        // Cover cold start when weather was already cached before the modifier attached.
        guard store.currentWeather != nil, scenePhase == .active else { return }
        AppReviewPrompt.recordMeaningfulSessionIfNeeded()
      }
  }
}

extension View {
  func appReviewPrompting() -> some View {
    modifier(AppReviewPromptModifier())
  }
}
