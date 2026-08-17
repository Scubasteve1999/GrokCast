import SwiftUI

/// Weather Channel–style hero: location chip, huge temp, condition on the right,
/// feels/H/L line, floating on the photo-like sky (no gray slab).
struct NowFeedCard: View {
  @Environment(WeatherStore.self) private var store
  let weather: DayCastWeather
  let score: DayCastScore
  var onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        // Location chip (TWC-style pill)
        HStack(spacing: 6) {
          Image(systemName: "location.fill")
            .font(DesignTokens.Typography.micro())
          Text(store.currentLocation?.name ?? weather.location.name)
            .font(DesignTokens.Typography.symbol(16))
            .lineLimit(1)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.38), in: Capsule())
        .accessibilityIdentifier(DayCastAccessibility.Today.location)

        // Hero row: giant temp | icon + condition
        HStack(alignment: .center, spacing: DesignTokens.Spacing.space12) {
          Text(store.formatTemperatureShort(weather.currentTemp))
            .font(DesignTokens.Typography.displayTemp())
            .foregroundStyle(Color.white)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.45)
            .shadow(color: .black.opacity(0.35), radius: 10, y: 3)
            .accessibilityIdentifier(DayCastAccessibility.Today.temperature)

          Spacer(minLength: 8)

          VStack(spacing: 8) {
            Image(systemName: weather.symbolName)
              .font(DesignTokens.Typography.widgetTemp(52))
              .symbolRenderingMode(.monochrome)
              .foregroundStyle(Color.white)
              .shadow(color: .black.opacity(0.25), radius: 6, y: 2)

            Text(weather.conditionText)
              .font(DesignTokens.Typography.headline())
              .foregroundStyle(Color.white)
              .multilineTextAlignment(.center)
              .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
          }
          .frame(minWidth: 100)
        }

        Text(
          "Feels like \(store.formatTemperatureShort(weather.feelsLike))  |  H \(store.formatTemperatureShort(weather.high))  |  L \(store.formatTemperatureShort(weather.low))"
        )
        .font(DesignTokens.Typography.headline())
        .foregroundStyle(Color.white.opacity(0.95))
        .monospacedDigit()
        .shadow(color: .black.opacity(0.3), radius: 4, y: 1)

        // Score chip under hero (our product surface — still elevated)
        HStack(spacing: DesignTokens.Spacing.space8) {
          Image(systemName: score.icon)
            .font(DesignTokens.Typography.headline())
            .foregroundStyle(scoreAccent)
          Text("\(score.value) · \(score.label)")
            .font(DesignTokens.Typography.subsection())
            .foregroundStyle(Color.white)
          Spacer(minLength: 0)
          Image(systemName: "chevron.right")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(Color.white.opacity(0.55))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.40), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, DesignTokens.Spacing.space4)
      .padding(.top, DesignTokens.Spacing.space8)
      .padding(.bottom, DesignTokens.Spacing.space12)
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilitySummary)
    .accessibilityAddTraits(.isButton)
  }

  private var scoreAccent: Color {
    switch score.accentTier {
    case .great: DesignTokens.Palette.success
    case .okay: DesignTokens.Palette.accentWarm
    case .poor: DesignTokens.Palette.danger
    }
  }

  private var accessibilitySummary: String {
    let place = store.currentLocation?.name ?? weather.location.name
    let temp = store.formatTemperatureShort(weather.currentTemp)
    let feels = store.formatTemperatureShort(weather.feelsLike)
    return
      "\(place). \(temp), \(weather.conditionText). Feels like \(feels). High \(Int(round(weather.high))) degrees, low \(Int(round(weather.low))). DayCast score \(score.value), \(score.label)."
  }
}

struct NowDetailView: View {
  @Environment(WeatherStore.self) private var store
  let weather: DayCastWeather
  let score: DayCastScore
  var isGeneratingImage: Bool
  var generateImageAction: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        DayCastScoreCard(
          score: score,
          locationName: store.currentLocation?.name ?? weather.location.name,
          layout: .figma
        )

        detailsGrid

        NavigationLink {
          TripPlannerView()
        } label: {
          HStack {
            Label("Trip Weather Planner", systemImage: "airplane.departure")
              .font(DesignTokens.Typography.callout())
            Spacer()
            Image(systemName: "chevron.right")
              .font(DesignTokens.Typography.caption())
              .foregroundStyle(DesignTokens.Palette.textTertiary)
          }
          .padding(DesignTokens.Spacing.space16)
          .cardStyle(elevated: true)
        }
        .buttonStyle(.plain)

        GrokImagineButton(
          weather: weather,
          isGenerating: isGeneratingImage,
          action: generateImageAction
        )
      }
      .padding(DesignTokens.Spacing.space20)
      .padding(.bottom, DesignTokens.Layout.tabBarScrollClearance)
    }
    .background(DesignTokens.Palette.bgPrimary.ignoresSafeArea())
    .navigationTitle("Now")
    .navigationBarTitleDisplayMode(.inline)
    .preferredColorScheme(.dark)
  }

  private var detailsGrid: some View {
    let precipValue: String = {
      let c = weather.precipitationChance
      return "\(c)%"
    }()

    return LazyVGrid(
      columns: [GridItem(.flexible()), GridItem(.flexible())],
      spacing: DesignTokens.Spacing.space16
    ) {
      TacticalCard(label: "Humidity", value: "\(weather.humidity)%", icon: "humidity")
      TacticalCard(label: "Wind", value: store.formatWindSpeed(weather.windSpeed), icon: "wind")
      TacticalCard(label: "UV Index", value: "\(Int(weather.uvIndex))", icon: "sun.max")
      TacticalCard(label: "Precip", value: precipValue, icon: weather.symbolName)
      if let aqi = weather.airQualityIndex {
        TacticalCard(label: "AQI", value: "\(aqi)", icon: "aqi.medium")
      }
      if let pollen = weather.pollenLevel {
        TacticalCard(label: "Pollen", value: pollen, icon: "leaf")
      }
    }
  }
}
