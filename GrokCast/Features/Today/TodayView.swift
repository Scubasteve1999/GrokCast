import SwiftUI

// Follows GrokCast Design System v1 exactly (see /DesignSystem.md at project root).
// Colors via DesignTokens.Palette, spacing/radius/shadows per spec.
// IA: large hero (icon left of dominant temp + prominent FEELS LIKE) + dedicated TONIGHT'S WEATHER + clean 2-col grid.

// Shared bottom clearance for Today tab states (data, skeleton, non-scroll) to clear
// the custom tab bar on .compact (iPhone) incl. large phones like iPhone 16 Pro Max.
private let bottomTabClearance = DesignTokens.Spacing.space32
/// Figma Today screen: content starts below status bar with modest top inset.
private let todayContentTopPadding = DesignTokens.Spacing.space16

struct TodayView: View {
  @Environment(WeatherStore.self) private var store

  var weather: GrokCastWeather? { store.currentWeather }
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

  var body: some View {
    NavigationStack {
      ZStack {
        todayWeatherBackground

        let status = store.locationService.authorizationStatus
        if !store.hasRequestedLocationPermission {
          // First-launch onboarding welcome (Today tab). Shown *only* on true first launch
          // (flag false + typically .notDetermined). "Get Started" presents the short
          // friendly explanation sheet (once) before any iOS prompt. After grant + load,
          // the reactive status + flag flip + existing skeleton/data paths give a smooth
          // transition to the normal Today UI. Build directly on the welcome state added
          // in empty-states work; uses identical TacticalCard styling + Haptic.
          firstLaunchWelcome()
            .padding(.bottom, bottomTabClearance)
        } else if !(status == .authorizedWhenInUse || status == .authorizedAlways) {
          LocationPermissionView()
            .padding(.bottom, bottomTabClearance)
        } else if weather == nil && (store.isLoadingWeather || store.locationService.isLoading) {
          TodaySkeleton()
        } else if let w = weather {
          ScrollView {
            TodayWeatherPanel(
              weather: w,
              isGeneratingImage: isGeneratingImage,
              generateImageAction: generateImageForToday
            )
            .padding(.horizontal, DesignTokens.Spacing.space20)
            .padding(.top, todayContentTopPadding)
            .padding(.bottom, bottomTabClearance)
            .adaptiveContainerWidth(AdaptiveLayout.contentCap)
          }
          .refreshable {
            await store.refreshWeather()
          }
        } else {
          // First load / no data state: welcome message + "Use My Position" button (neutral, per empty states rules and mockup).
          // Error state handled in actions via errorBanner pattern (red only for errors).
          ContentUnavailableView {
            Label("Welcome to GrokCast", systemImage: "sun.max")
          } description: {
            Text(
              "Establish your location to get started with accurate, personalized forecasts and insights."
            )
          } actions: {
            VStack(spacing: 12) {
              if store.locationService.isLoading || store.isLoadingWeather {
                HStack(spacing: 8) {
                  ProgressView()
                    .tint(.white)
                  Text("ACQUIRING...")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DesignTokens.Palette.textTertiary)
                }
              } else if store.weatherError != nil
                && !(store.locationService.isLoading || store.isLoadingWeather)
              {
                // Error state uses the new errorBanner pattern (icon + message + Retry).
                // Red accents for errors only.
                HStack(spacing: 8) {
                  Image(
                    systemName: store.isOffline ? "wifi.slash" : "exclamationmark.triangle.fill"
                  )
                  .foregroundStyle(DesignTokens.Palette.danger)
                  Text(store.weatherError ?? "")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Palette.danger)
                    .lineLimit(2)
                  Spacer(minLength: 8)
                  Button("Retry") {
                    Haptic.impact(.medium)
                    Task { await store.useCurrentDeviceLocation() }
                  }
                  .font(.caption.bold())
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
            // TacticalCard-inspired styling for the actions container (pure empty or error state).
            .padding(16)
            .background(DesignTokens.Palette.cardBackground)
            .overlay(
              RoundedRectangle(cornerRadius: 14)
                .stroke(DesignTokens.Palette.cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
          }
          .padding(.bottom, bottomTabClearance)
        }
      }
      .navigationTitle("")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            Haptic.impact(.light)
            Task { await store.useCurrentDeviceLocation() }
          } label: {
            Image(systemName: "location.circle.fill")
          }
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
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - First Launch / Onboarding (light touch, shown only when !hasRequestedLocationPermission)

  /// The welcoming first-launch card shown in the Today tab on a true first launch.
  /// "Get Started" presents the one-time permission explanation sheet (new copy per spec).
  /// Uses the same TacticalCard-inspired styling as the recovery welcome and detail cards.
  /// Haptic on the CTA. After the flow + grant the existing reactive branches + skeleton
  /// provide the smooth transition to the normal weather UI.
  private func firstLaunchWelcome() -> some View {
    VStack {
      Spacer()
      VStack(spacing: 20) {
        Image(systemName: "sun.max")
          .font(.system(size: 48))
          .foregroundStyle(DesignTokens.Palette.textTertiary)
        Text("Welcome to GrokCast")
          .font(.title2.weight(.semibold))
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        Text(
          "Your AI-powered weather companion. Get accurate, localized forecasts with smart insights."
        )
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
    .onAppear {
      // First-launch welcome appeared (no-op for production; diagnostics removed).
    }
  }

  /// The short, friendly, one-time explanation shown (as a sheet) right before the
  /// system iOS location permission prompt. Triggered by "Get Started" on first launch.
  /// "Continue" marks the flow complete (via hasRequestedLocationPermission), calls the
  /// unified requestLocationPermission(), and dismisses. Exact text per current query mockup.
  /// TacticalCard styling for premium feel.
  private func permissionExplanation() -> some View {
    VStack(spacing: 20) {
      Image(systemName: "location.fill")
        .font(.system(size: 48))
        .foregroundStyle(DesignTokens.Palette.textPrimary)
      VStack(spacing: 12) {
        Text("GrokCast uses your location to show accurate weather forecasts for where you are.")
          .font(.body)
          .multilineTextAlignment(.center)
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        Text("Your location is only used for weather — we don’t track or store it.")
          .font(.body)
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

  /// Bright, Apple-Weather-style condition sky backdrop for the Today tab (see TodayBrightTheme).
  private var todayWeatherBackground: some View {
    TodaySkyBackground(
      conditionCode: store.currentWeather?.conditionCode ?? 0,
      isDay: store.currentWeather.map {
        WeatherBackgroundView.isDay(from: $0.symbolName)
      } ?? WeatherBackgroundView.inferredIsDay
    )
  }
}

private struct TodayWeatherPanel: View {
  @Environment(WeatherStore.self) private var store
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.adaptiveContainerWidth) private var adaptiveContainerWidth

  let weather: GrokCastWeather
  let isGeneratingImage: Bool
  let generateImageAction: () -> Void

  private var currentScore: GrokCastScore {
    GrokCastScoreCalculator.score(
      for: weather, alerts: store.displayableActiveAlerts, units: store.temperatureUnit)
  }

  private var currentMinutecast: MinutecastSummary {
    MinutecastEngine.summary(from: weather.minutely15)
  }

  private var awaitsWidthMeasurement: Bool {
    AdaptiveLayout.awaitingWidthMeasurement(
      width: adaptiveContainerWidth,
      horizontalSizeClass: horizontalSizeClass
    )
  }

  private var prefersTwoColumnLayout: Bool {
    AdaptiveLayout.prefersTwoColumn(
      width: adaptiveContainerWidth,
      horizontalSizeClass: horizontalSizeClass
    )
  }

  var body: some View {
    if !awaitsWidthMeasurement && prefersTwoColumnLayout {
      wideTodayLayout
    } else {
      compactFigmaTodayLayout
    }
  }

  /// Bright Apple-Weather-style Today: hero on the sky, alert, summary + hourly,
  /// 10-day list, then GrokCast's own extras (Grok brief, score, minutecast, details).
  private var compactFigmaTodayLayout: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
      brightHeroSection

      ForEach(store.displayableActiveAlerts.prefix(2)) { alert in
        TodayAlertCard(alert: alert)
      }

      TodaySummaryHourlyCard(weather: weather)

      TodayTenDayCard(daily: weather.daily, currentTemp: weather.currentTemp)

      MinutecastStrip(summary: currentMinutecast)

      GrokBriefCard(presentation: .figma)

      GrokCastScoreCard(
        score: currentScore,
        locationName: store.currentLocation?.name ?? weather.location.name,
        layout: .figma
      )

      brightDetailsGrid

      GrokImagineButton(
        weather: weather,
        isGenerating: isGeneratingImage,
        action: generateImageAction
      )

      errorBanner
      refreshButton
    }
  }

  /// Frosted metric tiles matching the bright Today theme.
  private var brightDetailsGrid: some View {
    let precipValue: String = {
      let c = weather.precipitationChance
      if let d0 = weather.daily.first {
        let liq = (d0.rainSum ?? 0) + (d0.showersSum ?? 0)
        let sn = d0.snowfallSum ?? 0
        if let amtLabel = precipAmountLabel(liquid: liq, snow: sn) {
          return "\(c)% · \(amtLabel)"
        }
      }
      return "\(c)%"
    }()

    return LazyVGrid(
      columns: [GridItem(.flexible()), GridItem(.flexible())],
      spacing: DesignTokens.Spacing.space12
    ) {
      TodayDetailChip(
        label: "HUMIDITY", value: "\(weather.humidity)%", icon: "humidity",
        tint: DesignTokens.Palette.accentCool)
      TodayDetailChip(
        label: "WIND", value: "\(Int(weather.windSpeed)) MPH", icon: "wind",
        tint: DesignTokens.Palette.accent)
      TodayDetailChip(
        label: "UV INDEX", value: "\(Int(weather.uvIndex))", icon: "sun.max",
        tint: DesignTokens.Palette.warning)
      TodayDetailChip(
        label: "PRECIP", value: precipValue, icon: weather.symbolName,
        tint: DesignTokens.Palette.accentCool)
      if let aqi = weather.airQualityIndex {
        TodayDetailChip(
          label: "AQI", value: "\(aqi)", icon: "aqi.medium",
          tint: DesignTokens.Palette.success)
      }
      if let pollen = weather.pollenLevel {
        TodayDetailChip(
          label: "POLLEN", value: pollen, icon: "leaf",
          tint: DesignTokens.Palette.success)
      }
    }
  }

  private var wideTodayLayout: some View {
    VStack(spacing: DesignTokens.Spacing.space24) {
      brightHeroSection

      ForEach(store.displayableActiveAlerts.prefix(2)) { alert in
        TodayAlertCard(alert: alert)
      }

      HStack(alignment: .top, spacing: DesignTokens.Spacing.space24) {
        VStack(spacing: DesignTokens.Spacing.space16) {
          TodaySummaryHourlyCard(weather: weather)
          TodayTenDayCard(daily: weather.daily, currentTemp: weather.currentTemp)
          MinutecastStrip(summary: currentMinutecast)
        }
        .frame(maxWidth: .infinity)

        VStack(spacing: DesignTokens.Spacing.space16) {
          GrokBriefCard(presentation: .figma)
          GrokCastScoreCard(
            score: currentScore,
            locationName: store.currentLocation?.name ?? weather.location.name,
            layout: .figma
          )
          brightDetailsGrid
          GrokImagineButton(
            weather: weather,
            isGenerating: isGeneratingImage,
            action: generateImageAction
          )
        }
        .frame(maxWidth: .infinity)
      }

      errorBanner

      refreshButton
    }
  }

  /// Apple-Weather-style hero floating directly on the sky: HOME pin + location,
  /// dominant temperature, then a "Feels Like" + H/L line. White text with soft shadows.
  private var brightHeroSection: some View {
    VStack(spacing: DesignTokens.Spacing.space2) {
      Label {
        Text("HOME")
          .font(.caption.weight(.semibold))
          .tracking(1.0)
      } icon: {
        Image(systemName: "location.fill")
          .font(.caption2)
      }
      .foregroundStyle(TodayBright.textSecondary)

      Text(store.currentLocation?.name ?? weather.location.name)
        .font(.system(size: 34, weight: .regular))
        .foregroundStyle(TodayBright.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)

      Text(store.formatTemperatureShort(weather.currentTemp))
        .font(.system(size: 96, weight: .thin))
        .foregroundStyle(TodayBright.textPrimary)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .shadow(color: heroGlowColor.opacity(0.30), radius: 24)

      Text("Feels Like: \(store.formatTemperatureShort(weather.feelsLike))")
        .font(.title3)
        .foregroundStyle(TodayBright.textPrimary)

      HStack(spacing: DesignTokens.Spacing.space12) {
        Text("H:\(store.formatTemperatureShort(weather.high))")
        Text("L:\(store.formatTemperatureShort(weather.low))")
      }
      .font(.title3.weight(.medium))
      .foregroundStyle(TodayBright.textPrimary)
      .monospacedDigit()
    }
    .frame(maxWidth: .infinity)
    .multilineTextAlignment(.center)
    .skyTextShadow()
    .padding(.top, DesignTokens.Spacing.space8)
    .padding(.bottom, DesignTokens.Spacing.space16)
  }

  /// Condition-driven accent used for the hero temperature glow.
  private var heroGlowColor: Color {
    let c = weather.conditionText.lowercased()
    if c.contains("rain") || c.contains("storm") || c.contains("drizzle") || c.contains("shower") {
      return DesignTokens.Palette.accentCool
    }
    if c.contains("snow") { return DesignTokens.Palette.accentCool }
    if c.contains("cloud") || c.contains("fog") || c.contains("overcast") {
      return DesignTokens.Palette.accent
    }
    return DesignTokens.Palette.accentWarm
  }

  private var refreshButton: some View {
    Button {
      Haptic.impact(.medium)
      Task { await store.refreshWeather() }
    } label: {
      Label("REFRESH DATA", systemImage: "arrow.clockwise")
        .font(.footnote.weight(.semibold))
        .tracking(1.5)
    }
    .buttonStyle(.bordered)
    .tint(DesignTokens.Palette.textSecondary)
    .padding(.top, DesignTokens.Spacing.space8)
  }

  @ViewBuilder
  private var errorBanner: some View {
    if let error = store.weatherError, !error.isEmpty {
      HStack(spacing: DesignTokens.Spacing.space8) {
        Image(
          systemName: store.isOffline ? "wifi.slash" : "exclamationmark.triangle.fill"
        )
        .foregroundStyle(DesignTokens.Palette.danger)
        Text(error)
          .font(.caption)
          .foregroundStyle(DesignTokens.Palette.danger)
          .lineLimit(2)
        Spacer(minLength: DesignTokens.Spacing.space8)
        Button("Retry") {
          Haptic.impact(.medium)
          Task { await store.refreshWeather() }
        }
        .font(.caption.bold())
        .buttonStyle(.bordered)
        .tint(DesignTokens.Palette.danger)
        .controlSize(.small)
      }
      .padding(DesignTokens.Spacing.space8)
      .background(DesignTokens.Palette.danger.opacity(0.15))
      .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
    }
  }
}

struct GrokImagineButton: View {
  let weather: GrokCastWeather
  let isGenerating: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: DesignTokens.Spacing.space8) {
        if isGenerating {
          ProgressView()
            .tint(.white)
          Text("GENERATING IMAGE...")
            .font(.footnote.weight(.semibold))
            .tracking(DesignTokens.Typography.cardLabelTracking)
        } else {
          Label("GENERATE WHAT TODAY LOOKS LIKE", systemImage: "sparkles.rectangle.stack")
            .font(.footnote.weight(.semibold))
            .tracking(DesignTokens.Typography.cardLabelTracking)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, DesignTokens.Spacing.space8)
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
        let url = try await store.xaiService.generateDayImage(prompt: prompt)
        Task { @MainActor in
          isGeneratingImage = false
          generatedImageURL = url
          showImagineResult = true
        }
      } catch {
        Task { @MainActor in
          isGeneratingImage = false
          imagineError = error.localizedDescription
        }
      }
    }
  }

  private func buildImaginePrompt(for w: GrokCastWeather) -> String {
    let temp = Int(round(w.currentTemp))
    let condition = w.conditionText.lowercased()
    let location = w.location.name

    return """
      A cinematic, photorealistic image of the current weather in \(location): 
      \(condition) skies, temperature around \(temp)°F. 
      Beautiful natural lighting, high detail, realistic photography style, 
      no text, no people unless it enhances the scene.
      """
  }
}

// MARK: - Today Skeleton Loading (Shimmer)

struct TodaySkeleton: View {
  var body: some View {
    ScrollView {
      TodaySkeletonPanel()
        .padding(.horizontal, DesignTokens.Spacing.space20)
        .padding(.top, todayContentTopPadding)
        .padding(.bottom, bottomTabClearance)  // bottom clearance for CustomTabBar on compact + large phones (guarantees vs ~65pt tab)
        .adaptiveContainerWidth(AdaptiveLayout.contentCap)
    }
  }
}

private struct TodaySkeletonPanel: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.adaptiveContainerWidth) private var adaptiveContainerWidth

  private var awaitsWidthMeasurement: Bool {
    AdaptiveLayout.awaitingWidthMeasurement(
      width: adaptiveContainerWidth,
      horizontalSizeClass: horizontalSizeClass
    )
  }

  private var prefersTwoColumnLayout: Bool {
    AdaptiveLayout.prefersTwoColumn(
      width: adaptiveContainerWidth,
      horizontalSizeClass: horizontalSizeClass
    )
  }

  var body: some View {
    VStack(spacing: DesignTokens.Spacing.space48) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
          ShimmerBlock(width: 180, height: 16, cornerRadius: DesignTokens.Radius.small)
          ShimmerBlock(width: 120, height: 12, cornerRadius: DesignTokens.Radius.small)
        }
        Spacer()
        ShimmerBlock(width: 60, height: 12, cornerRadius: DesignTokens.Radius.small)
      }

      if !awaitsWidthMeasurement && prefersTwoColumnLayout {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.space24) {
          VStack(spacing: DesignTokens.Spacing.space16) {
            HeroSkeleton(includeHorizontalPadding: false)
            ShimmerBlock(width: nil, height: 80, cornerRadius: DesignTokens.Card.cornerRadiusLarge)
              .elevatedCardStyle(
                background: DesignTokens.Palette.cardBackground,
                stroke: DesignTokens.Palette.cardStroke,
                cornerRadius: DesignTokens.Card.cornerRadiusLarge
              )
          }
          .frame(maxWidth: .infinity)

          VStack(spacing: DesignTokens.Spacing.space24) {
            LazyVGrid(
              columns: [GridItem(.flexible()), GridItem(.flexible())],
              spacing: DesignTokens.Spacing.space20
            ) {
              ForEach(0..<8, id: \.self) { _ in
                TacticalCardSkeleton()
              }
            }

            ShimmerBlock(width: nil, height: 44, cornerRadius: DesignTokens.Radius.medium)
          }
          .frame(maxWidth: .infinity)
        }
      } else {
        HeroSkeleton(includeHorizontalPadding: false)
        ShimmerBlock(width: nil, height: 80, cornerRadius: DesignTokens.Card.cornerRadiusLarge)
          .elevatedCardStyle(
            background: DesignTokens.Palette.cardBackground,
            stroke: DesignTokens.Palette.cardStroke,
            cornerRadius: DesignTokens.Card.cornerRadiusLarge
          )

        LazyVGrid(
          columns: [GridItem(.flexible()), GridItem(.flexible())],
          spacing: DesignTokens.Spacing.space20
        ) {
          ForEach(0..<8, id: \.self) { _ in
            TacticalCardSkeleton()
          }
        }

        ShimmerBlock(width: nil, height: 44, cornerRadius: DesignTokens.Radius.medium)
          .padding(.top, DesignTokens.Spacing.space12)
      }

      ShimmerBlock(width: 140, height: 36, cornerRadius: DesignTokens.Radius.small)
        .padding(.top, DesignTokens.Spacing.space16)
    }
  }
}

struct HeroSkeleton: View {
  var includeHorizontalPadding: Bool = true

  var body: some View {
    VStack(spacing: DesignTokens.Spacing.space4) {
      // Minutecast banner placeholder
      ShimmerBlock(width: 200, height: 14, cornerRadius: DesignTokens.Radius.small)

      HStack(alignment: .center, spacing: DesignTokens.Spacing.space12) {
        // Icon
        ShimmerBlock(width: 42, height: 42, cornerRadius: DesignTokens.Radius.small)

        // Big temp
        ShimmerBlock(width: 120, height: 90, cornerRadius: DesignTokens.Radius.small)

        Spacer()

        // RealFeel
        VStack(alignment: .trailing, spacing: DesignTokens.Spacing.space2) {
          ShimmerBlock(width: 60, height: 12, cornerRadius: DesignTokens.Radius.small)
          ShimmerBlock(width: 50, height: 20, cornerRadius: DesignTokens.Radius.small)
        }
      }

      // Condition
      ShimmerBlock(width: 140, height: 18, cornerRadius: DesignTokens.Radius.small)
    }
    .padding(.vertical, DesignTokens.Spacing.space20)
    .padding(.horizontal, includeHorizontalPadding ? DesignTokens.Spacing.space20 : 0)
    .frame(maxWidth: .infinity)
    .elevatedCardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadiusLarge
    )
  }
}

struct TacticalCardSkeleton: View {
  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      HStack(spacing: DesignTokens.Spacing.space8) {
        ShimmerBlock(width: 16, height: 16, cornerRadius: DesignTokens.Radius.small)
        ShimmerBlock(width: 80, height: 12, cornerRadius: DesignTokens.Radius.small)
      }

      ShimmerBlock(width: 120, height: 34, cornerRadius: DesignTokens.Radius.small)
    }
    .padding(DesignTokens.Spacing.space20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .elevatedCardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadiusMedium
    )
  }
}

#Preview("Today — iPhone") {
  TodayView()
    .environment(WeatherStore())
}

#Preview("Today — 500pt regular") {
  TodayView()
    .environment(WeatherStore())
    .frame(width: 500, height: 900)
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("Today — 650pt regular") {
  TodayView()
    .environment(WeatherStore())
    .frame(width: 650, height: 900)
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("Today — 700pt regular") {
  TodayView()
    .environment(WeatherStore())
    .frame(width: 700, height: 900)
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("Today — 1024pt regular") {
  TodayView()
    .environment(WeatherStore())
    .frame(width: 1024, height: 900)
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("Today — iPad Pro 11-inch (M4)") {
  TodayView()
    .environment(WeatherStore())
}
