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
enum ForecastEraNotice {
  /// Bump to re-show after a dismiss. One id per window.
  static let id = "scn-26-48-2026-10-14"

  static let dismissedIdKey = "daycast.forecastEraNotice.dismissedId"
  static let forceShowKey = "daycast.debug.forceForecastEraNotice"

  /// Overridable so tests use an isolated suite. The test bundle is hosted by the app.
  nonisolated(unsafe) static var store: UserDefaults = .standard

  /// NCEP production implementation, 1200 UTC. May slip on a Critical Weather Day.
  static let cutoverUTC = utc("2026-10-14T12:00:00Z")
  /// 7 days before cutover.
  static let windowStartUTC = utc("2026-10-07T12:00:00Z")
  /// 14 days after cutover (exclusive).
  static let windowEndUTC = utc("2026-10-28T12:00:00Z")

  static func isInWindow(now: Date) -> Bool {
    now >= windowStartUTC && now < windowEndUTC
  }

  /// Today banner: in the UTC window and not dismissed, or DEBUG force-show.
  static func shouldShowBanner(now: Date = Date(), defaults: UserDefaults = store) -> Bool {
    #if DEBUG
      if defaults.bool(forKey: forceShowKey) { return true }
    #endif
    guard isInWindow(now: now) else { return false }
    return defaults.string(forKey: dismissedIdKey) != id
  }

  /// Settings / re-read: available throughout the window even after dismiss.
  static func shouldOfferExplainer(now: Date = Date(), defaults: UserDefaults = store) -> Bool {
    #if DEBUG
      if defaults.bool(forKey: forceShowKey) { return true }
    #endif
    return isInWindow(now: now)
  }

  static func dismiss(defaults: UserDefaults = store) {
    defaults.set(id, forKey: dismissedIdKey)
  }

  static func resetDismiss(defaults: UserDefaults = store) {
    defaults.removeObject(forKey: dismissedIdKey)
  }

  enum Copy {
    static let banner = "Upstream NWS short-range models are changing"
    static let cardTitle = "What this means"
    static let opener =
      "On or around October 14, 2026, NCEP is replacing older short-range systems (NAM, HREF, SREF, HiresW) with RRFS and REFS."
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

  private static func utc(_ string: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    guard let date = formatter.date(from: string) else {
      preconditionFailure("ForecastEraNotice UTC date must parse: \(string)")
    }
    return date
  }
}
