import Foundation

/// Which product surface triggered a Grok call. Reported with `ai_request` so
/// AI spend can be attributed to a feature rather than a lump total — the
/// difference between knowing AI costs money and knowing what to change.
enum GrokFeature: String {
  case chat
  case todaysTake = "todays_take"
  case explainRadar = "explain_radar"
  case alertsSummary = "alerts_summary"
  case stormPhoto = "storm_photo"
  case morningBrief = "morning_brief"
  case imagine
  case tripPlanner = "trip_planner"
  case connectionTest = "connection_test"
}

/// Which daily budget a Grok call draws from. Image generation costs far more
/// per request, so it gets its own allowance and cannot drain chat.
enum GrokUsageBucket: String, CaseIterable {
  case chat
  case image

  /// Mirrors `DAILY_CHAT_LIMIT` / `DAILY_IMAGE_LIMIT` in the proxy's wrangler.toml.
  var dailyLimit: Int {
    switch self {
    case .chat: return 150
    case .image: return 10
    }
  }
}

/// Client-side mirror of the proxy's daily caps.
///
/// The server is the real control — this exists so a runaway loop on device
/// can't burn a subscriber's whole allowance before the server starts refusing.
/// Counters reset at UTC midnight to match the proxy exactly, so the "resets at"
/// time we show is the same one the server would report.
struct GrokUsageLimiter {
  static let shared = GrokUsageLimiter()

  private let defaults: UserDefaults
  private let now: () -> Date

  init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
    self.defaults = defaults
    self.now = now
  }

  private static let keyPrefix = "spottercast.grokUsage.v1"

  private static let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private func key(for bucket: GrokUsageBucket, date: Date) -> String {
    "\(Self.keyPrefix).\(bucket.rawValue).\(Self.dayFormatter.string(from: date))"
  }

  func used(_ bucket: GrokUsageBucket) -> Int {
    max(0, defaults.integer(forKey: key(for: bucket, date: now())))
  }

  func remaining(_ bucket: GrokUsageBucket) -> Int {
    max(0, bucket.dailyLimit - used(bucket))
  }

  /// Next UTC midnight — what the "resets at" copy shows.
  func resetDate() -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let startOfDay = calendar.startOfDay(for: now())
    return calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
  }

  /// Takes one unit if the budget allows. Returns false when the cap is reached.
  @discardableResult
  func consume(_ bucket: GrokUsageBucket) -> Bool {
    let today = key(for: bucket, date: now())
    let used = max(0, defaults.integer(forKey: today))
    guard used < bucket.dailyLimit else { return false }

    defaults.set(used + 1, forKey: today)
    pruneStaleCounters()
    return true
  }

  /// Hands a unit back when a request never reached the model, matching the
  /// proxy's refund-on-upstream-failure behaviour.
  func refund(_ bucket: GrokUsageBucket) {
    let today = key(for: bucket, date: now())
    let used = defaults.integer(forKey: today)
    guard used > 0 else { return }
    defaults.set(used - 1, forKey: today)
  }

  /// Drops counters from previous days so this never grows without bound.
  private func pruneStaleCounters() {
    let live = Set(GrokUsageBucket.allCases.map { key(for: $0, date: now()) })
    for storedKey in defaults.dictionaryRepresentation().keys
    where storedKey.hasPrefix(Self.keyPrefix) && !live.contains(storedKey) {
      defaults.removeObject(forKey: storedKey)
    }
  }
}
