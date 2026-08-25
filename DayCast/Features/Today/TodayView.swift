import SwiftUI

private let bottomTabClearance = DesignTokens.Layout.tabBarScrollClearance
private let todayContentTopPadding = DesignTokens.Spacing.space16

enum TodayCopy {
  static let welcomeTitle = "Welcome to DayCast"
  static let welcomeBody =
    "Local Now for your city, official alerts, and next-hour rain you can believe."
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
    "DayCast uses your location to show local Now, official alerts, and next-hour rain."
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
  static let trustNextHour = "Next hour"
}

/// Storm-first skeleton slots — must match the glance cards, not the old tactical grid.
enum TodaySkeletonSlot: String, CaseIterable {
  case now
  case alerts
  case precip
  case hourly

  var feedItem: FeedItem {
    switch self {
    case .now: .now
    case .alerts: .alerts
    case .precip: .precip
    case .hourly: .hourly
    }
  }

  static var feedOrder: [TodaySkeletonSlot] { [.now, .alerts, .precip, .hourly] }
}

struct TodayView: View {
  @Environment(WeatherStore.self) private var store

  var weather: DayCastWeather? { store.displayedWeather }
  var locationName: String { store.currentLocation?.name ?? "—" }

  // Grok Imagine state
  @State private var isGeneratingImage = false
  @State private var generatedImageURL: URL?
  @State private var showImagineResult = false
  @State private var imagineError: String?

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
          TodayFeedView(
            weather: w,
            isGeneratingImage: isGeneratingImage,
            generateImageAction: generateImageForToday
          )
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
        ToolbarItem(placement: .topBarLeading) {
          if weather != nil {
            Button {
              Haptic.impact(.light)
              showShareSheet = true
            } label: {
              Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Share")
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            Haptic.impact(.light)
            Task { await store.useCurrentDeviceLocation() }
          } label: {
            Image(systemName: "location.circle.fill")
          }
          .accessibilityLabel("Use current location")
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
            grokBrief: nil,
            unit: store.temperatureUnit
          )
          ActivityViewRepresentable(items: items, surface: .todayCard)
            .presentationDetents([.medium, .large])
            .onAppear { Analytics.track(.shareStarted, parameters: ["surface": "share_today"]) }
        }
      }
      .sheet(isPresented: $showImagineResult) {
        if let url = generatedImageURL, let w = weather {
          GrokImagineResultView(
            imageURL: url,
            locationName: w.location.name,
            currentCondition: w.conditionText,
            temperature: w.currentTemp,
            onRegenerate: {
              showImagineResult = false
              generatedImageURL = nil
              generateImageForToday()
            }
          )
        }
      }
      .alert(
        "Image Generation Failed",
        isPresented: Binding(
          get: { imagineError != nil },
          set: { if !$0 { imagineError = nil } }
        )
      ) {
        Button("OK") { imagineError = nil }
      } message: {
        Text(imagineError ?? "Unknown error")
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

}

struct GrokImagineButton: View {
  let weather: DayCastWeather
  let isGenerating: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: DesignTokens.Spacing.space8) {
        if isGenerating {
          ProgressView()
            .tint(.white)
          Text("Generating…")
            .font(DesignTokens.Typography.subsection())
        } else {
          Label("Imagine today", systemImage: "sparkles.rectangle.stack")
            .font(DesignTokens.Typography.subsection())
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, DesignTokens.Spacing.space12)
    }
    .buttonStyle(.borderedProminent)
    .tint(DesignTokens.Palette.accent)
    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
    .disabled(isGenerating)
    .opacity(isGenerating ? 0.7 : 1.0)
  }
}

// MARK: - Grok Imagine Logic
extension TodayView {
  private func generateImageForToday() {
    guard let w = weather else { return }

    imagineError = nil
    isGeneratingImage = true
    Haptic.impact(.heavy)

    let prompt = buildImaginePrompt(for: w)

    Task {
      do {
        let url = try await GrokBuildService.generateImage(prompt: prompt)
        isGeneratingImage = false
        generatedImageURL = url
        showImagineResult = true
      } catch {
        isGeneratingImage = false
        imagineError = error.localizedDescription
      }
    }
  }

  private func buildImaginePrompt(for w: DayCastWeather) -> String {
    let condition = w.conditionText.lowercased()
    let location = w.location.name
    let temp = store.temperatureUnit.format(w.currentTemp)

    return """
      A cinematic, photorealistic image of the current weather in \(location): 
      \(condition) skies, temperature around \(temp). 
      Beautiful natural lighting, high detail, realistic photography style, 
      no text, no people unless it enhances the scene.
      """
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
      alertsSlotSkeleton
      precipSlotSkeleton
      hourlySlotSkeleton
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

  /// Thin alert chip — matches `AlertsFeedCard` event row, not a padded card.
  private var alertsSlotSkeleton: some View {
    HStack(spacing: DesignTokens.Spacing.space8) {
      ShimmerBlock(width: 18, height: 18, cornerRadius: 4)
      ShimmerBlock(width: 148, height: 14, cornerRadius: 4)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, DesignTokens.Spacing.space12)
    .frame(
      maxWidth: .infinity,
      minHeight: TodayGlanceLayout.alertChipMinHeight,
      alignment: .leading
    )
    .background(DesignTokens.Palette.cardBackground.opacity(0.72))
    .overlay(
      RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
        .stroke(DesignTokens.Palette.cardStroke, lineWidth: DesignTokens.Card.strokeWidth)
    )
    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
  }

  /// Next hour precip strip: caption + message + intensity bars.
  private var precipSlotSkeleton: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      ShimmerBlock(width: 88, height: 12, cornerRadius: 4)
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
        ShimmerBlock(width: 168, height: 12, cornerRadius: 4)
        HStack(alignment: .bottom, spacing: 4) {
          ForEach(0..<16, id: \.self) { index in
            RoundedRectangle(cornerRadius: 2, style: .continuous)
              .fill(DesignTokens.Palette.cardElevated)
              .frame(maxWidth: .infinity)
              .frame(height: precipBarHeight(at: index))
              .shimmer()
          }
        }
        .frame(height: 32, alignment: .bottom)
      }
      .padding(.vertical, DesignTokens.Spacing.space12)
      .padding(.horizontal, DesignTokens.Spacing.space16)
      .cardStyle(cornerRadius: DesignTokens.Radius.small)
    }
  }

  private func precipBarHeight(at index: Int) -> CGFloat {
    // Quiet variation so the strip reads as intensity, not identical ticks.
    let pattern: [CGFloat] = [8, 8, 10, 16, 24, 18, 10, 8]
    return pattern[index % pattern.count]
  }

  private var hourlySlotSkeleton: some View {
    VStack(alignment: .leading, spacing: TodayGlanceLayout.hourlyInnerSpacing) {
      HStack {
        ShimmerBlock(width: 64, height: 12, cornerRadius: 4)
        Spacer(minLength: 0)
        ShimmerBlock(width: 108, height: 16, cornerRadius: 8)
      }
      .frame(height: TodayGlanceLayout.hourlyHeaderHeight)
      ShimmerBlock(width: 240, height: 14, cornerRadius: 4)
      ShimmerBlock(width: 200, height: 14, cornerRadius: 4)
        .frame(
          maxWidth: .infinity,
          minHeight: TodayGlanceLayout.hourlyTonightLineHeight,
          alignment: .topLeading
        )
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
        ShimmerBlock(
          width: HourlyGraphLayout.columnWidth * 8,
          height: 10,
          cornerRadius: 5
        )
        .padding(.top, DesignTokens.Spacing.space16)
        HStack(spacing: 0) {
          ForEach(0..<4, id: \.self) { _ in
            ShimmerBlock(width: 28, height: 10, cornerRadius: 3)
              .frame(width: HourlyGraphLayout.columnWidth * 2)
          }
          Spacer(minLength: 0)
        }
      }
      .frame(height: TodayGlanceLayout.hourlyGraphHeight, alignment: .top)
    }
    .padding(TodayGlanceLayout.hourlyCardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardStyle()
  }
}

/// Floating Now hero — temp, condition, feels + Updated on one row.
/// Matches `NowFeedCard` (city is the chip bar; score is Now detail).
struct HeroSkeleton: View {
  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      HStack(alignment: .center, spacing: DesignTokens.Spacing.space12) {
        ShimmerBlock(width: 132, height: 64, cornerRadius: DesignTokens.Radius.small)
        Spacer(minLength: 8)
        VStack(spacing: DesignTokens.Spacing.space4) {
          ShimmerBlock(width: 36, height: 36, cornerRadius: DesignTokens.Radius.small)
          ShimmerBlock(width: 72, height: 14, cornerRadius: DesignTokens.Radius.small)
        }
      }

      HStack(spacing: DesignTokens.Spacing.space8) {
        ShimmerBlock(width: 196, height: 14, cornerRadius: DesignTokens.Radius.small)
        Spacer(minLength: 4)
        ShimmerBlock(width: 96, height: 12, cornerRadius: DesignTokens.Radius.small)
      }
    }
    .padding(.horizontal, DesignTokens.Spacing.space4)
    .padding(.top, DesignTokens.Spacing.space4)
    .padding(.bottom, DesignTokens.Spacing.space8)
    .frame(maxWidth: .infinity, alignment: .leading)
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
