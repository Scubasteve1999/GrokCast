import CoreGraphics

/// First viewport: type-on-photo Now (rain line + alert pill) and the
/// outlook sheet starting. News / conditions sit below the fold.
enum TodayGlanceLayout {
  /// iPhone 16 logical height. Do not use iPhone 17 / iOS 27 as the peek target.
  static let iPhone16ScreenHeight: CGFloat = 852
  static let iPhone16StatusBarHeight: CGFloat = 59
  static let inlineNavHeight: CGFloat = 44

  static let feedSpacing: CGFloat = DesignTokens.Spacing.space12
  static let sheetSectionSpacing: CGFloat = DesignTokens.Spacing.space24
  static let cardPadding: CGFloat = DesignTokens.Spacing.space12
  static var nowTempSize: CGFloat { DesignTokens.Layout.todayTempSize }
  /// Type-on-stage Now (temp + glyph + feels + rain line). Photo is the tab background.
  static let nowBudgetHeight: CGFloat = 200
  static let alertChipMinHeight: CGFloat = 56
  static let radarHeaderHeight: CGFloat = 22
  static let radarInnerSpacing: CGFloat = DesignTokens.Spacing.space8
  static var radarMapHeight: CGFloat { RadarPreviewSource.teaserHeight }
  static var radarCardHeight: CGFloat {
    cardPadding * 2 + radarHeaderHeight + radarInnerSpacing + radarMapHeight
  }
  static let hourlyHeaderHeight: CGFloat = 28
  static let hourlyInnerSpacing: CGFloat = 8
  static let hourlyCardPadding: CGFloat = DesignTokens.Spacing.space4
  /// Three-line callout for the Tonight / next-period sentence.
  static let hourlyTonightLineHeight: CGFloat = 56
  static let hourlyPickerHeight: CGFloat = 36
  static var hourlyGraphHeight: CGFloat { HourlyGraphLayout.height }
  static var hourlyCardHeight: CGFloat {
    hourlyCardPadding * 2 + hourlyHeaderHeight + hourlyTonightLineHeight
      + hourlyGraphHeight + hourlyPickerHeight + hourlyInnerSpacing * 3
  }
  static let decisionCardHeight: CGFloat = 56
  static let nextEventCardHeight: CGFloat = 72
  static let sheetTopRadius: CGFloat = WeatherStageSheet.topRadius

  static var visibleFeedHeightIPhone16: CGFloat {
    iPhone16ScreenHeight
      - iPhone16StatusBarHeight
      - inlineNavHeight
      - CompactTabBar.chromeHeight
      - LocationChipBar.reservedHeight
  }

  /// Photo hero + outlook sheet start. Alert pill sits in the hero.
  static var oliveBranchStoryStackHeight: CGFloat {
    nowBudgetHeight + alertChipMinHeight + hourlyCardHeight + feedSpacing * 2
  }
}
