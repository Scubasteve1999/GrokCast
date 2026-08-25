import SwiftUI

/// Shared dark-sheet-on-stage chrome for Today, Forecast, Alerts, Radar dock, and More.
enum WeatherStageSheet {
  static let topRadius: CGFloat = DesignTokens.Radius.xLarge
  static var fill: Color { DesignTokens.Palette.bgSecondary }

  /// Compact tab-bar height. Radar dock uses this so the fill meets the bar.
  /// `DesignTokens.Layout.tabBarScrollClearance` is for scrolling content only —
  /// using it to lift the dock leaves a light-map strip above the tab bar.
  static let tabBarClearance: CGFloat = CompactTabBar.chromeHeight
}

enum MoreHubPresentation {
  static let defaultDetent: PresentationDetent = .medium
  static let availableDetents: Set<PresentationDetent> = [.medium, .large]
}

extension View {
  /// Dark sheet that sits on `WeatherStage`. Top corners only; bottom meets the tab bar.
  func weatherStageSheet() -> some View {
    padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.top, DesignTokens.Spacing.space20)
      .padding(.bottom, WeatherStageSheet.tabBarClearance)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(WeatherStageSheet.fill)
      .clipShape(
        UnevenRoundedRectangle(
          topLeadingRadius: WeatherStageSheet.topRadius,
          topTrailingRadius: WeatherStageSheet.topRadius,
          style: .continuous
        )
      )
  }
}
