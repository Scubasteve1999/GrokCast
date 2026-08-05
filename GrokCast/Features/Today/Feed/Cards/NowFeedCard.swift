import SwiftUI

struct NowFeedCard: View {
  @Environment(WeatherStore.self) private var store
  let weather: GrokCastWeather
  let score: GrokCastScore
  var onTap: () -> Void

  private var heroTemperatureColor: Color {
    if weather.currentTemp >= 72 { return DesignTokens.Palette.accentWarm }
    if weather.currentTemp <= 50 { return DesignTokens.Palette.accentCool }
    return DesignTokens.Palette.textPrimary
  }

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: DesignTokens.Spacing.space8) {
        Text(store.currentLocation?.name ?? weather.location.name)
          .font(.title2.weight(.semibold))
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .accessibilityIdentifier(DayCastAccessibility.Today.location)

        Image(systemName: weather.symbolName)
          .font(.system(size: 42))
          .symbolRenderingMode(.multicolor)

        Text(store.formatTemperatureShort(weather.currentTemp))
          .font(DesignTokens.Typography.heroTemperature())
          .foregroundStyle(heroTemperatureColor)
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .accessibilityIdentifier(DayCastAccessibility.Today.temperature)

        Text(weather.conditionText)
          .font(.title3.weight(.medium))
          .foregroundStyle(DesignTokens.Palette.textSecondary)

        HStack(spacing: DesignTokens.Spacing.space12) {
          Text("Feels like \(store.formatTemperatureShort(weather.feelsLike))")
          Text("H:\(Int(round(weather.high)))°  L:\(Int(round(weather.low)))°")
        }
        .font(.subheadline)
        .foregroundStyle(DesignTokens.Palette.textSecondary)

        HStack(spacing: DesignTokens.Spacing.space8) {
          Image(systemName: score.icon)
            .foregroundStyle(scoreAccent)
          Text("\(score.value) · \(score.label)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(DesignTokens.Palette.textPrimary)
          Spacer(minLength: 0)
          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
        .padding(.top, DesignTokens.Spacing.space4)
      }
      .frame(maxWidth: .infinity)
      .padding(DesignTokens.Spacing.space16)
      .cardStyle()
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
  let weather: GrokCastWeather
  let score: GrokCastScore
  var isGeneratingImage: Bool
  var generateImageAction: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        GrokCastScoreCard(
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
              .font(.subheadline.weight(.semibold))
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption.weight(.semibold))
              .foregroundStyle(DesignTokens.Palette.textTertiary)
          }
          .padding(DesignTokens.Spacing.space16)
          .cardStyle()
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
      TacticalCard(label: "Wind", value: "\(Int(weather.windSpeed)) mph", icon: "wind")
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
