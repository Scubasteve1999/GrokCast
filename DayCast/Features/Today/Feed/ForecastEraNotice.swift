import Foundation

/// Quiet, date-gated honesty about the NCEP short-range model cutover (SCN 26-48 / 26-47).
/// Separate from `HonestyStrip` — do not fold this into the WFO / ensemble second line.
///
/// DayCast does **not** ingest RRFS/REFS GRIB. This is partner transparency about
/// upstream NWS short-range models, not a claim that DayCast switched engines.
///
/// Feeds that may *feel* the era change (indirectly): WFO text products via
/// `api.weather.gov` (AFD / PNS on Your News), NWS alerts/obs narrative tone.
/// Feeds that stay on a different stack: Open-Meteo (primary numbers + ICON ensemble),
/// Site Doppler / National radar paint, OWM. HRRR short-term precip is not this cutover.
struct EraNoticeConfig: Codable, Equatable, Sendable {
  var id: String
  var cutoverUTC: Date
  var windowStartUTC: Date
  var windowEndUTC: Date
  var status: Status
  var updatedAt: Date

  enum Status: String, Codable, Sendable {
    case scheduled
    case slipped
    case done
  }
}

enum ForecastEraNotice {
  /// Bump / remote slip to re-show after a dismiss. One id per window.
  static let fallbackId = "scn-26-48-2026-10-14"
  static var id: String { effective().id }

  static let dismissedIdKey = "daycast.forecastEraNotice.dismissedId"
  static let forceShowKey = "daycast.debug.forceForecastEraNotice"
  static let cachedJSONKey = "daycast.forecastEraNotice.cachedJSON"
  static let lastFetchAtKey = "daycast.forecastEraNotice.lastFetchAt"
  static let minRefreshInterval: TimeInterval = 15 * 60

  /// Overridable so tests use an isolated suite. The test bundle is hosted by the app.
  nonisolated(unsafe) static var store: UserDefaults = .standard
  /// Tests replace this. Production hits `GET /era-notice`.
  nonisolated(unsafe) static var dataLoader: @Sendable () async -> Data? = liveLoad

  /// NCEP production implementation, 1200 UTC. May slip on a Critical Weather Day.
  static let cutoverUTC = utc("2026-10-14T12:00:00Z")
  /// 7 days before cutover.
  static let windowStartUTC = utc("2026-10-07T12:00:00Z")
  /// 14 days after cutover (exclusive).
  static let windowEndUTC = utc("2026-10-28T12:00:00Z")
  static let earliestUTC = utc("2026-10-01T00:00:00Z")
  static let latestUTC = utc("2026-12-31T23:59:59Z")

  static let fallback = EraNoticeConfig(
    id: fallbackId,
    cutoverUTC: cutoverUTC,
    windowStartUTC: windowStartUTC,
    windowEndUTC: windowEndUTC,
    status: .scheduled,
    updatedAt: utc("2026-10-03T00:00:00Z")
  )

  static func effective(defaults: UserDefaults = store) -> EraNoticeConfig {
    cachedConfig(defaults: defaults) ?? fallback
  }

  static func cachedConfig(defaults: UserDefaults = store) -> EraNoticeConfig? {
    guard let raw = defaults.string(forKey: cachedJSONKey),
      let data = raw.data(using: .utf8)
    else { return nil }
    return decode(data)
  }

  static func decode(_ data: Data) -> EraNoticeConfig? {
    guard let config = try? decoder.decode(EraNoticeConfig.self, from: data) else { return nil }
    return sanitized(config)
  }

  static func sanitized(_ config: EraNoticeConfig) -> EraNoticeConfig? {
    let id = config.id.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !id.isEmpty else { return nil }
    guard config.windowStartUTC >= earliestUTC,
      config.cutoverUTC >= earliestUTC,
      config.windowEndUTC >= earliestUTC,
      config.windowStartUTC <= latestUTC,
      config.cutoverUTC <= latestUTC,
      config.windowEndUTC <= latestUTC,
      config.windowStartUTC < config.cutoverUTC,
      config.cutoverUTC < config.windowEndUTC
    else { return nil }
    var clean = config
    clean.id = id
    return clean
  }

  static func isInWindow(now: Date, defaults: UserDefaults = store) -> Bool {
    let config = effective(defaults: defaults)
    return now >= config.windowStartUTC && now < config.windowEndUTC
  }

  /// Today banner: in the UTC window and not dismissed, or DEBUG force-show.
  static func shouldShowBanner(now: Date = Date(), defaults: UserDefaults = store) -> Bool {
    #if DEBUG
      if defaults.bool(forKey: forceShowKey) { return true }
    #endif
    guard isInWindow(now: now, defaults: defaults) else { return false }
    return defaults.string(forKey: dismissedIdKey) != effective(defaults: defaults).id
  }

  /// Settings / re-read: available throughout the window even after dismiss.
  static func shouldOfferExplainer(now: Date = Date(), defaults: UserDefaults = store) -> Bool {
    #if DEBUG
      if defaults.bool(forKey: forceShowKey) { return true }
    #endif
    return isInWindow(now: now, defaults: defaults)
  }

  static func dismiss(defaults: UserDefaults = store) {
    defaults.set(effective(defaults: defaults).id, forKey: dismissedIdKey)
  }

  static func resetDismiss(defaults: UserDefaults = store) {
    defaults.removeObject(forKey: dismissedIdKey)
  }

  static func shouldRefresh(now: Date = Date(), defaults: UserDefaults = store) -> Bool {
    guard defaults.object(forKey: lastFetchAtKey) != nil else { return true }
    let last = defaults.double(forKey: lastFetchAtKey)
    return now.timeIntervalSince1970 - last >= minRefreshInterval
  }

  /// Soft-fail refresh. Never throws. Cache, then constants, on a miss.
  @discardableResult
  static func refreshRemote(
    now: Date = Date(),
    defaults: UserDefaults = store,
    force: Bool = false
  ) async -> EraNoticeConfig {
    if !force, !shouldRefresh(now: now, defaults: defaults) {
      return effective(defaults: defaults)
    }
    defaults.set(now.timeIntervalSince1970, forKey: lastFetchAtKey)
    guard let data = await dataLoader() else {
      return effective(defaults: defaults)
    }
    guard let config = decode(data),
      let encoded = try? encoder.encode(config),
      let json = String(data: encoded, encoding: .utf8)
    else {
      return effective(defaults: defaults)
    }
    defaults.set(json, forKey: cachedJSONKey)
    return config
  }

  static func liveLoad() async -> Data? {
    guard let base = RefsAgreementConfiguration.baseURL else { return nil }
    let url = base.appendingPathComponent("era-notice")
    do {
      let (data, response) = try await URLSession.shared.data(from: url)
      guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
        return nil
      }
      return data
    } catch {
      return nil
    }
  }

  static func formattedCutover(_ date: Date, locale: Locale = .current) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateStyle = .long
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }

  enum Copy {
    static let banner = "Upstream NWS short-range models are changing"
    static let cardTitle = "What this means"
    static var opener: String { opener(for: ForecastEraNotice.effective()) }

    static func opener(for config: EraNoticeConfig, locale: Locale = .current) -> String {
      let date = ForecastEraNotice.formattedCutover(config.cutoverUTC, locale: locale)
      switch config.status {
      case .scheduled:
        return
          "On or around \(date), NCEP is replacing older short-range systems (NAM, HREF, SREF, HiresW) with RRFS and REFS."
      case .slipped:
        return
          "NWS moved the switch to \(date) after a Critical Weather Day. NCEP is replacing older short-range systems (NAM, HREF, SREF, HiresW) with RRFS and REFS."
      case .done:
        return
          "On \(date), NCEP replaced older short-range systems (NAM, HREF, SREF, HiresW) with RRFS and REFS."
      }
    }

    static let timingRisk =
      "If NWS calls a Critical Weather Day or significant weather, the cutover may slip to the next suitable weekday."
    static let behavior =
      "Some forecast behavior you notice in local NWS products — office discussions, for example — may shift. DayCast is not inventing a new forecast engine for this."
    static let notOfficial =
      "DayCast is not NOAA, NWS, or FEMA, and it is not a wireless emergency alert. Keep Government Alerts on."
    static let cite =
      "Official notice: SCN 26-48 (RRFS and REFS). SCN 26-47 retires NAM, SREF, HREF, HiresW, and NAM MOS."
    static let scn48LinkTitle = "SCN 26-48 (weather.gov PDF)"
    static let scn47LinkTitle = "SCN 26-47 retirement (weather.gov PDF)"
    static let dismiss = "Dismiss"
    static let notWEA = "DayCast is not an official wireless emergency alert."
    /// Test / Settings sample only. Not Mid-South product gating.
    static let memphisSample =
      "NWS Memphis · office discussion may shift with the upstream model change"

    static var paragraphs: [String] { [opener, timingRisk, behavior, notOfficial, cite] }

    static var visibleStrings: [String] {
      [banner, cardTitle] + paragraphs + [scn48LinkTitle, scn47LinkTitle, dismiss, memphisSample]
    }

    static var bannerAccessibility: String { "\(banner). \(notWEA)" }

    static var cardAccessibility: String {
      "\(cardTitle). \(opener) \(notOfficial)"
    }
  }

  private static let iso: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
  }()

  private static let isoFractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
  }()

  private static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let text = try container.decode(String.self)
      if let date = isoFractional.date(from: text) ?? iso.date(from: text) {
        return date
      }
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Expected an ISO-8601 instant"
      )
    }
    return decoder
  }()

  private static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = .custom { date, encoder in
      var container = encoder.singleValueContainer()
      try container.encode(iso.string(from: date))
    }
    return encoder
  }()

  private static func utc(_ string: String) -> Date {
    guard let date = iso.date(from: string) else {
      preconditionFailure("ForecastEraNotice UTC date must parse: \(string)")
    }
    return date
  }
}
