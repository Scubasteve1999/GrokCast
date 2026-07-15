import SwiftUI
import UIKit

/// Shared severity styling for NWS alerts (Warning = red, Watch = orange).
enum NWSAlertStyle {
  static func tint(for alert: NWSAlert) -> Color {
    if alert.isWarning { return .red }
    if alert.isWatch { return .orange }
    if alert.severityLevel >= 3 { return .red }
    if alert.severityLevel >= 2 { return .orange }
    return .yellow
  }

  static func iconName(for alert: NWSAlert) -> String {
    if alert.isWarning || alert.severityLevel >= 3 {
      return "exclamationmark.triangle.fill"
    }
    return "exclamationmark.circle.fill"
  }

  /// MapKit / UIKit tint for Radar annotation pins.
  static func uiTint(for alert: NWSAlert) -> UIColor {
    if alert.isWarning { return .systemRed }
    if alert.isWatch { return .systemOrange }
    if alert.severityLevel >= 3 { return .systemRed }
    if alert.severityLevel >= 2 { return .systemOrange }
    return .systemYellow
  }
}
