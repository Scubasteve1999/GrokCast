import CoreGraphics

/// First viewport: type-on-photo Now, live alert chip, Temperature curve,
/// Outlook radar plate, and a Your News peek (or header) on iPhone 16 (852pt).
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
  static var radarMapHeight: CGFloat { RadarPreviewSource.outlookPlateHeight }
  static var radarCardHeight: CGFloat {
    cardPadding * 2 + radarHeaderHeight + radarInnerSpacing + radarMapHeight
  }
  static let hourlyHeaderHeight: CGFloat = 28
  static let hourlyInnerSpacing: CGFloat = 8
  static let hourlyCardPadding: CGFloat = DesignTokens.Spacing.space4
  static let hourlyPickerHeight: CGFloat = 36
  static var hourlyGraphHeight: CGFloat { HourlyGraphLayout.height }
  /// Temperature curve only. Outlook owns the tonight sentence.
  static var hourlyCardHeight: CGFloat {
    hourlyCardPadding * 2 + hourlyGraphHeight + hourlyInnerSpacing
  }
  static let sheetTopRadius: CGFloat = WeatherStageSheet.topRadius

  static var visibleFeedHeightIPhone16: CGFloat {
    iPhone16ScreenHeight
      - iPhone16StatusBarHeight
      - inlineNavHeight
      - CompactTabBar.chromeHeight
      - LocationChipBar.reservedHeight
  }

  /// Now + alert chip + Temperature curve + Outlook plate. Your News peeks below
  /// (header peek is the floor; card peek is better).
  static var oliveBranchStoryStackHeight: CGFloat {
    nowBudgetHeight + alertChipMinHeight + hourlyCardHeight
      + radarCardHeight + feedSpacing * 3
  }
}
