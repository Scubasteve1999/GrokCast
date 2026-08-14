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

  @MainActor
  static func considerRequestingReview(_ requestReview: RequestReviewAction) {
    guard !isMarketingScreenshotLaunch else { return }
    guard !requestedReviewThisLaunch else { return }
    guard shouldRequestReview else { return }

    requestedReviewThisLaunch = true
    let version = currentMarketingVersion
    UserDefaults.standard.set(version, forKey: lastVersionKey)

    Task { @MainActor in
      try? await Task.sleep(for: .seconds(2))
      requestReview()
    }
  }

  static func openWriteReview() {
    UIApplication.shared.open(writeReviewURL)
  }

  private static var shouldRequestReview: Bool {
    let defaults = UserDefaults.standard
    let sessions = defaults.integer(forKey: sessionsKey)
    guard sessions >= minimumSessions else { return false }
    let last = defaults.string(forKey: lastVersionKey)
    return last != currentMarketingVersion
  }

  private static var currentMarketingVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
  }

  private static var isMarketingScreenshotLaunch: Bool {
    ProcessInfo.processInfo.arguments.contains("-MarketingScreenshot")
  }
}

/// Records engagement and optionally asks StoreKit to show the review dialog.
struct AppReviewPromptModifier: ViewModifier {
  @Environment(\.requestReview) private var requestReview
  @Environment(WeatherStore.self) private var store
  @Environment(\.scenePhase) private var scenePhase

  func body(content: Content) -> some View {
    content
      .onChange(of: store.currentWeather?.fetchedAt) { _, fetchedAt in
        guard fetchedAt != nil else { return }
        AppReviewPrompt.recordMeaningfulSessionIfNeeded()
        guard scenePhase == .active else { return }
        AppReviewPrompt.considerRequestingReview(requestReview)
      }
      .onChange(of: scenePhase) { _, phase in
        guard phase == .active, store.currentWeather != nil else { return }
        AppReviewPrompt.recordMeaningfulSessionIfNeeded()
        AppReviewPrompt.considerRequestingReview(requestReview)
      }
      .task {
        // Cover cold start when weather was already cached before the modifier attached.
        guard store.currentWeather != nil, scenePhase == .active else { return }
        AppReviewPrompt.recordMeaningfulSessionIfNeeded()
        AppReviewPrompt.considerRequestingReview(requestReview)
      }
  }
}

extension View {
  func appReviewPrompting() -> some View {
    modifier(AppReviewPromptModifier())
  }
}
