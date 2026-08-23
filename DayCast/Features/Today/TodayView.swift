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
    VStack {
      Spacer()
      VStack(spacing: 20) {
        Image(systemName: "sun.max")
          .font(DesignTokens.Typography.symbol(48))
          .foregroundStyle(DesignTokens.Palette.textTertiary)
        Text(TodayCopy.welcomeTitle)
          .font(DesignTokens.Typography.studioTitle())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        Text(TodayCopy.welcomeBody)
          .font(.callout)
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 8)
        Button("Get Started") {
          Haptic.impact(.medium)
          showPermissionExplanation = true
        }
        .buttonStyle(.borderedProminent)
        .tint(DesignTokens.Palette.accent)
      }
      .padding(DesignTokens.Spacing.space16)
      .cardStyle(
        background: DesignTokens.Palette.cardBackground,
        stroke: DesignTokens.Palette.cardStroke,
        cornerRadius: DesignTokens.Card.cornerRadiusMedium
      )
      .padding(.horizontal, 20)
      .readableContentWidth(ReadableContentWidth.compact)
      Spacer()
    }
  }

  private func permissionExplanation() -> some View {
    VStack(spacing: 20) {
      Image(systemName: "location.fill")
        .font(DesignTokens.Typography.symbol(48))
        .foregroundStyle(DesignTokens.Palette.textPrimary)
      VStack(spacing: 12) {
        Text("DayCast uses your location to show accurate weather forecasts for where you are.")
          .font(DesignTokens.Typography.body())
          .multilineTextAlignment(.center)
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        Text("Your location is only used for weather — we don’t track or store it.")
          .font(DesignTokens.Typography.body())
          .multilineTextAlignment(.center)
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      }
      Button("Continue") {
        Haptic.impact(.medium)
        store.markLocationPermissionRequested()
        store.locationService.requestLocationPermission()
        showPermissionExplanation = false
      }
      .buttonStyle(.borderedProminent)
      .tint(DesignTokens.Palette.accent)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func emptyLocationGate() -> some View {
    ContentUnavailableView {
      Label(TodayCopy.emptyTitle, systemImage: "location.circle")
    } description: {
      Text(TodayCopy.emptyBody)
    } actions: {
      VStack(spacing: 12) {
        if store.locationService.isLoading || store.isLoadingWeather
          || store.isAcquiringDeviceLocation
        {
          HStack(spacing: 8) {
            ProgressView()
              .tint(.white)
            Text(TodayCopy.gettingLocation)
              .font(DesignTokens.Typography.caption())
              .foregroundStyle(DesignTokens.Palette.textTertiary)
          }
        } else if store.weatherError != nil {
          HStack(spacing: 8) {
            Image(
              systemName: store.isOffline ? "wifi.slash" : "exclamationmark.triangle.fill"
            )
            .foregroundStyle(DesignTokens.Palette.danger)
            Text(store.weatherError ?? "")
              .font(DesignTokens.Typography.caption())
              .foregroundStyle(DesignTokens.Palette.danger)
              .lineLimit(2)
            Spacer(minLength: 8)
            Button("Retry") {
              Haptic.impact(.medium)
              Task { await store.useCurrentDeviceLocation() }
            }
            .font(DesignTokens.Typography.caption())
            .buttonStyle(.bordered)
            .tint(DesignTokens.Palette.danger)
            .controlSize(.small)
          }
          .padding(8)
          .background(DesignTokens.Palette.danger.opacity(0.15))
          .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
          Button("USE MY POSITION") {
            Haptic.impact(.medium)
            Task { await store.useCurrentDeviceLocation() }
          }
          .buttonStyle(.borderedProminent)
          .tint(DesignTokens.Palette.accent)
        }
      }
      .padding(16)
      .background(DesignTokens.Palette.cardBackground)
      .overlay(
        RoundedRectangle(cornerRadius: 14)
          .stroke(DesignTokens.Palette.cardStroke, lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 14))
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
          HStack(spacing: DesignTokens.Spacing.space8) {
            ProgressView()
              .tint(.white)
            Text(statusText)
              .font(DesignTokens.Typography.caption())
              .foregroundStyle(DesignTokens.Palette.textSecondary)
          }
          .padding(.horizontal, DesignTokens.Spacing.space20)
          .accessibilityElement(children: .combine)
          .accessibilityLabel(statusText)
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
    VStack(spacing: DesignTokens.Spacing.space16) {
      chipBarSkeleton
      HeroSkeleton(includeHorizontalPadding: false)
      alertsSlotSkeleton
      precipSlotSkeleton
      hourlySlotSkeleton
    }
  }

  private var chipBarSkeleton: some View {
    HStack(spacing: DesignTokens.Spacing.space8) {
      ShimmerBlock(width: 88, height: 32, cornerRadius: DesignTokens.Radius.small)
      ShimmerBlock(width: 72, height: 32, cornerRadius: DesignTokens.Radius.small)
      ShimmerBlock(width: 96, height: 32, cornerRadius: DesignTokens.Radius.small)
      Spacer(minLength: 0)
    }
  }

  private var alertsSlotSkeleton: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      ShimmerBlock(width: 110, height: 12, cornerRadius: DesignTokens.Radius.small)
      ShimmerBlock(width: nil, height: 52, cornerRadius: DesignTokens.Radius.medium)
    }
    .padding(DesignTokens.Spacing.space16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .elevatedCardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadiusMedium
    )
  }

  private var precipSlotSkeleton: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      ShimmerBlock(width: 88, height: 12, cornerRadius: DesignTokens.Radius.small)
      HStack(spacing: DesignTokens.Spacing.space4) {
        ForEach(0..<8, id: \.self) { _ in
          ShimmerBlock(width: nil, height: 36, cornerRadius: DesignTokens.Radius.small)
        }
      }
    }
    .padding(DesignTokens.Spacing.space16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .elevatedCardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadiusMedium
    )
  }

  private var hourlySlotSkeleton: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      ShimmerBlock(width: 72, height: 12, cornerRadius: DesignTokens.Radius.small)
      HStack(spacing: DesignTokens.Spacing.space12) {
        ForEach(0..<6, id: \.self) { _ in
          VStack(spacing: DesignTokens.Spacing.space8) {
            ShimmerBlock(width: 28, height: 10, cornerRadius: DesignTokens.Radius.small)
            ShimmerBlock(width: 28, height: 28, cornerRadius: DesignTokens.Radius.small)
            ShimmerBlock(width: 36, height: 16, cornerRadius: DesignTokens.Radius.small)
          }
        }
        Spacer(minLength: 0)
      }
    }
    .padding(DesignTokens.Spacing.space16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(height: DesignTokens.Layout.hourlyRowHeight + DesignTokens.Spacing.space40)
    .elevatedCardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadiusMedium
    )
  }
}

struct HeroSkeleton: View {
  var includeHorizontalPadding: Bool = true

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
      ShimmerBlock(width: 140, height: 28, cornerRadius: DesignTokens.Radius.small)

      HStack(alignment: .center, spacing: DesignTokens.Spacing.space12) {
        ShimmerBlock(width: 120, height: 72, cornerRadius: DesignTokens.Radius.small)
        Spacer()
        VStack(spacing: DesignTokens.Spacing.space8) {
          ShimmerBlock(width: 48, height: 48, cornerRadius: DesignTokens.Radius.small)
          ShimmerBlock(width: 90, height: 16, cornerRadius: DesignTokens.Radius.small)
        }
      }

      ShimmerBlock(width: 200, height: 16, cornerRadius: DesignTokens.Radius.small)
      ShimmerBlock(width: 120, height: 12, cornerRadius: DesignTokens.Radius.small)
    }
    .padding(.vertical, DesignTokens.Spacing.space20)
    .padding(.horizontal, includeHorizontalPadding ? DesignTokens.Spacing.space20 : 0)
    .frame(maxWidth: .infinity, alignment: .leading)
    .elevatedCardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadiusLarge
    )
  }
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
