import SwiftUI

/// Severity styling for widget alert badges (mirrors app `NWSAlertStyle` via event name + level).
enum WidgetAlertStyle {
  static func tint(for summary: WidgetAlertSummary) -> Color {
    if summary.topIsWarning { return DesignTokens.Palette.danger }
    if summary.topIsWatch { return DesignTokens.Palette.warning }
    return DesignTokens.Palette.accentWarm
  }

  static func iconName(for summary: WidgetAlertSummary) -> String {
    if summary.topIsWarning || summary.topIsWatch {
      return "exclamationmark.triangle.fill"
    }
    return "exclamationmark.circle.fill"
  }
}
