import SwiftUI

private let bottomTabClearance = DesignTokens.Layout.tabBarScrollClearance
private let todayContentTopPadding = DesignTokens.Spacing.space16

struct TodayView: View {
  @Environment(WeatherStore.self) private var store

  var weather: DayCastWeather? { store.currentWeather }
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
        WeatherBackgroundLayer(
          conditionCode: store.currentWeather?.conditionCode,
          isDay: store.currentWeather.map {
            WeatherBackgroundView.isDay(from: $0.symbolName)
          } ?? WeatherBackgroundView.inferredIsDay(
            timeZone: store.currentWeather?.locationTimeZone ?? .current
          ),
          intensity: .staticOnly,
          extraOpacity: 1.0
        )

        let status = store.locationService.authorizationStatus
        if !store.hasRequestedLocationPermission {
          firstLaunchWelcome()
            .padding(.bottom, bottomTabClearance)
        } else if !(status == .authorizedWhenInUse || status == .authorizedAlways) {
          LocationPermissionView()
            .padding(.bottom, bottomTabClearance)
        } else if weather == nil && (store.isLoadingWeather || store.locationService.isLoading) {
          TodaySkeleton()
        } else if let w = weather {
          TodayFeedView(
            weather: w,
            isGeneratingImage: isGeneratingImage,
            generateImageAction: generateImageForToday
          )
        } else {
          ContentUnavailableView {
            Label("Welcome to DayCast", systemImage: "sun.max")
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
                    .font(DesignTokens.Typography.caption())
                    .foregroundStyle(DesignTokens.Palette.textTertiary)
                }
              } else if store.weatherError != nil
                && !(store.locationService.isLoading || store.isLoadingWeather)
              {
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
          .padding(.bottom, bottomTabClearance)
        }
      }
      .navigationTitle("")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          if weather != nil {
            Button {
              Haptic.impact(.light)
              showShareSheet = true
            } label: {
              Image(systemName: "square.and.arrow.up")
            }
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            Haptic.impact(.light)
            Task { await store.useCurrentDeviceLocation() }
          } label: {
            Image(systemName: "location.circle.fill")
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
            grokBrief: nil
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
        Text("Welcome to DayCast")
          .font(DesignTokens.Typography.studioTitle())
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
        let url = try await store.xaiService.generateDayImage(prompt: prompt)
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
    .environment(SevereWeatherStore.shared)
    .environment(ShortTermPrecipStore.shared)
    .environment(FireStore.shared)
}

#Preview("Today — 500pt regular") {
  TodayView()
    .environment(WeatherStore())
    .environment(SevereWeatherStore.shared)
    .environment(ShortTermPrecipStore.shared)
    .environment(FireStore.shared)
    .frame(width: 500, height: 900)
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("Today — 650pt regular") {
  TodayView()
    .environment(WeatherStore())
    .environment(SevereWeatherStore.shared)
    .environment(ShortTermPrecipStore.shared)
    .environment(FireStore.shared)
    .frame(width: 650, height: 900)
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("Today — 700pt regular") {
  TodayView()
    .environment(WeatherStore())
    .environment(SevereWeatherStore.shared)
    .environment(ShortTermPrecipStore.shared)
    .environment(FireStore.shared)
    .frame(width: 700, height: 900)
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("Today — 1024pt regular") {
  TodayView()
    .environment(WeatherStore())
    .environment(SevereWeatherStore.shared)
    .environment(ShortTermPrecipStore.shared)
    .environment(FireStore.shared)
    .frame(width: 1024, height: 900)
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("Today — iPad Pro 11-inch (M4)") {
  TodayView()
    .environment(WeatherStore())
    .environment(SevereWeatherStore.shared)
    .environment(ShortTermPrecipStore.shared)
    .environment(FireStore.shared)
}
