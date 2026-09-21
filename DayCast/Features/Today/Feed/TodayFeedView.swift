import SwiftUI

/// TWC-style scrolling home feed. Permission / empty gates stay in `TodayView`.
struct TodayFeedView: View {
  @Environment(WeatherStore.self) private var store
  @Environment(ShortTermPrecipStore.self) private var shortTermStore
  @Environment(FireStore.self) private var fireStore
  @Environment(LocalBriefingStore.self) private var briefingStore
  @Environment(EnsembleAgreementStore.self) private var ensembleStore
  @Environment(RefsAgreementStore.self) private var refsStore

  let weather: DayCastWeather

  @State private var selectedAlert: NWSAlert?
  @State private var showNowDetail = false
  @State private var showAirQualityDetail = false
  @State private var showFireDetail = false
  @State private var showForecastEraNotice = false
  @AppStorage(ForecastEraNotice.dismissedIdKey) private var forecastEraDismissedId = ""
  @AppStorage(ForecastEraNotice.forceShowKey) private var forceForecastEraNotice = false
  @AppStorage(RefsAgreementConfiguration.forceKey) private var forceRefsAgreement = false
  @State private var chipBarHeight: CGFloat = LocationChipBar.reservedHeight

  private var fireWeatherAlerts: [NWSAlert] {
    store.displayableActiveAlerts.filter(FireFeedVisibility.isFireWeatherAlert)
  }

  private var fireSummary: FireFeedSummary? {
    FireFeedVisibility.summary(
      snapshot: fireStore.snapshot,
      origin: store.currentLocation?.coordinate,
      radiusMiles: store.fireProximityRadiusMiles
    )
  }

  private var nearbyFireSummary: FireFeedSummary? {
    if let fireSummary { return fireSummary }
    guard let alert = fireWeatherAlerts.first else { return nil }
    return FireFeedSummary(
      title: alert.event,
      subtitle: alert.headline ?? "Fire weather conditions for your area",
      distanceMiles: nil,
      hotspotCount: 0,
      incidentCount: 0
    )
  }

  private var snapshot: FeedSnapshot {
    let showFire = FireFeedVisibility.shouldShowCard(
      snapshot: fireStore.snapshot,
      origin: store.currentLocation?.coordinate,
      alerts: store.displayableActiveAlerts,
      radiusMiles: store.fireProximityRadiusMiles
    )
    var snap = FeedSnapshotBuilder.make(
      weather: weather,
      alerts: store.displayableActiveAlerts,
      showFireCard: showFire
    )
    // Prefer live minutecast (HRRR when present) over the builder's Open-Meteo-only check.
    snap.hasPrecipContent = PrecipFeedVisibility.hasContent(summary: currentMinutecast)
    snap.isNowWet = NowHeroReconcile.isNowWet(
      conditionCode: weather.conditionCode, summary: currentMinutecast)
    snap.hasLocalBriefing = hasBriefingForCurrentLocation
    snap.isLocalBriefingPending = LocalBriefingSlot.isPending(
      currentLocationID: store.currentLocation?.id.uuidString,
      storeLocationID: briefingStore.locationID,
      itemCount: briefingStore.items.count,
      isRefreshing: briefingStore.isRefreshing
    )
    return snap
  }

  private var hasBriefingForCurrentLocation: Bool {
    guard let locID = store.currentLocation?.id.uuidString else { return false }
    return briefingStore.locationID == locID && !briefingStore.items.isEmpty
  }

  private var feedItems: [FeedItem] {
    FeedAssembler.items(from: snapshot)
  }

  private var currentScore: DayCastScore {
    DayCastScoreCalculator.score(
      for: weather, alerts: store.displayableActiveAlerts, units: store.temperatureUnit)
  }

  private var hrrrContextForLocation: ShortTermPrecipContext? {
    guard let locID = store.currentLocation?.id.uuidString,
      shortTermStore.context.locationID == locID,
      shortTermStore.context.isUsableHRRR()
    else { return nil }
    return shortTermStore.context
  }

  private var honestyContent: HonestyStripCopy.Content? {
    guard let office = briefingStore.officeOfRecord(for: store.currentLocation?.id.uuidString)
    else { return nil }
    let ensemble = EnsembleAgreement.evaluate(
      snapshot: ensembleStore.snapshot(for: store.currentLocation?.id.uuidString),
      hours: weather.hourly
    )
    return HonestyStripCopy.content(
      officeName: office.officeName,
      cwa: office.cwa,
      alerts: store.displayableGroupedAlerts,
      briefingItems: hasBriefingForCurrentLocation ? briefingStore.items : [],
      ensemble: ensemble,
      timeZone: weather.locationTimeZone
    )
  }

  private var showsStandaloneHonestyStrip: Bool {
    HonestyStripCopy.showsStandaloneStrip(
      hasWFO: honestyContent != nil,
      showAlertsSlot: snapshot.showAlertsSlot
    )
  }

  private var showsForecastEraNotice: Bool {
    _ = forecastEraDismissedId
    _ = forceForecastEraNotice
    return ForecastEraNotice.shouldShowBanner()
  }

  private var refsPayload: RefsAgreementPayload? {
    _ = forceRefsAgreement
    return refsStore.payload(for: store.currentLocation?.id.uuidString)
  }

  private var feedRows: [TodayFeedRow] {
    FeedAssembler.rows(
      items: feedItems,
      weatherError: store.weatherError,
      showsStandaloneHonestyStrip: showsStandaloneHonestyStrip,
      showsForecastEraNotice: showsForecastEraNotice,
      showsRefsAgreement: refsPayload != nil
    )
  }

  private var currentMinutecast: MinutecastSummary {
    if let hrrr = hrrrContextForLocation {
      return hrrr.summary
        ?? MinutecastEngine.summary(from: hrrr.slots, units: store.temperatureUnit)
    }
    return MinutecastEngine.summary(from: weather.minutely15, units: store.temperatureUnit)
  }

  private var officialWarningEvent: String? {
    store.displayableGroupedAlerts.first(where: { $0.isWarning && !$0.isExpired })?.event
  }

  private var heroRows: [TodayFeedRow] {
    var rows: [TodayFeedRow] = []
    for row in feedRows {
      guard isHeroChrome(row) else { break }
      rows.append(row)
    }
    return rows
  }

  private var sheetRows: [TodayFeedRow] {
    Array(feedRows.dropFirst(heroRows.count))
  }

  /// Photo-stage chrome, including a calm-day forecast-era caption after the WFO strip.
  /// A notice placed after Your News is not hero — the prefix walk stops at hourly.
  private func isHeroChrome(_ row: TodayFeedRow) -> Bool {
    switch row {
    case .errorBanner, .honestyStrip, .forecastEraNotice, .item(.now), .item(.alerts):
      return true
    default:
      return false
    }
  }

  var body: some View {
    ZStack(alignment: .top) {
      ScrollView {
        VStack(spacing: 0) {
          VStack(spacing: TodayGlanceLayout.feedSpacing) {
            ForEach(heroRows) { row in
              switch row {
              case .errorBanner:
                if let error = store.weatherError, !error.isEmpty {
                  errorBanner(error)
                }
              case .honestyStrip:
                if let honestyContent {
                  HonestyStrip(content: honestyContent, sitsOnPhoto: true)
                }
              case .forecastEraNotice:
                forecastEraNoticeBanner(sitsOnPhoto: true)
              case .refsAgreement:
                if let refsPayload {
                  RefsAgreementChip(payload: refsPayload, timeZone: weather.locationTimeZone)
                }
              case .item(let item):
                feedCard(for: item, plated: false)
              }
            }
          }
          .padding(.horizontal, DesignTokens.Spacing.space20)
          .padding(.top, chipBarHeight)
          .padding(.bottom, TodayGlanceLayout.heroBottomPadding)

          if !sheetRows.isEmpty {
            VStack(spacing: TodayGlanceLayout.sheetSectionSpacing) {
              ForEach(sheetRows) { row in
                switch row {
                case .forecastEraNotice:
                  forecastEraNoticeBanner(sitsOnPhoto: false)
                case .refsAgreement:
                  if let refsPayload {
                    RefsAgreementChip(payload: refsPayload, timeZone: weather.locationTimeZone)
                  }
                case .item(let item):
                  feedCard(for: item, plated: false)
                default:
                  EmptyView()
                }
              }
            }
            .padding(.horizontal, DesignTokens.Spacing.space20)
            .padding(.top, TodayGlanceLayout.sheetTopPadding)
            .padding(.bottom, DesignTokens.Layout.tabBarScrollClearance)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Palette.bgSecondary)
            .clipShape(
              UnevenRoundedRectangle(
                topLeadingRadius: TodayGlanceLayout.sheetTopRadius,
                topTrailingRadius: TodayGlanceLayout.sheetTopRadius,
                style: .continuous
              )
            )
          }
        }
        .adaptiveContainerWidth(AdaptiveLayout.contentCap)
      }

      LocationChipBar()
        .zIndex(1)
        .background {
          GeometryReader { proxy in
            Color.clear
              .preference(key: ChipBarHeightKey.self, value: proxy.size.height)
              .allowsHitTesting(false)
          }
        }
    }
    .onPreferenceChange(ChipBarHeightKey.self) { chipBarHeight = $0 }
    .refreshable {
      await refreshAll()
    }
    .task(id: refsRefreshKey) {
      await refreshRefsAgreement(force: false)
    }
    .navigationDestination(item: $selectedAlert) { alert in
      AlertDetailView(alert: alert)
    }
    .navigationDestination(isPresented: $showNowDetail) {
      NowDetailView(
        weather: weather,
        score: currentScore
      )
    }
    .navigationDestination(isPresented: $showAirQualityDetail) {
      if let aqi = weather.airQualityIndex {
        AirQualityDetailView(aqi: aqi)
      }
    }
    .navigationDestination(isPresented: $showFireDetail) {
      FireDetailView(
        snapshot: fireStore.snapshot,
        origin: store.currentLocation?.coordinate,
        fireWeatherAlerts: fireWeatherAlerts,
        radiusMiles: store.fireProximityRadiusMiles
      )
    }
    .sheet(isPresented: $showForecastEraNotice) {
      ForecastEraNoticeCard()
    }
  }

  @ViewBuilder
  private func feedCard(for item: FeedItem, plated: Bool) -> some View {
    switch item {
    case .now:
      NowFeedCard(
        weather: weather,
        rainLine: PrecipOutlookCopy.heroLine(
          summary: currentMinutecast,
          rainChance: weather.precipitationChance
        ),
        face: NowHeroReconcile.face(
          conditionCode: weather.conditionCode,
          conditionText: weather.conditionText,
          symbolName: weather.symbolName,
          summary: currentMinutecast
        )
      ) {
        Analytics.track(.feedCardTap, parameters: ["card": item.analyticsName])
        showNowDetail = true
      }
    case .alerts:
      AlertsFeedCard(
        alerts: store.displayableGroupedAlerts,
        sitsOnPhoto: true,
        honesty: honestyContent
      ) { alert in
        Analytics.track(.feedCardTap, parameters: ["card": item.analyticsName])
        selectedAlert = alert
      }
    case .hourly:
      HourlyFeedCard(
        weather: weather,
        plated: plated
      ) {
        Analytics.track(.feedCardTap, parameters: ["card": item.analyticsName])
        store.selectedTab = .forecast
      }
    case .yourNews:
      YourNewsFeedCard(
        items: hasBriefingForCurrentLocation ? briefingStore.items : [],
        sitsInSheet: !plated,
        isPending: snapshot.isLocalBriefingPending
      )
    case .radar:
      RadarFeedCard(
        weather: weather,
        briefingItems: briefingStore.items,
        hoisted: FeedAssembler.isRadarStory(snapshot),
        plated: plated,
        isNowWet: snapshot.isNowWet,
        isNextHourWet: snapshot.hasPrecipContent,
        officialWarningEvent: officialWarningEvent
      ) {
        Analytics.track(.feedCardTap, parameters: ["card": item.analyticsName])
      }
    case .daily:
      DailyFeedCard(weather: weather, plated: plated)
    case .health:
      HealthFeedCard(
        weather: weather,
        hasNWSAirQualityAlert: store.displayableActiveAlerts.contains {
          NearbyTileCopy.isAirQualityAlert($0.event)
        },
        showsPrecipTile: ConditionsVisibility.showsPrecipTile(isNowWet: snapshot.isNowWet),
        plated: plated,
        onAirQuality: weather.airQualityIndex == nil
          ? nil
          : {
            Analytics.track(.feedCardTap, parameters: ["card": "airQuality"])
            showAirQualityDetail = true
          }
      )
    case .nearby:
      if let fire = nearbyFireSummary {
        NearbyFeedCard(
          fire: fire,
          onFire: {
            Analytics.track(.feedCardTap, parameters: ["card": "fire"])
            showFireDetail = true
          },
          plated: plated
        )
      }
    }
  }

  private func forecastEraNoticeBanner(sitsOnPhoto: Bool) -> some View {
    ForecastEraNoticeBanner(sitsOnPhoto: sitsOnPhoto) {
      showForecastEraNotice = true
    } onDismiss: {
      ForecastEraNotice.dismiss()
      forecastEraDismissedId = ForecastEraNotice.id
    }
  }

  private func errorBanner(_ error: String) -> some View {
    TodayMessageBanner(
      message: error,
      isOffline: store.isOffline,
      tone: store.isShowingDefaultLocationFallback ? .warning : .danger,
      actionTitle: store.isShowingDefaultLocationFallback
        ? TodayCopy.useMyPosition : "Retry"
    ) {
      Haptic.impact(.medium)
      Task {
        if store.isShowingDefaultLocationFallback {
          await store.useCurrentDeviceLocation()
        } else {
          await store.refreshWeather()
        }
      }
    }
    .accessibilityIdentifier(DayCastAccessibility.Today.errorBanner)
  }

  private var refsRefreshKey: String {
    let location = store.currentLocation?.id.uuidString ?? ""
    let zone = weather.timezoneIdentifier ?? ""
    return "\(location)|\(zone)|\(forceRefsAgreement)"
  }

  private func refreshRefsAgreement(force: Bool) async {
    guard let location = store.currentLocation else { return }
    await refsStore.refresh(
      for: location,
      timeZone: weather.locationTimeZone,
      force: force
    )
  }

  private func refreshAll() async {
    await store.refreshWeather()
    await refreshRefsAgreement(force: true)
  }
}
