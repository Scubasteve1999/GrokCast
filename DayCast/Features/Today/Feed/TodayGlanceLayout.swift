import CoreGraphics

/// First viewport: type-on-photo Now, live alert chip, Temperature curve,
/// Outlook radar plate, and a Your News card peek on iPhone 16 (852pt).
enum TodayGlanceLayout {
  /// iPhone 16 logical height. Do not use iPhone 17 / iOS 27 as the peek target.
  static let iPhone16ScreenHeight: CGFloat = 852
  static let iPhone16StatusBarHeight: CGFloat = 59
  static let inlineNavHeight: CGFloat = 44

  static let feedSpacing: CGFloat = DesignTokens.Spacing.space12
  static let sheetSectionSpacing: CGFloat = DesignTokens.Spacing.space12
  static let heroBottomPadding: CGFloat = DesignTokens.Spacing.space8
  static let sheetTopPadding: CGFloat = DesignTokens.Spacing.space12
  static let cardPadding: CGFloat = DesignTokens.Spacing.space12
  static var nowTempSize: CGFloat { DesignTokens.Layout.todayTempSize }
  /// Type-on-stage Now (temp + glyph + feels + rain line). Photo is the tab background.
  /// Hard cap — wet rain / minutecast lines cannot grow the hero past this.
  static let nowBudgetHeight: CGFloat = 160
  static var nowHeroMaxHeight: CGFloat { nowBudgetHeight }
  static let alertChipMinHeight: CGFloat = 56
  static let radarHeaderHeight: CGFloat = 22
  static let radarInnerSpacing: CGFloat = DesignTokens.Spacing.space8
  static var radarMapHeight: CGFloat { RadarPreviewSource.outlookPlateHeight }
  /// Unplated Outlook: tonight line + 168pt plate. Today never plates this card.
  static var radarCardHeight: CGFloat {
    radarHeaderHeight + radarInnerSpacing + radarMapHeight
  }
  static let hourlyHeaderHeight: CGFloat = 28
  static let hourlyInnerSpacing: CGFloat = 8
  static let hourlyCardPadding: CGFloat = DesignTokens.Spacing.space4
  static let hourlyPickerHeight: CGFloat = 36
  static var hourlyGraphHeight: CGFloat { HourlyGraphLayout.height }
  /// Temperature curve only. Outlook owns the tonight sentence.
  static var hourlyCardHeight: CGFloat { hourlyGraphHeight }
  static let sheetTopRadius: CGFloat = WeatherStageSheet.topRadius
  /// Floor for one Your News headline card in the first viewport (title + card start).
  static let yourNewsCardPeekHeight: CGFloat = 80

  static var visibleFeedHeightIPhone16: CGFloat {
    iPhone16ScreenHeight
      - iPhone16StatusBarHeight
      - inlineNavHeight
      - CompactTabBar.chromeHeight
      - LocationChipBar.reservedHeight
  }

  /// Now + alert chip + Temperature curve + Outlook plate. Your News card peeks below.
  static var oliveBranchStoryStackHeight: CGFloat {
    nowBudgetHeight
      + feedSpacing
      + alertChipMinHeight
      + heroBottomPadding
      + sheetTopPadding
      + hourlyCardHeight
      + sheetSectionSpacing
      + radarCardHeight
      + sheetSectionSpacing
  }

  static var oliveBranchYourNewsPeek: CGFloat {
    visibleFeedHeightIPhone16 - oliveBranchStoryStackHeight
  }
}
