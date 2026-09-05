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

  static let radarUnavailable = RadarChromeCopy.unavailableTitle

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
    condition.isPrecipitating
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

/// Outlook plate product. Not Intensity. Future stays off if frames are missing.
enum OutlookRadarProduct: String, CaseIterable, Equatable {
  case radar
  case future

  static func resolved(
    requested: OutlookRadarProduct,
    futureFramesAvailable: Bool,
    canUseFuture: Bool = true
  ) -> OutlookRadarProduct {
    if requested == .future, futureFramesAvailable, canUseFuture { return .future }
    return .radar
  }
}

enum OutlookRadarCopy {
  static let title = "Outlook"
  static let radarPill = "Radar"
  static let futurePill = "Future"
  static let livePill = "LIVE"
  static let opensRadarTab = RadarFeedCopy.opensRadarTab

  static func accessibilityLabel(sentence: String, product: OutlookRadarProduct) -> String {
    let productName = product == .future ? futurePill : radarPill
    return "\(title). \(sentence). \(productName). \(opensRadarTab)"
  }
}

struct RadarFeedCard: View {
  @Environment(WeatherStore.self) private var store
  let weather: DayCastWeather
  var briefingItems: [LocalBriefingItem] = []
  var hoisted: Bool = false
  var isNowWet: Bool = false
  var isNextHourWet: Bool = false
  var officialWarningEvent: String? = nil
  var onTap: (() -> Void)? = nil

  @State private var nearestSite: IEMRadarService.Site?
  @State private var sweep: Level3N0BSweep?
  @State private var polarFailed = false
  @State private var requestedProduct: OutlookRadarProduct = .radar
  @State private var futureFramesAvailable = false

  private var paint: RadarPreviewPaint {
    RadarPreviewPaint.resolve(
      hoisted: hoisted,
      hasDrawableSweep: sweep != nil && !polarFailed,
      mapboxPresent: RadarPreviewSource.mapboxTokenPresent,
      mapsGLKeysPresent: MapsGLRadarHost.keysPresent
    )
  }

  private var canUseFuture: Bool {
    EntitlementChecker.canUseRadarFuture(subscription: SubscriptionManager.shared)
  }

  private var product: OutlookRadarProduct {
    OutlookRadarProduct.resolved(
      requested: requestedProduct,
      futureFramesAvailable: futureFramesAvailable,
      canUseFuture: canUseFuture
    )
  }

  private var outlook: TonightOutlook.Result {
    TonightOutlook.make(
      weather: weather,
      briefingItems: briefingItems,
      unit: store.temperatureUnit,
      isNowWet: isNowWet
        || RadarFeedCopy.isLocalWet(WeatherCondition(fromWMO: weather.conditionCode)),
      isNextHourWet: isNextHourWet,
      officialWarningEvent: officialWarningEvent
    )
  }

  var body: some View {
    card
      .task(id: loadKey) {
        await loadSiteSweepIfNeeded()
      }
      .task {
        futureFramesAvailable = await RadarLoader().probeForecastFramesAvailable()
        fallBackToRadarIfFutureLocked()
      }
      .onChange(of: canUseFuture) { _, _ in
        fallBackToRadarIfFutureLocked()
      }
  }

  private var loadKey: String {
    let loc = store.currentLocation
    return "\(hoisted)-\(loc?.latitude ?? 0)-\(loc?.longitude ?? 0)"
  }

  private var card: some View {
    VStack(alignment: .leading, spacing: TodayGlanceLayout.radarInnerSpacing) {
      header
      plate
    }
    .accessibilityElement(children: .contain)
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.space8) {
      Text(OutlookRadarCopy.title)
        .font(DesignTokens.Typography.subsection())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
      Text(outlook.plateSentence)
        .font(DesignTokens.Typography.callout())
        .foregroundStyle(DesignTokens.Palette.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
    .frame(maxWidth: .infinity, minHeight: TodayGlanceLayout.radarHeaderHeight, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(OutlookRadarCopy.title). \(outlook.plateSentence)")
  }

  private var plate: some View {
    ZStack(alignment: .bottom) {
      map
        .allowsHitTesting(false)
        .contentShape(Rectangle())
        .onTapGesture { openRadarTab() }

      VStack(alignment: .leading, spacing: 0) {
        HStack {
          if product == .radar, paint != .unavailable {
            liveStamp
          }
          Spacer(minLength: 0)
        }
        .padding(DesignTokens.Spacing.space8)
        Spacer(minLength: 0)
        pills
          .padding(DesignTokens.Spacing.space8)
      }
    }
  }

  @ViewBuilder
  private var map: some View {
    let shown = product == .future ? RadarPreviewPaint.nationalMapsGL : paint
    mapPaint(shown)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        OutlookRadarCopy.accessibilityLabel(
          sentence: outlook.plateSentence, product: product)
      )
      .accessibilityAddTraits(.isButton)
  }

  @ViewBuilder
  private func mapPaint(_ shown: RadarPreviewPaint) -> some View {
    switch shown {
    case .siteDoppler:
      RadarPreviewCard(
        paint: .siteDoppler,
        sweep: sweep,
        height: RadarPreviewSource.outlookPlateHeight,
        onPolarFailed: { polarFailed = true }
      )
    case .nationalMapsGL:
      RadarPreviewCard(
        paint: .nationalMapsGL,
        height: RadarPreviewSource.outlookPlateHeight,
        showsFuture: product == .future
      )
    case .unavailable:
      RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadius)
        .fill(DesignTokens.Palette.radarTrack)
        .frame(height: RadarPreviewSource.outlookPlateHeight)
        .overlay {
          Text(RadarFeedCopy.radarUnavailable)
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture { openRadarTab() }
    }
  }

  private var liveStamp: some View {
    Text(OutlookRadarCopy.livePill)
      .font(DesignTokens.Typography.micro().weight(.semibold))
      .foregroundStyle(DesignTokens.Palette.radarTextPrimary)
      .padding(.horizontal, DesignTokens.Spacing.space8)
      .padding(.vertical, DesignTokens.Spacing.space2)
      .background(DesignTokens.Palette.radarTrack, in: Capsule())
      .accessibilityHidden(true)
  }

  private var pills: some View {
    HStack(spacing: DesignTokens.Spacing.space8) {
      productPill(.radar, title: OutlookRadarCopy.radarPill)
      if canUseFuture {
        productPill(.future, title: OutlookRadarCopy.futurePill)
      }
    }
  }

  private func productPill(_ value: OutlookRadarProduct, title: String) -> some View {
    let selected = product == value
    return Button {
      selectProduct(value)
    } label: {
      Text(title)
        .font(DesignTokens.Typography.caption())
        .fontWeight(selected ? .semibold : .regular)
        .foregroundStyle(
          selected
            ? DesignTokens.Palette.radarTextPrimary
            : DesignTokens.Palette.radarTextSecondary
        )
        .frame(maxWidth: .infinity, minHeight: 28)
        .background(
          Capsule().fill(
            selected
              ? DesignTokens.Palette.radarTrack
              : Color.clear
          )
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private func selectProduct(_ value: OutlookRadarProduct) {
    Haptic.impact(.light)
    if value == .future {
      if !futureFramesAvailable {
        requestedProduct = .radar
        return
      }
      if !canUseFuture {
        PaywallCoordinator.shared.present(.radarFuture)
        requestedProduct = .radar
        return
      }
    }
    requestedProduct = value
  }

  private func fallBackToRadarIfFutureLocked() {
    if requestedProduct == .future,
      !futureFramesAvailable || !canUseFuture
    {
      requestedProduct = .radar
    }
  }

  private func openRadarTab() {
    Haptic.impact(.medium)
    onTap?()
    store.pendingRadarShowsFuture = product == .future
    store.selectedTab = .radar
  }

  private func loadSiteSweepIfNeeded() async {
    guard hoisted else { return }
    nearestSite = nil
    sweep = nil
    polarFailed = false
    guard let loc = store.currentLocation else { return }
    let coord = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
    let site = await IEMRadarService.nearestSite(to: coord)
    nearestSite = site
    guard let site else { return }
    sweep = await Level3N0BService.loadNewestSweep(for: site)
  }

  static func accessibilityLabel(conditionCode: Int) -> String {
    RadarFeedCopy.accessibilityLabel(conditionCode: conditionCode)
  }
}
