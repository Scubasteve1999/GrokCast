import Foundation

/// Today Now presentation policy. Photography is the face; SF Symbols are chrome only.
enum NowHeroPhotography {
  enum Treatment: Equatable {
    case photography(assetName: String)
    case systemGlyph(symbolName: String)
  }

  /// Product rule: a blocky weather glyph is never the face of Now.
  static let glyphIsSectionFace = false

  /// Plate height. Width is always the feed's proposed width — never the JPEG's.
  static var plateHeight: CGFloat { TodayGlanceLayout.nowBudgetHeight }

  /// Size an inset still is clipped to. `containerWidth` is the feed card width.
  static func plateSize(containerWidth: CGFloat) -> CGSize {
    CGSize(width: max(0, containerWidth), height: plateHeight)
  }

  /// Full-bleed tab stage. Width/height are the screen, never JPEG intrinsic.
  static func stageSize(containerSize: CGSize) -> CGSize {
    CGSize(width: max(0, containerSize.width), height: max(0, containerSize.height))
  }

  /// Bundled cinematic stills in `Assets.xcassets`. Not Imagine, not news keywords.
  static let knownAssetNames: Set<String> = [
    "NewsHeroDawn",
    "NewsHeroFlood",
    "NewsHeroHaze",
    "NewsHeroLightning",
    "NewsHeroSky",
    "NewsHeroStorm",
  ]

  static func stillName(conditionCode: Int?, isDay: Bool) -> String {
    switch WeatherCondition(fromWMO: conditionCode ?? -1) {
    case .clear:
      return isDay ? "NewsHeroSky" : "NewsHeroStorm"
    case .mainlyClear:
      return isDay ? "NewsHeroDawn" : "NewsHeroSky"
    case .overcast, .fog, .unknown:
      return "NewsHeroHaze"
    case .drizzle, .rain, .rainShowers, .sleet, .snow, .snowGrains, .snowShowers:
      return "NewsHeroStorm"
    case .thunderstorm:
      return "NewsHeroLightning"
    }
  }

  static func treatment(conditionCode: Int?, isDay: Bool) -> Treatment {
    .photography(assetName: stillName(conditionCode: conditionCode, isDay: isDay))
  }
}

/// Your News photography. Real source `https` images only — never keyword-match stock.
enum YourNewsPhotography {
  static func cardImageURL(for item: LocalBriefingItem) -> URL? {
    item.imageURL
  }

  /// Always nil. Titles like “tornado” must not pick `NewsHeroLightning`.
  static func bundledStockHeroName(matchingTitle title: String) -> String? {
    _ = title
    return nil
  }
}
