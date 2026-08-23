import Foundation

/// Outlook is not a warning. NWS point alerts own warning chrome and counts.
/// SPC Day 1 / MD / LSR stay visible without a fake “1 ALERT” badge.
enum AlertsHonesty {
  struct Chrome: Equatable {
    /// Visible screen title. Outlook-only is not titled like a warning list.
    let screenTitle: String
    /// Red ACTIVE NOW — NWS point alerts only.
    let showsActiveNow: Bool
    /// Quiet line when SPC products are present but NWS count is 0.
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
  static let outlookTitle = "Outlook"
  static let noActiveAlerts = "No active alerts"
  static let activeNow = "ACTIVE NOW"
  static let todayOutlookTitle = "Severe outlook"
  static let todayWarningTitle = "Active Alerts"
  static let tabSymbolWithAlerts = "bell.badge.fill"
  static let tabSymbolIdle = "bell.fill"

  static func chrome(nwsAlertCount: Int, hasSevereProducts: Bool) -> Chrome {
    let nws = max(0, nwsAlertCount)
    if nws > 0 {
      let noun = nwsCountPhrase(nws)
      return Chrome(
        screenTitle: tabTitle,
        showsActiveNow: true,
        noActiveAlertsCaption: nil,
        tabSymbolName: tabSymbolWithAlerts,
        tabAccessibilityLabel: tabTitle,
        tabAccessibilityValue: noun,
        screenAccessibilityLabel: "\(tabTitle). \(noun)"
      )
    }
    if hasSevereProducts {
      return Chrome(
        screenTitle: outlookTitle,
        showsActiveNow: false,
        noActiveAlertsCaption: noActiveAlerts,
        tabSymbolName: tabSymbolIdle,
        tabAccessibilityLabel: tabTitle,
        tabAccessibilityValue: noActiveAlerts,
        screenAccessibilityLabel: outlookTitle
      )
    }
    return Chrome(
      screenTitle: tabTitle,
      showsActiveNow: false,
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
  static func todaySlotAccessibility(nwsAlertCount: Int) -> String {
    if nwsAlertCount > 0 {
      return "\(todayWarningTitle). \(nwsCountPhrase(nwsAlertCount))"
    }
    return todayOutlookTitle
  }

  static func nwsCountPhrase(_ count: Int) -> String {
    count == 1 ? "1 active alert" : "\(count) active alerts"
  }
}
