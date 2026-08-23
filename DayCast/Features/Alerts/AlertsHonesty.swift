import Foundation

/// Outlook is not a warning. NWS point alerts own warning chrome and counts.
/// SPC Day 1 / MD / LSR stay visible without a fake “1 ALERT” badge.
enum AlertsHonesty {
  struct Chrome: Equatable {
    /// Visible screen title. Outlook-only is not titled like a warning list.
    let screenTitle: String
    /// Red ACTIVE NOW — NWS point alerts only.
    let showsActiveNow: Bool
    /// Day 1 risk line under the title. Leads outlook-only, never a warning count.
    let riskCaption: String?
    /// Quiet honesty when SPC products are present but NWS count is 0.
    let noActiveAlertsCaption: String?
    /// Tab SF Symbol. `bell.badge.fill` only when NWS count > 0.
    let tabSymbolName: String
    /// VoiceOver for the Alerts tab. Never implies a count when NWS is 0.
    let tabAccessibilityLabel: String
    let tabAccessibilityValue: String?
    /// VoiceOver for the screen title.
    let screenAccessibilityLabel: String
  }

  static let tabTitle = "Alerts"
  static let outlookTitle = "Severe Outlook"
  static let noActiveAlerts = "No active NWS alerts"
  static let activeNow = "ACTIVE NOW"
  static let todayOutlookTitle = "Severe outlook"
  static let todayOutlookCardHeading = "Severe Outlook"
  static let todayWarningTitle = "Active Alerts"
  static let tabSymbolWithAlerts = "bell.badge.fill"
  static let tabSymbolIdle = "bell.fill"

  static func chrome(
    nwsAlertCount: Int,
    hasSevereProducts: Bool,
    outlookSummary: String? = nil
  ) -> Chrome {
    let nws = max(0, nwsAlertCount)
    if nws > 0 {
      let noun = nwsCountPhrase(nws)
      return Chrome(
        screenTitle: tabTitle,
        showsActiveNow: true,
        riskCaption: nil,
        noActiveAlertsCaption: nil,
        tabSymbolName: tabSymbolWithAlerts,
        tabAccessibilityLabel: tabTitle,
        tabAccessibilityValue: noun,
        screenAccessibilityLabel: "\(tabTitle). \(noun)"
      )
    }
    if hasSevereProducts {
      let summary = trimmed(outlookSummary)
      return Chrome(
        screenTitle: outlookTitle,
        showsActiveNow: false,
        riskCaption: summary,
        noActiveAlertsCaption: noActiveAlerts,
        tabSymbolName: tabSymbolIdle,
        tabAccessibilityLabel: tabTitle,
        tabAccessibilityValue: joinedAccessibility([summary, noActiveAlerts]),
        screenAccessibilityLabel: joinedAccessibility([outlookTitle, summary, noActiveAlerts])
      )
    }
    return Chrome(
      screenTitle: tabTitle,
      showsActiveNow: false,
      riskCaption: nil,
      noActiveAlertsCaption: nil,
      tabSymbolName: tabSymbolIdle,
      tabAccessibilityLabel: tabTitle,
      tabAccessibilityValue: nil,
      screenAccessibilityLabel: tabTitle
    )
  }

  static func tabSymbolName(nwsAlertCount: Int) -> String {
    chrome(nwsAlertCount: nwsAlertCount, hasSevereProducts: false).tabSymbolName
  }

  static func todaySlotTitle(nwsAlertCount: Int) -> String {
    nwsAlertCount > 0 ? todayWarningTitle : todayOutlookTitle
  }

  /// VoiceOver for the Today alerts slot. Outlook-only must not say there is an active alert.
  static func todaySlotAccessibility(
    nwsAlertCount: Int,
    outlookSummary: String? = nil
  ) -> String {
    if nwsAlertCount > 0 {
      return "\(todayWarningTitle). \(nwsCountPhrase(nwsAlertCount))"
    }
    return joinedAccessibility([todayOutlookTitle, trimmed(outlookSummary)])
  }

  static func nwsCountPhrase(_ count: Int) -> String {
    count == 1 ? "1 active alert" : "\(count) active alerts"
  }

  private static func trimmed(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func joinedAccessibility(_ parts: [String?]) -> String {
    parts.compactMap { trimmed($0) }.joined(separator: ". ")
  }
}
