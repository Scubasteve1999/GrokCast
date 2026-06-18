import SwiftUI

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
        WeatherBackgroundView(
          conditionCode: store.currentWeather?.conditionCode,
          isDay: store.currentWeather.map {
            WeatherBackgroundView.isDay(from: $0.symbolName)
          } ?? WeatherBackgroundView.inferredIsDay,
          intensity: .full
        )
        .ignoresSafeArea()

        let status = store.locationService.authorizationStatus
        if !store.hasRequestedLocationPermission {
          // First-launch onboarding welcome (Today tab). Shown *only* on true first launch
          // (flag false + typically .notDetermined). "Get Started" presents the short
          // friendly explanation sheet (once) before any iOS prompt. After grant + load,
          // the reactive status + flag flip + existing skeleton/data paths give a smooth
          // transition to the normal Today UI. Build directly on the welcome state added
          // in empty-states work; uses identical TacticalCard styling + Haptic.
          firstLaunchWelcome()
        } else if !(status == .authorizedWhenInUse || status == .authorizedAlways) {
          LocationPermissionView()
        } else if store.isLoadingWeather || store.locationService.isLoading {  // --skeletons: shimmer for NWS primary loading states (Today, Forecast, Alerts)
          TodaySkeleton()
        } else if let w = weather {
          ScrollView {
            TodayWeatherPanel(
              weather: w,
              isGeneratingImage: isGeneratingImage,
              generateImageAction: generateImageForToday
            )
            .padding(.horizontal, 20)
            .padding(.top, 80)
            .padding(.bottom, 60)
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
                    .foregroundStyle(.secondary)
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
                  .foregroundStyle(.red)
                  Text(store.weatherError ?? "")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                  Spacer(minLength: 8)
                  Button("Retry") {
                    Haptic.impact(.medium)
                    Task { await store.useCurrentDeviceLocation() }
                  }
                  .font(.caption.bold())
                  .buttonStyle(.bordered)
                  .tint(.red)
                  .controlSize(.small)
                }
                .padding(8)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
              } else {
                Button("USE MY POSITION") {
                  Haptic.impact(.medium)
                  Task { await store.useCurrentDeviceLocation() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo.opacity(0.7))
              }
            }
            // TacticalCard-inspired styling for the actions container (pure empty or error state).
            .padding(16)
            .background(Color.white.opacity(0.06))
            .overlay(
              RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
          }
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
          .foregroundStyle(.secondary)
        Text("Welcome to GrokCast")
          .font(.title2.weight(.semibold))
        Text(
          "Your AI-powered weather companion. Get accurate, localized forecasts with smart insights."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)
        Button("Get Started") {
          Haptic.impact(.medium)
          showPermissionExplanation = true
        }
        .buttonStyle(.borderedProminent)
        .tint(.indigo.opacity(0.7))
      }
      .padding(16)
      .background(Color.white.opacity(0.06))
      .overlay(
        RoundedRectangle(cornerRadius: 14)
          .stroke(Color.white.opacity(0.1), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 14))
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
        .foregroundStyle(.white)
      VStack(spacing: 12) {
        Text("GrokCast uses your location to show accurate weather forecasts for where you are.")
          .font(.body)
          .multilineTextAlignment(.center)
        Text("Your location is only used for weather — we don’t track or store it.")
          .font(.body)
          .multilineTextAlignment(.center)
          .foregroundStyle(.secondary)
      }
      Button("Continue") {
        Haptic.impact(.medium)
        store.markLocationPermissionRequested()
        store.locationService.requestLocationPermission()
        showPermissionExplanation = false
      }
      .buttonStyle(.borderedProminent)
      .tint(.indigo.opacity(0.7))
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var backgroundGradient: some View {
    LinearGradient(
      colors: [Color.blue.opacity(0.85), Color.indigo.opacity(0.9)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
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
    VStack(spacing: 32) {
      header

      if !store.displayableActiveAlerts.isEmpty {
        alertsSection
      }

      if !awaitsWidthMeasurement && prefersTwoColumnLayout {
        HStack(alignment: .top, spacing: 20) {
          heroCard
            .frame(maxWidth: .infinity)

          VStack(spacing: 20) {
            tacticalDetailsGrid
            GrokImagineButton(
              weather: weather,
              isGenerating: isGeneratingImage,
              action: generateImageAction
            )
          }
          .frame(maxWidth: .infinity)
        }
      } else {
        heroCard
        tacticalDetailsGrid
        GrokImagineButton(
          weather: weather,
          isGenerating: isGeneratingImage,
          action: generateImageAction
        )
      }

      errorBanner

      Button {
        Haptic.impact(.medium)
        Task { await store.refreshWeather() }
      } label: {
        Label("REFRESH DATA", systemImage: "arrow.clockwise")
          .font(.footnote.weight(.semibold))
          .tracking(1.5)
      }
      .buttonStyle(.bordered)
      .tint(.white.opacity(0.6))
      .padding(.top, 12)
    }
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 2) {
        Text((store.currentLocation?.name ?? "—").uppercased())
          .font(.system(size: 15, weight: .heavy, design: .rounded))
          .tracking(2)
          .foregroundStyle(.white.opacity(0.9))

        Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
      }
      Spacer()

      Text("\(weather.fetchedAt, format: .dateTime.hour().minute())")
        .font(.caption2.monospaced())
        .foregroundStyle(.secondary)
    }
  }

  private var heroCard: some View {
    VStack(spacing: 8) {
      Image(systemName: weather.symbolName)
        .font(.system(size: 72))
        .foregroundStyle(.white)
        .symbolEffect(.pulse, options: .repeating)

      Text("\(Int(round(weather.currentTemp)))°")
        .font(.system(size: 108, weight: .black, design: .rounded))
        .foregroundStyle(.white)
        .monospacedDigit()

      Text(weather.conditionText.uppercased())
        .font(.title3.weight(.bold))
        .tracking(3)
        .foregroundStyle(.white.opacity(0.85))

      HStack(spacing: 28) {
        VStack {
          Text("HIGH").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
          Text("\(Int(round(weather.high)))°").font(.title2.weight(.semibold))
        }
        VStack {
          Text("LOW").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
          Text("\(Int(round(weather.low)))°").font(.title2.weight(.semibold))
        }
      }
      .foregroundStyle(.white)
    }
    .padding(.vertical, 24)
    .frame(maxWidth: .infinity)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
  }

  private var tacticalDetailsGrid: some View {
    let precipValue: String = {
      let c = weather.precipitationChance
      if let d0 = weather.daily.first {
        let liq = (d0.rainSum ?? 0) + (d0.showersSum ?? 0)
        let sn = d0.snowfallSum ?? 0
        if let amtLabel = precipAmountLabel(liquid: liq, snow: sn) {
          return "\(c)% \(amtLabel)"
        }
      }
      return "\(c)%"
    }()

    return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
      TacticalCard(
        label: "FEELS LIKE", value: "\(Int(round(weather.feelsLike)))°", icon: "thermometer.medium")
      TacticalCard(label: "HUMIDITY", value: "\(weather.humidity)%", icon: "humidity")
      TacticalCard(label: "WIND", value: "\(Int(weather.windSpeed)) MPH", icon: "wind")
      TacticalCard(label: "UV INDEX", value: "\(Int(weather.uvIndex))", icon: "sun.max")
      TacticalCard(label: "PRECIP", value: precipValue, icon: weather.symbolName)
      if let aqi = weather.airQualityIndex {
        TacticalCard(label: "AQI", value: "\(aqi)", icon: "aqi.medium")
      }
      if let pollen = weather.pollenLevel {
        TacticalCard(label: "POLLEN", value: pollen, icon: "leaf")
      }
      if let obs = store.currentNWSObservation {
        let tempStr = obs.temperatureF.map { "\(Int(round($0)))°" } ?? "—"
        TacticalCard(
          label: "NWS", value: "\(obs.stationId) \(tempStr)",
          icon: "antenna.radiowaves.left.and.right")
      }
    }
  }

  private var alertsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(store.displayableActiveAlerts.prefix(3)) { alert in
        HStack(spacing: 10) {
          Image(systemName: NWSAlertStyle.iconName(for: alert))
            .font(.title3)
            .foregroundStyle(NWSAlertStyle.tint(for: alert))

          VStack(alignment: .leading, spacing: 4) {
            Text(alert.event.uppercased())
              .font(.caption.weight(.bold))
              .foregroundStyle(.white)

            if let headline = alert.headline, !headline.isEmpty {
              Text(headline)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
            }

            if let area = alert.areaDesc, !area.isEmpty {
              Text(area)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
            }

            if let instr = alert.instruction, !instr.isEmpty {
              Text(instr)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(2)
                .padding(.top, 2)
            }
          }

          Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.06))
        .overlay(
          RoundedRectangle(cornerRadius: 14)
            .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
      }
    }
  }

  @ViewBuilder
  private var errorBanner: some View {
    if let error = store.weatherError, !error.isEmpty {
      HStack(spacing: 8) {
        Image(
          systemName: store.isOffline ? "wifi.slash" : "exclamationmark.triangle.fill"
        )
        .foregroundStyle(.red)
        Text(error)
          .font(.caption)
          .foregroundStyle(.red)
          .lineLimit(2)
        Spacer(minLength: 8)
        Button("Retry") {
          Haptic.impact(.medium)
          Task { await store.refreshWeather() }
        }
        .font(.caption.bold())
        .buttonStyle(.bordered)
        .tint(.red)
        .controlSize(.small)
      }
      .padding(8)
      .background(Color.red.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }
}

struct TacticalCard: View {
  let label: String
  let value: String
  let icon: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.caption)
        Text(label)
          .font(.system(size: 10, weight: .heavy))
          .tracking(1)
      }
      .foregroundStyle(.white.opacity(0.5))

      Text(value)
        .font(.system(size: 28, weight: .black, design: .rounded))
        .foregroundStyle(.white)
        .monospacedDigit()
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white.opacity(0.06))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.white.opacity(0.1), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }
}

struct GrokImagineButton: View {
  let weather: GrokCastWeather
  let isGenerating: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack {
        if isGenerating {
          ProgressView()
            .tint(.white)
          Text("GENERATING...")
        } else {
          Label("GENERATE WHAT TODAY LOOKS LIKE", systemImage: "sparkles.rectangle.stack")
        }
      }
      .font(.footnote.weight(.semibold))
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .tint(.indigo.opacity(0.7))
    .padding(.top, 8)
    .disabled(isGenerating)
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
        .padding(.horizontal, 20)
        .padding(.top, 80)
        .padding(.bottom, 60)
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
    VStack(spacing: 32) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 2) {
          ShimmerBlock(width: 180, height: 16, cornerRadius: 4)
          ShimmerBlock(width: 120, height: 12, cornerRadius: 3)
        }
        Spacer()
        ShimmerBlock(width: 60, height: 12, cornerRadius: 3)
      }

      if !awaitsWidthMeasurement && prefersTwoColumnLayout {
        HStack(alignment: .top, spacing: 20) {
          HeroSkeleton(includeHorizontalPadding: false)
            .frame(maxWidth: .infinity)

          VStack(spacing: 20) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
              ForEach(0..<8, id: \.self) { _ in
                TacticalCardSkeleton()
              }
            }

            ShimmerBlock(width: nil, height: 44, cornerRadius: 10)
          }
          .frame(maxWidth: .infinity)
        }
      } else {
        HeroSkeleton(includeHorizontalPadding: false)

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
          ForEach(0..<8, id: \.self) { _ in
            TacticalCardSkeleton()
          }
        }

        ShimmerBlock(width: nil, height: 44, cornerRadius: 10)
          .padding(.top, 8)
      }

      ShimmerBlock(width: 140, height: 36, cornerRadius: 8)
        .padding(.top, 12)
    }
  }
}

struct HeroSkeleton: View {
  var includeHorizontalPadding: Bool = true

  var body: some View {
    VStack(spacing: 8) {
      // Icon placeholder
      ShimmerBlock(width: 80, height: 80, cornerRadius: 12)

      // Huge temperature
      ShimmerBlock(width: 220, height: 90, cornerRadius: 12)

      // Condition
      ShimmerBlock(width: 160, height: 22, cornerRadius: 6)

      // High / Low
      HStack(spacing: 40) {
        VStack(spacing: 4) {
          ShimmerBlock(width: 40, height: 12, cornerRadius: 3)
          ShimmerBlock(width: 50, height: 20, cornerRadius: 4)
        }
        VStack(spacing: 4) {
          ShimmerBlock(width: 40, height: 12, cornerRadius: 3)
          ShimmerBlock(width: 50, height: 20, cornerRadius: 4)
        }
      }
    }
    .padding(.vertical, 24)
    .frame(maxWidth: .infinity)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    .padding(.horizontal, includeHorizontalPadding ? 20 : 0)
  }
}

struct TacticalCardSkeleton: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 6) {
        ShimmerBlock(width: 14, height: 14, cornerRadius: 3)
        ShimmerBlock(width: 70, height: 10, cornerRadius: 2)
      }

      ShimmerBlock(width: 110, height: 32, cornerRadius: 6)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white.opacity(0.06))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.white.opacity(0.1), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 14))
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
