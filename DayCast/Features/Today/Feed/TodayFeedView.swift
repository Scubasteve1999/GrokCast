import SwiftUI

/// TWC-style scrolling home feed. Permission / empty gates stay in `TodayView`.
struct TodayFeedView: View {
  @Environment(WeatherStore.self) private var store
  @Environment(SevereWeatherStore.self) private var severeStore
  @Environment(ShortTermPrecipStore.self) private var shortTermStore
  @Environment(FireStore.self) private var fireStore
  @Environment(LocalBriefingStore.self) private var briefingStore

  let weather: DayCastWeather

  @State private var selectedAlert: NWSAlert?
  @State private var showNowDetail = false
  @State private var showAirQualityDetail = false
  @State private var showSunMoonDetail = false
  @State private var showFireDetail = false
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
      showFireCard: showFire,
      showAIInsight: false,
      hasSevereContext: todaySevereContext != nil
    )
    // Prefer live minutecast (HRRR when present) over the builder's Open-Meteo-only check.
    snap.hasPrecipContent = PrecipFeedVisibility.hasContent(summary: currentMinutecast)
    snap.hasNextEvent = PrecipFeedVisibility.showsCard(summary: currentMinutecast)
    snap.isNowWet = NowHeroReconcile.isNowWet(
      conditionCode: weather.conditionCode, summary: currentMinutecast)
    snap.hasLocalBriefing = hasBriefingForCurrentLocation
    return snap
  }

  private var hasBriefingForCurrentLocation: Bool {
    guard let locID = store.currentLocation?.id.uuidString else { return false }
    return briefingStore.locationID == locID && !briefingStore.items.isEmpty
  }

  private var todaySunTimes: (sunrise: Date?, sunset: Date?) {
    let day = weather.daily.first
    return (day?.sunrise, day?.sunset)
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

  private var feedRows: [TodayFeedRow] {
    FeedAssembler.rows(items: feedItems, weatherError: store.weatherError)
  }

  private var currentMinutecast: MinutecastSummary {
    if let hrrr = hrrrContextForLocation {
      return hrrr.summary
        ?? MinutecastEngine.summary(from: hrrr.slots, units: store.temperatureUnit)
    }
    return MinutecastEngine.summary(from: weather.minutely15, units: store.temperatureUnit)
  }

  private var todaySevereContext: SevereWeatherContext? {
    guard let locID = store.currentLocation?.id.uuidString,
      severeStore.context.locationID == locID,
      severeStore.context.shouldShowTodayCard
    else { return nil }
    return severeStore.context
  }

  private var officialWarningEvent: String? {
    store.displayableGroupedAlerts.first(where: { $0.isWarning && !$0.isExpired })?.event
  }

  private var heroRows: [TodayFeedRow] {
    feedRows.filter { row in
      switch row {
      case .errorBanner, .item(.now), .item(.alerts): return true
      default: return false
      }
    }
  }

  private var sheetRows: [TodayFeedRow] {
    feedRows.filter { row in
      switch row {
      case .errorBanner, .item(.now), .item(.alerts): return false
      default: return true
      }
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
              case .item(let item):
                feedCard(for: item, plated: false)
              }
            }
          }
          .padding(.horizontal, DesignTokens.Spacing.space20)
          .padding(.top, chipBarHeight)
          .padding(.bottom, DesignTokens.Spacing.space16)

          if !sheetRows.isEmpty {
            VStack(spacing: TodayGlanceLayout.sheetSectionSpacing) {
              ForEach(sheetRows) { row in
                if case .item(let item) = row {
                  feedCard(for: item, plated: false)
                }
              }
            }
            .padding(.horizontal, DesignTokens.Spacing.space20)
            .padding(.top, DesignTokens.Spacing.space20)
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
    .navigationDestination(isPresented: $showSunMoonDetail) {
      SunMoonDetailView(
        sunrise: todaySunTimes.sunrise,
        sunset: todaySunTimes.sunset,
        timeZone: weather.locationTimeZone
      )
    }
    .navigationDestination(isPresented: $showFireDetail) {
      FireDetailView(
        snapshot: fireStore.snapshot,
        origin: store.currentLocation?.coordinate,
        fireWeatherAlerts: fireWeatherAlerts,
        radiusMiles: store.fireProximityRadiusMiles
      )
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
        sitsOnPhoto: true
      ) { alert in
        Analytics.track(.feedCardTap, parameters: ["card": item.analyticsName])
        selectedAlert = alert
      }
    case .decision, .precip:
      EmptyView()
    case .aiInsight:
      EmptyView()
    case .hourly:
      HourlyFeedCard(
        weather: weather,
        plated: plated
      ) {
        Analytics.track(.feedCardTap, parameters: ["card": item.analyticsName])
        store.selectedTab = .forecast
      }
    case .yourNews:
      YourNewsFeedCard(items: briefingStore.items, sitsInSheet: !plated)
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
        plated: plated,
        onAirQuality: weather.airQualityIndex == nil
          ? nil
          : {
            Analytics.track(.feedCardTap, parameters: ["card": "airQuality"])
            showAirQualityDetail = true
          }
      )
    case .nearby:
      NearbyFeedCard(
        aqi: nil,
        hasNWSAirQualityAlert: false,
        fire: nearbyFireSummary,
        sunrise: todaySunTimes.sunrise,
        sunset: todaySunTimes.sunset,
        timeZone: weather.locationTimeZone,
        onAirQuality: nil,
        onFire: nearbyFireSummary == nil
          ? nil
          : {
            Analytics.track(.feedCardTap, parameters: ["card": "fire"])
            showFireDetail = true
          },
        onSunMoon: (todaySunTimes.sunrise == nil && todaySunTimes.sunset == nil)
          ? nil
          : {
            Analytics.track(.feedCardTap, parameters: ["card": "sunMoon"])
            showSunMoonDetail = true
          },
        plated: plated
      )
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

  private func refreshAll() async {
    await store.refreshWeather()
  }
}
