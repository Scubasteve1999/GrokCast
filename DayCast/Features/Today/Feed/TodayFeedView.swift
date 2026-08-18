import SwiftUI

/// TWC-style scrolling home feed. Permission / empty gates stay in `TodayView`.
struct TodayFeedView: View {
  @Environment(WeatherStore.self) private var store
  @Environment(SevereWeatherStore.self) private var severeStore
  @Environment(ShortTermPrecipStore.self) private var shortTermStore
  @Environment(FireStore.self) private var fireStore
  @Environment(GrokBriefSafety.self) private var briefSafety

  let weather: DayCastWeather
  var isGeneratingImage: Bool
  var generateImageAction: () -> Void

  @State private var selectedAlert: NWSAlert?
  @State private var showNowDetail = false
  @State private var showAirQualityDetail = false
  @State private var showSunMoonDetail = false
  @State private var showFireDetail = false

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
      showAIInsight: !briefSafety.isFeatureHidden
    )
    // Prefer live minutecast (HRRR when present) over the builder's Open-Meteo-only check.
    snap.hasPrecipContent = PrecipFeedVisibility.hasContent(summary: currentMinutecast)
    return snap
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
      shortTermStore.context.hasHRRRSlots
    else { return nil }
    return shortTermStore.context
  }

  private var currentMinutecast: MinutecastSummary {
    if let hrrr = hrrrContextForLocation {
      return hrrr.summary
        ?? MinutecastEngine.summary(from: hrrr.slots, units: store.temperatureUnit)
    }
    return MinutecastEngine.summary(from: weather.minutely15, units: store.temperatureUnit)
  }

  private var minutecastSourceLabel: String? {
    hrrrContextForLocation != nil ? "HRRR" : nil
  }

  private var minutecastDisagreementCaption: String? {
    guard let hrrr = hrrrContextForLocation else { return nil }
    let result = MinutecastAgreement.compare(
      hrrr: hrrr.slots,
      openMeteo: weather.minutely15,
      units: store.temperatureUnit
    )
    return MinutecastAgreement.caption(for: result)
  }

  private var todaySevereContext: SevereWeatherContext? {
    guard let locID = store.currentLocation?.id.uuidString,
      severeStore.context.locationID == locID,
      severeStore.context.shouldShowTodayCard
    else { return nil }
    return severeStore.context
  }

  var body: some View {
    ScrollView {
      LazyVStack(spacing: DesignTokens.Spacing.space16) {
        ForEach(feedItems) { item in
          feedCard(for: item)
            .padding(.horizontal, DesignTokens.Spacing.space20)
        }

        if let error = store.weatherError, !error.isEmpty {
          errorBanner(error)
            .padding(.horizontal, DesignTokens.Spacing.space20)
        }
      }
      .padding(.bottom, DesignTokens.Layout.tabBarScrollClearance)
      .adaptiveContainerWidth(AdaptiveLayout.contentCap)
    }
    .safeAreaInset(edge: .top, spacing: 0) {
      LocationChipBar()
        .padding(.top, DesignTokens.Spacing.space8)
        .padding(.bottom, DesignTokens.Spacing.space8)
        .frame(maxWidth: .infinity)
        .background(DesignTokens.Palette.bgPrimary)
    }
    .refreshable {
      await refreshAll()
    }
    .navigationDestination(item: $selectedAlert) { alert in
      AlertDetailView(alert: alert)
    }
    .navigationDestination(isPresented: $showNowDetail) {
      NowDetailView(
        weather: weather,
        score: currentScore,
        isGeneratingImage: isGeneratingImage,
        generateImageAction: generateImageAction
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
  private func feedCard(for item: FeedItem) -> some View {
    switch item {
    case .now:
      NowFeedCard(weather: weather, score: currentScore) {
        Analytics.track(.feedCardTap, parameters: ["card": item.analyticsName])
        showNowDetail = true
      }
    case .alerts:
      AlertsFeedCard(
        alerts: store.displayableActiveAlerts,
        severeContext: todaySevereContext
      ) { alert in
        Analytics.track(.feedCardTap, parameters: ["card": item.analyticsName])
        selectedAlert = alert
      }
    case .aiInsight:
      AIInsightFeedCard()
        .onTapGesture {
          Analytics.track(.feedCardTap, parameters: ["card": item.analyticsName])
        }
    case .hourly:
      HourlyFeedCard(weather: weather) {
        Analytics.track(.feedCardTap, parameters: ["card": item.analyticsName])
        store.selectedTab = .forecast
      }
    case .radar:
      RadarFeedCard()
        .onTapGesture {
          Analytics.track(.feedCardTap, parameters: ["card": item.analyticsName])
        }
    case .daily:
      DailyFeedCard(weather: weather)
    case .precip:
      PrecipFeedCard(
        summary: currentMinutecast,
        sourceLabel: minutecastSourceLabel,
        disagreementCaption: minutecastDisagreementCaption,
        timingSentence: PrecipFeedVisibility.timingSentence(for: currentMinutecast)
      ) {
        Analytics.track(.feedCardTap, parameters: ["card": item.analyticsName])
        store.selectedTab = .forecast
      }
    case .airQuality:
      if let aqi = weather.airQualityIndex {
        AirQualityFeedCard(aqi: aqi) {
          Analytics.track(.feedCardTap, parameters: ["card": item.analyticsName])
          showAirQualityDetail = true
        }
      }
    case .sunMoon:
      SunMoonFeedCard(
        sunrise: todaySunTimes.sunrise,
        sunset: todaySunTimes.sunset,
        timeZone: weather.locationTimeZone
      ) {
        Analytics.track(.feedCardTap, parameters: ["card": item.analyticsName])
        showSunMoonDetail = true
      }
    case .fire:
      if let fireSummary {
        FireFeedCard(summary: fireSummary) {
          Analytics.track(.feedCardTap, parameters: ["card": item.analyticsName])
          showFireDetail = true
        }
      } else if !fireWeatherAlerts.isEmpty {
        FireFeedCard(
          summary: FireFeedSummary(
            title: fireWeatherAlerts[0].event,
            subtitle: fireWeatherAlerts[0].headline
              ?? "Fire weather conditions for your area",
            distanceMiles: nil,
            hotspotCount: fireSummary?.hotspotCount ?? 0,
            incidentCount: fireSummary?.incidentCount ?? 0
          )
        ) {
          Analytics.track(.feedCardTap, parameters: ["card": item.analyticsName])
          showFireDetail = true
        }
      }
    }
  }

  private func errorBanner(_ error: String) -> some View {
    HStack(spacing: DesignTokens.Spacing.space8) {
      Image(systemName: store.isOffline ? "wifi.slash" : "exclamationmark.triangle.fill")
        .foregroundStyle(DesignTokens.Palette.danger)
      Text(error)
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.danger)
        .lineLimit(2)
      Spacer(minLength: DesignTokens.Spacing.space8)
      Button("Retry") {
        Haptic.impact(.medium)
        Task { await store.refreshWeather() }
      }
      .font(DesignTokens.Typography.caption())
      .buttonStyle(.bordered)
      .tint(DesignTokens.Palette.danger)
      .controlSize(.small)
    }
    .padding(DesignTokens.Spacing.space8)
    .background(DesignTokens.Palette.danger.opacity(0.15))
    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
  }

  private func refreshAll() async {
    await store.refreshWeather()
  }
}
