import SwiftUI

/// One-glance Today teaser. Product half always matches the National
/// preview (`National radar`). Never Site Doppler. Never mosaic.
/// Never “Radar. Opens the Radar tab.” Live-open policy for the Radar
/// tab is unchanged.
enum RadarFeedCopy {
  static let opensRadarTab = "Opens the Radar tab."

  static func title(conditionCode: Int, siteID: String? = nil) -> String {
    let condition = WeatherCondition(fromWMO: conditionCode)
    let product = RadarProduct.reflectivity.displayName
    if isLocalWet(condition) {
      return "\(precipWord(for: condition)) now · \(product)"
    }
    return "\(RadarLiveOpenPolicy.clearHint(siteID: siteID)) · \(product)"
  }

  static func accessibilityLabel(conditionCode: Int, siteID: String? = nil) -> String {
    accessibilityLabel(title: title(conditionCode: conditionCode, siteID: siteID))
  }

  static func accessibilityLabel(title: String) -> String {
    let spoken = title.replacingOccurrences(of: " · ", with: ". ")
    return "\(spoken). \(opensRadarTab)"
  }

  static func isLocalWet(_ condition: WeatherCondition) -> Bool {
    switch condition {
    case .drizzle, .rain, .sleet, .snow, .snowGrains, .rainShowers, .snowShowers,
      .thunderstorm:
      return true
    case .clear, .mainlyClear, .overcast, .fog, .unknown:
      return false
    }
  }

  static func precipWord(for condition: WeatherCondition) -> String {
    switch condition {
    case .thunderstorm: return "Storm"
    case .sleet: return "Sleet"
    case .snow, .snowGrains, .snowShowers: return "Snow"
    default: return "Rain"
    }
  }
}

struct RadarFeedCard: View {
  @Environment(WeatherStore.self) private var store
  let weather: DayCastWeather
  var onTap: (() -> Void)? = nil

  private var teaser: String {
    RadarFeedCopy.title(conditionCode: weather.conditionCode)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      HStack {
        Text(teaser)
          .font(DesignTokens.Typography.subsection())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.85)
        Spacer(minLength: DesignTokens.Spacing.space8)
        Image(systemName: "chevron.right")
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }

      RadarPreviewCard()
        .allowsHitTesting(false)
    }
    .padding(DesignTokens.Spacing.space16)
    .cardStyle()
    .contentShape(Rectangle())
    .onTapGesture {
      Haptic.impact(.medium)
      onTap?()
      store.selectedTab = .radar
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.accessibilityLabel(conditionCode: weather.conditionCode))
    .accessibilityAddTraits(.isButton)
  }

  static func accessibilityLabel(conditionCode: Int) -> String {
    RadarFeedCopy.accessibilityLabel(conditionCode: conditionCode)
  }
}
