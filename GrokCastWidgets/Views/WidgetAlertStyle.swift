import SwiftUI

/// Severity styling for widget alert badges (mirrors app `NWSAlertStyle` via event name + level).
enum WidgetAlertStyle {
  static func tint(for summary: WidgetAlertSummary) -> Color {
    if summary.topIsWarning { return .red }
    if summary.topIsWatch { return .orange }
    if summary.topSeverityLevel >= 3 { return .red }
    if summary.topSeverityLevel >= 2 { return .orange }
    return .yellow
  }

  static func iconName(for summary: WidgetAlertSummary) -> String {
    if summary.topIsWarning || summary.topSeverityLevel >= 3 {
      return "exclamationmark.triangle.fill"
    }
    return "exclamationmark.circle.fill"
  }
}
