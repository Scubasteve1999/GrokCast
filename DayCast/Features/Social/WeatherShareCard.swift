import SwiftUI

struct WeatherShareCard: View {
  let weather: DayCastWeather
  let score: DayCastScore
  let locationName: String
  let grokBrief: String?
  var unit: TemperatureUnit = .fahrenheit

  var body: some View {
    VStack(spacing: 0) {
      headerSection
      contentSection
      footerSection
    }
    .frame(width: 390, height: 520)
    .background(backgroundGradient)
    .clipShape(RoundedRectangle(cornerRadius: 24))
  }

  private var headerSection: some View {
    HStack {
      HStack(spacing: 6) {
        Image(systemName: "mappin.circle.fill")
          .font(DesignTokens.Typography.caption())
        Text(locationName)
          .font(DesignTokens.Typography.subsection())
      }
      Spacer()
      Text(Date.now, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
        .font(DesignTokens.Typography.caption())
    }
    .foregroundStyle(.white.opacity(0.8))
    .padding(.horizontal, 24)
    .padding(.top, 24)
    .padding(.bottom, 12)
  }

  private var contentSection: some View {
    VStack(spacing: 16) {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Image(systemName: weather.symbolName)
          .font(DesignTokens.Typography.compactTemp())
          .symbolRenderingMode(.multicolor)

        Text(unit.format(weather.currentTemp))
          .font(DesignTokens.Typography.widgetTemp(72))
          .foregroundStyle(.white)
      }

      Text(weather.conditionText)
        .font(DesignTokens.Typography.metric())
        .foregroundStyle(.white.opacity(0.9))

      HStack(spacing: 16) {
        Label("H:\(unit.formatShort(weather.high))", systemImage: "arrow.up")
        Label("L:\(unit.formatShort(weather.low))", systemImage: "arrow.down")
      }
      .font(DesignTokens.Typography.subsection())
      .foregroundStyle(.white.opacity(0.75))
      .labelStyle(.titleOnly)

      scoreRing

      if let brief = grokBrief, !brief.isEmpty {
        HStack(alignment: .top, spacing: 6) {
          Image(systemName: "sparkles")
            .font(DesignTokens.Typography.caption())
          Text(brief)
            .font(DesignTokens.Typography.caption())
            .lineLimit(2)
            .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 20)
      }
    }
    .padding(.horizontal, 24)
    .frame(maxHeight: .infinity)
  }

  private var scoreRing: some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .stroke(.white.opacity(0.2), lineWidth: 4)
          .frame(width: 44, height: 44)
        Circle()
          .trim(from: 0, to: CGFloat(score.value) / 100.0)
          .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
          .frame(width: 44, height: 44)
          .rotationEffect(.degrees(-90))
        Text("\(score.value)")
          .font(.system(.caption, design: .rounded).weight(.bold))
          .foregroundStyle(.white)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text("DayCast Score")
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(.white.opacity(0.6))
        Text(score.label)
          .font(DesignTokens.Typography.subsection())
          .foregroundStyle(.white)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(.white.opacity(0.12), in: Capsule())
  }

  private var footerSection: some View {
    HStack {
      Text("DayCast")
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(.white.opacity(0.5))
      Spacer()
      Image(systemName: "square.and.arrow.up")
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(.white.opacity(0.4))
    }
    .padding(.horizontal, 24)
    .padding(.bottom, 20)
    .padding(.top, 8)
  }

  private var backgroundGradient: some View {
    let colors: [Color] = weather.symbolName.contains("sun")
      ? [Color(red: 0.15, green: 0.35, blue: 0.75), Color(red: 0.08, green: 0.18, blue: 0.48)]
      : weather.symbolName.contains("rain") || weather.symbolName.contains("storm")
        ? [Color(red: 0.12, green: 0.15, blue: 0.28), Color(red: 0.06, green: 0.08, blue: 0.18)]
        : [Color(red: 0.18, green: 0.25, blue: 0.42), Color(red: 0.08, green: 0.12, blue: 0.25)]

    return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
  }
}

#Preview {
  WeatherShareCard(
    weather: DayCastWeather(snapshot: .preview),
    score: DayCastScore(value: 84, label: "Go Outside", subtitle: "Great conditions", icon: "figure.walk"),
    locationName: "Memphis, TN",
    grokBrief: "Light jacket this morning; great afternoon for a walk."
  )
  .padding()
  .background(Color.black)
}
