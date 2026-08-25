import SwiftUI
import UIKit

/// Shared severity styling for NWS alerts.
/// Danger red is reserved for official warnings / life-threatening products.
enum NWSAlertStyle {
  enum Emphasis: Equatable {
    case warning
    case watch
    case advisory
  }

  static func emphasis(for alert: NWSAlert) -> Emphasis {
    if alert.usesWarningEmphasis { return .warning }
    if alert.isWatch || alert.severityLevel >= 2 { return .watch }
    return .advisory
  }

  static func tint(for alert: NWSAlert) -> Color {
    switch emphasis(for: alert) {
    case .warning: DesignTokens.Palette.danger
    case .watch: DesignTokens.Palette.warning
    case .advisory: DesignTokens.Palette.accentWarm
    }
  }

  static func iconName(for alert: NWSAlert) -> String {
    if alert.usesWarningEmphasis || alert.isWatch {
      return "exclamationmark.triangle.fill"
    }
    return "exclamationmark.circle.fill"
  }

  /// MapKit / UIKit tint for Radar annotation pins.
  static func uiTint(for alert: NWSAlert) -> UIColor {
    switch emphasis(for: alert) {
    case .warning: .systemRed
    case .watch: .systemOrange
    case .advisory: .systemYellow
    }
  }
}
