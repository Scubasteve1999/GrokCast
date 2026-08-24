import CoreLocation
import SwiftUI

/// One-glance Today teaser.
/// Buried (calm): product half is National radar. Never Site Doppler.
/// Hoisted (wet / warned / next-hour): named WSR-88D + Site Doppler + SCAN age.
/// Never mosaic. Never “Radar. Opens the Radar tab.”
enum RadarFeedCopy {
  static let opensRadarTab = "Opens the Radar tab."
  static let siteProductName = RadarProduct.superResReflectivity.displayName
  static let scanUnavailable = "scan unavailable"

  static func title(conditionCode: Int, siteID: String? = nil) -> String {
    let condition = WeatherCondition(fromWMO: conditionCode)
    let product = RadarProduct.reflectivity.displayName
    if isLocalWet(condition) {
      return "\(precipWord(for: condition)) now · \(product)"
    }
    return "\(RadarLiveOpenPolicy.clearHint(siteID: siteID)) · \(product)"
  }

  static func siteTitle(
    conditionCode: Int,
    siteID: String?,
    ageLine: String
  ) -> String {
    let condition = WeatherCondition(fromWMO: conditionCode)
    if isLocalWet(condition) {
      return "\(precipWord(for: condition)) now · \(displaySiteID(siteID))"
    }
    if let siteID, !siteID.isEmpty {
      return "\(siteID) is clear · \(ageLine)"
    }
    return "\(RadarLiveOpenPolicy.clearHint(siteID: siteID)) · \(ageLine)"
  }

  static func displaySiteID(_ siteID: String?) -> String {
    if let siteID, !siteID.isEmpty { return siteID }
    return siteProductName
  }

  static func failLine(siteID: String?) -> String {
    if let siteID, !siteID.isEmpty {
      return "\(siteID) · \(scanUnavailable)"
    }
    return "\(siteProductName) · \(scanUnavailable)"
  }

  static func scanAgeLine(scanDate: Date?, now: Date) -> String {
    let minutes = ChaseRadarHUDLogic.scanAgeMinutes(now: now, scanDate: scanDate)
    return ChaseRadarHUDLogic.scanAgeLine(
      showsFuture: false,
      futureFrameLabel: "",
      ageMinutes: minutes
    )
  }

  static func accessibilityLabel(conditionCode: Int, siteID: String? = nil) -> String {
    accessibilityLabel(title: title(conditionCode: conditionCode, siteID: siteID))
  }

  static func siteAccessibilityLabel(
    conditionCode: Int,
    siteID: String?,
    ageLine: String
  ) -> String {
    let title = siteTitle(
      conditionCode: conditionCode, siteID: siteID, ageLine: ageLine)
    let spoken = title.replacingOccurrences(of: " · ", with: ". ")
    let condition = WeatherCondition(fromWMO: conditionCode)
    if isLocalWet(condition) {
      return "\(spoken). \(siteProductName). \(ageLine). \(opensRadarTab)"
    }
    return "\(spoken). \(siteProductName). \(opensRadarTab)"
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
  var hoisted: Bool = false
  var onTap: (() -> Void)? = nil

  @State private var nearestSite: IEMRadarService.Site?
  @State private var sweep: Level3N0BSweep?
  @State private var loadFinished = false
  @State private var polarFailed = false

  private var isNowWet: Bool {
    RadarFeedCopy.isLocalWet(WeatherCondition(fromWMO: weather.conditionCode))
  }

  private var paint: RadarPreviewPaint {
    RadarPreviewPaint.resolve(
      hoisted: hoisted,
      hasDrawableSweep: sweep != nil && !polarFailed,
      mapboxPresent: RadarPreviewSource.mapboxTokenPresent,
      mapsGLKeysPresent: MapsGLRadarHost.keysPresent
    )
  }

  var body: some View {
    TimelineView(.everyMinute) { context in
      let ageLine = RadarFeedCopy.scanAgeLine(
        scanDate: sweep?.timestamp, now: context.date)
      card(ageLine: ageLine)
    }
    .task(id: loadKey) {
      await loadSiteSweepIfNeeded()
    }
  }

  private var loadKey: String {
    let loc = store.currentLocation
    return "\(hoisted)-\(loc?.latitude ?? 0)-\(loc?.longitude ?? 0)"
  }

  @ViewBuilder
  private func card(ageLine: String) -> some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      header(ageLine: ageLine)

      switch paint {
      case .siteDoppler:
        RadarPreviewCard(
          paint: .siteDoppler,
          sweep: sweep,
          onPolarFailed: { polarFailed = true }
        )
        .allowsHitTesting(false)
      case .nationalMapsGL:
        RadarPreviewCard(paint: .nationalMapsGL)
          .allowsHitTesting(false)
      case .unavailable:
        if hoisted, loadFinished || polarFailed {
          Text(RadarFeedCopy.failLine(siteID: nearestSite?.id))
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
      }
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
    .accessibilityLabel(voiceOverLabel(ageLine: ageLine))
    .accessibilityAddTraits(.isButton)
  }

  private func header(ageLine: String) -> some View {
    HStack(alignment: .top, spacing: DesignTokens.Spacing.space8) {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
        Text(headline(ageLine: ageLine))
          .font(DesignTokens.Typography.subsection())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.85)
        if hoisted {
          Text(RadarFeedCopy.siteProductName)
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
      }
      Spacer(minLength: DesignTokens.Spacing.space8)
      if hoisted, isNowWet {
        Text(ageLine)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
          .monospacedDigit()
      }
      Image(systemName: "chevron.right")
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .padding(.top, 2)
    }
  }

  private func headline(ageLine: String) -> String {
    if hoisted {
      return RadarFeedCopy.siteTitle(
        conditionCode: weather.conditionCode,
        siteID: nearestSite?.id,
        ageLine: ageLine
      )
    }
    return RadarFeedCopy.title(conditionCode: weather.conditionCode)
  }

  private func voiceOverLabel(ageLine: String) -> String {
    if hoisted {
      return RadarFeedCopy.siteAccessibilityLabel(
        conditionCode: weather.conditionCode,
        siteID: nearestSite?.id,
        ageLine: ageLine
      )
    }
    return Self.accessibilityLabel(conditionCode: weather.conditionCode)
  }

  private func loadSiteSweepIfNeeded() async {
    guard hoisted else { return }
    nearestSite = nil
    sweep = nil
    polarFailed = false
    loadFinished = false
    guard let loc = store.currentLocation else {
      loadFinished = true
      return
    }
    let coord = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
    let site = await IEMRadarService.nearestSite(to: coord)
    nearestSite = site
    guard let site else {
      loadFinished = true
      return
    }
    sweep = await Level3N0BService.loadNewestSweep(for: site)
    loadFinished = true
  }

  static func accessibilityLabel(conditionCode: Int) -> String {
    RadarFeedCopy.accessibilityLabel(conditionCode: conditionCode)
  }
}
