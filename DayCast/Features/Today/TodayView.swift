import SwiftUI

private let bottomTabClearance = DesignTokens.Layout.tabBarScrollClearance
private let todayContentTopPadding = DesignTokens.Spacing.space16

enum TodayCopy {
  static let welcomeTitle = "Welcome to DayCast"
  static let welcomeBody =
    "Local Now for your city, official alerts, and the next 2 hours of rain you can believe."
  static let gettingLocation = "Getting your location…"
  static let emptyTitle = "Getting your city"
  static let emptyBody =
    "Tap Use my position for local Now and alerts, or pick a saved city. This is not GPS yet."

  static let getStarted = "Get Started"
  static let continuePermission = "Continue"
  static let enableLocation = "Enable location"
  static let openSettings = "Open Settings"
  static let useMyPosition = "Use my position"

  static let permissionTitle = "Use your location"
  static let permissionBody =
    "DayCast uses your location to show local Now, official alerts, and the next 2 hours of rain."
  static let permissionPrivacy =
    "Your location is only used for weather — we don’t track or store it."

  static let deniedTitle = "Location is off"
  static let deniedBody =
    "Location access was denied. Enable it in Settings to use your current position for Now and alerts."
  static let restrictedTitle = "Location is restricted"
  static let restrictedBody =
    "Location access is restricted on this device. Check Settings > Screen Time or parental controls."

  static let trustNow = "Now"
  static let trustAlerts = "Alerts"
  static let trustNextHour = PrecipOutlookCopy.title
}

/// Storm-first skeleton slots — must match the glance cards, not the old tactical grid.
enum TodaySkeletonSlot: String, CaseIterable {
  case now
  case hourly

  var feedItem: FeedItem {
    switch self {
    case .now: .now
    case .hourly: .hourly
    }
  }

  static var feedOrder: [TodaySkeletonSlot] { [.now, .hourly] }
}

struct TodayView: View {
  @Environment(WeatherStore.self) private var store

  var weather: DayCastWeather? { store.displayedWeather }
  var locationName: String { store.currentLocation?.name ?? "—" }

  /// Controls the one-time pre-permission explanation sheet shown on first launch
  /// (from the Get Started button in the welcome card). "Continue" in the sheet
  /// calls requestLocationPermission() (triggering the iOS prompt) and marks the flow complete.
  @State private var showPermissionExplanation = false
  @State private var showShareSheet = false

  var body: some View {
    NavigationStack {
      ZStack {
        let status = store.locationService.authorizationStatus
        let authorized = status == .authorizedWhenInUse || status == .authorizedAlways
        let waitingOnLocation =
          store.isAcquiringDeviceLocation || store.locationService.isLoading
        if !store.hasRequestedLocationPermission {
          firstLaunchWelcome()
            .padding(.bottom, bottomTabClearance)
        } else if !authorized {
          LocationPermissionView()
            .padding(.bottom, bottomTabClearance)
        } else if weather == nil
          && (waitingOnLocation || store.isLoadingWeather)
        {
          TodaySkeleton(statusText: waitingOnLocation ? TodayCopy.gettingLocation : nil)
        } else if let w = weather {
          TodayFeedView(weather: w)
        } else {
          emptyLocationGate()
            .padding(.bottom, bottomTabClearance)
        }
      }
      .background {
        WeatherBackgroundLayer(
          conditionCode: store.displayedWeather?.conditionCode,
          isDay: store.displayedWeather.map {
            WeatherBackgroundView.isDay(from: $0.symbolName)
          }
            ?? WeatherBackgroundView.inferredIsDay(
              timeZone: store.displayedWeather?.locationTimeZone ?? .current
            ),
          intensity: .staticOnly,
          extraOpacity: 1.0
        )
        .ignoresSafeArea()
      }
      .navigationTitle("Today")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarTitleDisplayMode(.inline)
      .weatherShowsThroughNavigationBar()
      .toolbar {
        if #available(iOS 26.0, *) {
          ToolbarItem(placement: .topBarLeading) {
            shareToolbarButton
          }
          .sharedBackgroundVisibility(.hidden)
          ToolbarItem(placement: .topBarTrailing) {
            locationToolbarButton
          }
          .sharedBackgroundVisibility(.hidden)
        } else {
          ToolbarItem(placement: .topBarLeading) {
            shareToolbarButton
          }
          ToolbarItem(placement: .topBarTrailing) {
            locationToolbarButton
          }
        }
      }
      .sheet(isPresented: $showShareSheet) {
        if let w = weather {
          let score = DayCastScoreCalculator.score(
            for: w, alerts: store.displayableActiveAlerts, units: store.temperatureUnit)
          let items = WeatherShareService.shareItems(
            weather: w,
            score: score,
            locationName: store.currentLocation?.name ?? w.location.name,
            unit: store.temperatureUnit
          )
          ActivityViewRepresentable(items: items, surface: .todayCard)
            .presentationDetents([.medium, .large])
            .onAppear { Analytics.track(.shareStarted, parameters: ["surface": "share_today"]) }
        }
      }
      .sheet(isPresented: $showPermissionExplanation) {
        permissionExplanation()
          .preferredColorScheme(.dark)
          .presentationDetents([.fraction(0.72), .large])
          .presentationDragIndicator(.visible)
          .presentationBackground(DesignTokens.Palette.bgPrimary)
      }
      .onChange(of: store.locationService.authorizationStatus) { _, _ in
        store.noteAuthorizationMayNeedDeviceLocation()
        Task { await store.handleLocationAuthorizationChange() }
      }
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - Onboarding

  private func firstLaunchWelcome() -> some View {
    TodayFirstRunStage {
      TodayFirstRunCard {
        TodayWeatherGlyph(kind: .weather)
        Text(TodayCopy.welcomeTitle)
          .font(DesignTokens.Typography.title())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .multilineTextAlignment(.center)
        Text(TodayCopy.welcomeBody)
          .font(DesignTokens.Typography.callout())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
        TodayTrustRow()
        TodayPrimaryCTA(title: TodayCopy.getStarted) {
          Haptic.impact(.medium)
          showPermissionExplanation = true
        }
        .accessibilityIdentifier(DayCastAccessibility.Today.getStarted)
      }
    }
  }

  private func permissionExplanation() -> some View {
    ScrollView {
      TodayFirstRunCard {
        TodayWeatherGlyph(kind: .location)
        Text(TodayCopy.permissionTitle)
          .font(DesignTokens.Typography.title())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .multilineTextAlignment(.center)
        Text(TodayCopy.permissionBody)
          .font(DesignTokens.Typography.callout())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
        Text(TodayCopy.permissionPrivacy)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
        TodayPrimaryCTA(title: TodayCopy.continuePermission) {
          Haptic.impact(.medium)
          store.markLocationPermissionRequested()
          store.locationService.requestLocationPermission()
          showPermissionExplanation = false
        }
        .accessibilityIdentifier(DayCastAccessibility.Today.continuePermission)
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.top, DesignTokens.Spacing.space24)
      .padding(.bottom, DesignTokens.Spacing.space16)
      .readableContentWidth(ReadableContentWidth.compact)
    }
    .background {
      WeatherBackgroundLayer(
        conditionCode: nil,
        isDay: WeatherBackgroundView.inferredIsDay,
        intensity: .staticOnly
      )
      .ignoresSafeArea()
    }
  }

  private func emptyLocationGate() -> some View {
    TodayFirstRunStage {
      TodayFirstRunCard {
        TodayWeatherGlyph(kind: .city)
        Text(TodayCopy.emptyTitle)
          .font(DesignTokens.Typography.title())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .multilineTextAlignment(.center)
        Text(TodayCopy.emptyBody)
          .font(DesignTokens.Typography.callout())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)

        if store.locationService.isLoading || store.isLoadingWeather
          || store.isAcquiringDeviceLocation
        {
          TodayStatusPill(text: TodayCopy.gettingLocation)
        } else if let error = store.weatherError, !error.isEmpty {
          TodayMessageBanner(
            message: error,
            isOffline: store.isOffline,
            tone: store.isShowingDefaultLocationFallback ? .warning : .danger,
            actionTitle: "Retry"
          ) {
            Haptic.impact(.medium)
            Task { await store.useCurrentDeviceLocation() }
          }
        } else {
          TodayPrimaryCTA(
            title: TodayCopy.useMyPosition,
            systemImage: "location.fill"
          ) {
            Haptic.impact(.medium)
            Task { await store.useCurrentDeviceLocation() }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var shareToolbarButton: some View {
    if weather != nil {
      Button {
        Haptic.impact(.light)
        showShareSheet = true
      } label: {
        Image(systemName: "square.and.arrow.up")
          .font(DesignTokens.Typography.symbol(17))
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .frame(width: DesignTokens.Layout.minHitTarget, height: DesignTokens.Layout.minHitTarget)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .tint(DesignTokens.Palette.textPrimary)
      .accessibilityLabel("Share weather")
    }
  }

  private var locationToolbarButton: some View {
    Button {
      Haptic.impact(.light)
      Task { await store.useCurrentDeviceLocation() }
    } label: {
      Image(systemName: "location.circle.fill")
        .font(DesignTokens.Typography.symbol(17))
        .foregroundStyle(DesignTokens.Palette.textSecondary)
        .frame(width: DesignTokens.Layout.minHitTarget, height: DesignTokens.Layout.minHitTarget)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .tint(DesignTokens.Palette.textSecondary)
    .accessibilityLabel("Use current location")
  }

}

// MARK: - Today Skeleton Loading (Shimmer)

struct TodaySkeleton: View {
  var statusText: String? = nil

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        if let statusText, !statusText.isEmpty {
          TodayStatusPill(text: statusText)
            .padding(.horizontal, DesignTokens.Spacing.space20)
        }
        TodaySkeletonPanel()
          .padding(.horizontal, DesignTokens.Spacing.space20)
      }
      .padding(.top, todayContentTopPadding)
      .padding(.bottom, bottomTabClearance)
      .adaptiveContainerWidth(AdaptiveLayout.contentCap)
    }
  }
}

private struct TodaySkeletonPanel: View {
  var body: some View {
    VStack(spacing: TodayGlanceLayout.feedSpacing) {
      chipBarSkeleton
      HeroSkeleton()
      outlookSlotSkeleton
    }
  }

  private var chipBarSkeleton: some View {
    HStack(spacing: DesignTokens.Spacing.space8) {
      ShimmerBlock(width: 88, height: 36, cornerRadius: 18)
      ShimmerBlock(width: 72, height: 36, cornerRadius: 18)
      ShimmerBlock(width: 96, height: 36, cornerRadius: 18)
      Spacer(minLength: 0)
    }
  }

  private var outlookSlotSkeleton: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      ShimmerBlock(width: 168, height: 22, cornerRadius: 4)
      ShimmerBlock(width: nil, height: 14, cornerRadius: 4)
      ShimmerBlock(width: 220, height: 14, cornerRadius: 4)
      ShimmerBlock(width: nil, height: TodayGlanceLayout.hourlyGraphHeight, cornerRadius: 8)
    }
    .padding(.top, DesignTokens.Spacing.space8)
  }
}

/// Type-on-stage Now — matches `NowFeedCard`. Photo is the tab background.
struct HeroSkeleton: View {
  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      HStack(alignment: .top) {
        ShimmerBlock(width: 148, height: 64, cornerRadius: DesignTokens.Radius.small)
        Spacer(minLength: 8)
        VStack(spacing: 6) {
          ShimmerBlock(width: 56, height: 56, cornerRadius: 12)
          ShimmerBlock(width: 88, height: 14, cornerRadius: 4)
        }
      }
      ShimmerBlock(width: 240, height: 14, cornerRadius: 4)
      ShimmerBlock(width: 200, height: 14, cornerRadius: 4)
    }
    .frame(
      maxWidth: .infinity,
      minHeight: TodayGlanceLayout.nowBudgetHeight,
      alignment: .leading
    )
  }
}

#Preview("Today — waiting skeleton") {
  ZStack {
    WeatherBackgroundLayer(conditionCode: nil, intensity: .staticOnly)
      .ignoresSafeArea()
    TodaySkeleton(statusText: TodayCopy.gettingLocation)
  }
  .preferredColorScheme(.dark)
}

#Preview("Today — iPhone") {
  TodayView()
    .environment(WeatherStore())
    .environment(SevereWeatherStore.shared)
    .environment(ShortTermPrecipStore.shared)
    .environment(FireStore.shared)
    .environment(GrokBriefSafety())
}

#Preview("Today — 500pt regular") {
  TodayView()
    .environment(WeatherStore())
    .environment(SevereWeatherStore.shared)
    .environment(ShortTermPrecipStore.shared)
    .environment(FireStore.shared)
    .environment(GrokBriefSafety())
    .frame(width: 500, height: 900)
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("Today — 650pt regular") {
  TodayView()
    .environment(WeatherStore())
    .environment(SevereWeatherStore.shared)
    .environment(ShortTermPrecipStore.shared)
    .environment(FireStore.shared)
    .environment(GrokBriefSafety())
    .frame(width: 650, height: 900)
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("Today — 700pt regular") {
  TodayView()
    .environment(WeatherStore())
    .environment(SevereWeatherStore.shared)
    .environment(ShortTermPrecipStore.shared)
    .environment(FireStore.shared)
    .environment(GrokBriefSafety())
    .frame(width: 700, height: 900)
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("Today — 1024pt regular") {
  TodayView()
    .environment(WeatherStore())
    .environment(SevereWeatherStore.shared)
    .environment(ShortTermPrecipStore.shared)
    .environment(FireStore.shared)
    .environment(GrokBriefSafety())
    .frame(width: 1024, height: 900)
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("Today — iPad Pro 11-inch (M4)") {
  TodayView()
    .environment(WeatherStore())
    .environment(SevereWeatherStore.shared)
    .environment(ShortTermPrecipStore.shared)
    .environment(FireStore.shared)
    .environment(GrokBriefSafety())
}
