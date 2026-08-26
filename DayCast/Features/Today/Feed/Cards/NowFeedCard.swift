import SwiftUI

/// First-glance Now: type on the photographic stage. Rain chance is a line, not a plate.
/// One condition glyph on the trailing side. City lives on `LocationChipBar`.
struct NowFeedCard: View {
  @Environment(WeatherStore.self) private var store
  let weather: DayCastWeather
  var rainLine: String? = nil
  var face: NowHeroReconcile.Face
  var onTap: () -> Void

  init(
    weather: DayCastWeather,
    rainLine: String? = nil,
    face: NowHeroReconcile.Face? = nil,
    onTap: @escaping () -> Void
  ) {
    self.weather = weather
    self.rainLine = rainLine
    self.face =
      face
      ?? NowHeroReconcile.Face(
        conditionText: weather.conditionText, symbolName: weather.symbolName)
    self.onTap = onTap
  }

  var body: some View {
    TimelineView(.everyMinute) { context in
      let now = context.date
      let stale = WidgetRelativeTime.isStale(weather.fetchedAt, relativeTo: now)
      let asOf = WidgetRelativeTime.updatedLabel(for: weather.fetchedAt, relativeTo: now)
      let heroOpacity: Double = stale ? 0.7 : 1

      Button(action: onTap) {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
          HStack(alignment: .top, spacing: DesignTokens.Spacing.space12) {
            Text(store.formatTemperatureShort(weather.currentTemp))
              .font(DesignTokens.Typography.todayTemp())
              .foregroundStyle(Color.white)
              .monospacedDigit()
              .lineLimit(1)
              .minimumScaleFactor(0.45)
              .shadow(color: .black.opacity(0.45), radius: 12, y: 3)
              .accessibilityIdentifier(DayCastAccessibility.Today.temperature)

            Spacer(minLength: 8)

            VStack(spacing: DesignTokens.Spacing.space4) {
              Image(systemName: face.symbolName)
                .font(.system(size: 56, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.white)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
                .accessibilityHidden(true)
              Text(face.conditionText)
                .font(DesignTokens.Typography.headline())
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
            }
            .frame(minWidth: 96)
          }

          Text(
            "Feels like \(store.formatTemperatureShort(weather.feelsLike))  |  H \(store.formatTemperatureShort(weather.high))  |  L \(store.formatTemperatureShort(weather.low))"
          )
          .font(DesignTokens.Typography.callout())
          .foregroundStyle(Color.white.opacity(0.95))
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.75)
          .shadow(color: .black.opacity(0.4), radius: 4, y: 1)

          if let rainLine, !rainLine.isEmpty {
            Text(rainLine)
              .font(DesignTokens.Typography.callout())
              .foregroundStyle(Color.white.opacity(0.92))
              .lineLimit(2)
              .minimumScaleFactor(0.85)
              .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
              .accessibilityIdentifier(DayCastAccessibility.Today.precip)
          }

          Text(asOf)
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(stale ? DesignTokens.Palette.warning : Color.white.opacity(0.72))
            .lineLimit(1)
            .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
            .accessibilityIdentifier(DayCastAccessibility.Today.updatedAt)
        }
        .frame(
          maxWidth: .infinity,
          minHeight: TodayGlanceLayout.nowBudgetHeight,
          alignment: .leading
        )
        .opacity(heroOpacity)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(accessibilitySummary(asOf: asOf, rainLine: rainLine))
      .accessibilityHint("Shows Now details including DayCast score")
      .accessibilityAddTraits(.isButton)
    }
  }

  private func accessibilitySummary(asOf: String, rainLine: String?) -> String {
    let place = store.currentLocation?.name ?? weather.location.name
    let temp = store.formatTemperatureShort(weather.currentTemp)
    let feels = store.formatTemperatureShort(weather.feelsLike)
    var line =
      "\(place). \(temp), \(face.conditionText). Feels like \(feels). High \(Int(round(weather.high))) degrees, low \(Int(round(weather.low)))."
    if let rainLine, !rainLine.isEmpty {
      line += " \(rainLine)."
    }
    return "\(line) \(asOf)."
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
