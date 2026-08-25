import CoreGraphics

/// First-viewport budget so Your News peeks on iPhone 16 — including a story day
/// with an alert chip + hoisted Site Doppler + tonight line + hourly graph.
enum TodayGlanceLayout {
  /// iPhone 16 logical height. Do not use iPhone 17 / iOS 27 as the peek target.
  static let iPhone16ScreenHeight: CGFloat = 852
  static let iPhone16StatusBarHeight: CGFloat = 59
  static let inlineNavHeight: CGFloat = 44

  static let feedSpacing: CGFloat = DesignTokens.Spacing.space12
  static let cardPadding: CGFloat = DesignTokens.Spacing.space12
  static var nowTempSize: CGFloat { DesignTokens.Layout.todayTempSize }
  static let nowBudgetHeight: CGFloat = 112
  static let alertChipMinHeight: CGFloat = 44
  static let radarHeaderHeight: CGFloat = 22
  static let radarInnerSpacing: CGFloat = DesignTokens.Spacing.space8
  static var radarMapHeight: CGFloat { RadarPreviewSource.teaserHeight }
  static var radarCardHeight: CGFloat {
    cardPadding * 2 + radarHeaderHeight + radarInnerSpacing + radarMapHeight
  }
  static let hourlyHeaderHeight: CGFloat = 24
  static let hourlyInnerSpacing: CGFloat = 6
  static let hourlyCardPadding: CGFloat = DesignTokens.Spacing.space8
  /// Two-line callout for the Tonight / next-period sentence.
  static let hourlyTonightLineHeight: CGFloat = 36
  static var hourlyGraphHeight: CGFloat { HourlyGraphLayout.height }
  static var hourlyCardHeight: CGFloat {
    hourlyCardPadding * 2 + hourlyHeaderHeight + hourlyTonightLineHeight
      + hourlyGraphHeight + hourlyInnerSpacing * 2
  }
  /// Your News section title + first headline line. Enough to count as a peek.
  static let yourNewsPeekMinHeight: CGFloat = 56

  static var visibleFeedHeightIPhone16: CGFloat {
    iPhone16ScreenHeight
      - iPhone16StatusBarHeight
      - inlineNavHeight
      - CompactTabBar.chromeHeight
      - LocationChipBar.reservedHeight
  }

  /// Olive Branch story day: Now + 1 alert chip + hoisted radar + tonight/graph + news peek.
  static var oliveBranchStoryStackHeight: CGFloat {
    let cards =
      nowBudgetHeight + alertChipMinHeight + radarCardHeight + hourlyCardHeight
      + yourNewsPeekMinHeight
    return cards + feedSpacing * 4
  }
}
