import SwiftUI

// MARK: - Intensity

enum BackgroundIntensity {
  case full
  case subtle
}

// MARK: - Category (WMO groupings aligned with mapWeatherCode)

private enum WeatherBackgroundCategory {
  case clear
  case partlyCloudy
  case overcast
  case fog
  case rain
  case sleet
  case snow
  case thunderstorm
  case neutral

  static func from(conditionCode: Int) -> WeatherBackgroundCategory {
    switch conditionCode {
    case 0: return .clear
    case 1, 2: return .partlyCloudy
    case 3: return .overcast
    case 45, 48: return .fog
    case 51, 53, 55, 61, 63, 65, 80, 81, 82: return .rain
    case 66, 67: return .sleet
    case 71, 73, 75, 77, 85, 86: return .snow
    case 95, 96, 99: return .thunderstorm
    default: return .neutral
    }
  }
}

// MARK: - Main View

struct WeatherBackgroundView: View {
  let conditionCode: Int?
  var isDay: Bool = true
  var intensity: BackgroundIntensity = .full

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  private var category: WeatherBackgroundCategory {
    guard let code = conditionCode else { return .neutral }
    return WeatherBackgroundCategory.from(conditionCode: code)
  }

  private var isLowPower: Bool {
    ProcessInfo.processInfo.isLowPowerModeEnabled
  }

  /// All motion pauses when backgrounded, Low Power Mode, or Reduce Motion is on.
  private var shouldAnimate: Bool {
    scenePhase == .active && !reduceMotion && !isLowPower
  }

  private var showsParticles: Bool {
    guard shouldAnimate else { return false }
    return intensity == .full || intensity == .subtle
  }

  private var rainParticleCount: Int {
    intensity == .full ? 12 : 6
  }

  private var snowParticleCount: Int {
    intensity == .full ? 8 : 4
  }

  var body: some View {
    ZStack {
      staticBaseLayer

      if showsParticles {
        animatedOverlayLayer
          .drawingGroup()
          .opacity(particleOpacity)
      }
    }
    .allowsHitTesting(false)
  }

  // MARK: - Static Base (never ticks)

  private var staticBaseLayer: some View {
    ZStack {
      Color.black.opacity(blackBaseOpacity)
      gradientLayer
        .opacity(gradientOpacity)
    }
  }

  // MARK: - Layer Opacity

  private var blackBaseOpacity: Double {
    switch intensity {
    case .full: return 1.0
    case .subtle: return 0.55
    }
  }

  private var gradientOpacity: Double {
    let base: Double =
      switch intensity {
      case .full: colorScheme == .dark ? 0.92 : 0.85
      case .subtle: colorScheme == .dark ? 0.42 : 0.38
      }
    return base
  }

  private var particleOpacity: Double {
    intensity == .full ? 0.75 : 0.35
  }

  // MARK: - Gradients

  @ViewBuilder
  private var gradientLayer: some View {
    switch category {
    case .clear:
      clearGradient
    case .partlyCloudy:
      partlyCloudyGradient
    case .overcast:
      overcastGradient
    case .fog:
      fogGradient
    case .rain, .sleet:
      rainGradient
    case .snow:
      snowGradient
    case .thunderstorm:
      thunderstormGradient
    case .neutral:
      neutralTacticalGradient
    }
  }

  private var clearGradient: some View {
    LinearGradient(
      colors: isDay
        ? [
          Color(red: 0.45, green: 0.28, blue: 0.08),
          Color(red: 0.72, green: 0.42, blue: 0.12),
          Color(red: 0.18, green: 0.10, blue: 0.06),
        ]
        : [
          Color(red: 0.06, green: 0.08, blue: 0.22),
          Color(red: 0.12, green: 0.14, blue: 0.32),
          Color.black,
        ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private var partlyCloudyGradient: some View {
    LinearGradient(
      colors: [
        Color(red: 0.22, green: 0.28, blue: 0.38),
        Color(red: 0.14, green: 0.18, blue: 0.26),
        Color(red: 0.06, green: 0.08, blue: 0.12),
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  private var overcastGradient: some View {
    LinearGradient(
      colors: [
        Color(red: 0.18, green: 0.22, blue: 0.30),
        Color(red: 0.10, green: 0.13, blue: 0.20),
        Color(red: 0.04, green: 0.05, blue: 0.08),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private var fogGradient: some View {
    LinearGradient(
      colors: [
        Color(red: 0.20, green: 0.22, blue: 0.24),
        Color(red: 0.12, green: 0.13, blue: 0.15),
        Color.black,
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  private var rainGradient: some View {
    LinearGradient(
      colors: [
        Color(red: 0.08, green: 0.14, blue: 0.28),
        Color(red: 0.05, green: 0.10, blue: 0.22),
        Color(red: 0.02, green: 0.04, blue: 0.10),
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  private var snowGradient: some View {
    LinearGradient(
      colors: [
        Color(red: 0.55, green: 0.65, blue: 0.78),
        Color(red: 0.22, green: 0.30, blue: 0.42),
        Color(red: 0.06, green: 0.10, blue: 0.18),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private var thunderstormGradient: some View {
    LinearGradient(
      colors: [
        Color(red: 0.22, green: 0.12, blue: 0.32),
        Color(red: 0.10, green: 0.08, blue: 0.18),
        Color.black,
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  private var neutralTacticalGradient: some View {
    LinearGradient(
      colors: [Color(red: 0.05, green: 0.05, blue: 0.12), .black],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  // MARK: - Animated Overlays (TimelineView only when shouldAnimate)

  @ViewBuilder
  private var animatedOverlayLayer: some View {
    switch category {
    case .clear:
      ClearShimmerOverlay(isDay: isDay, intensity: intensity)
    case .partlyCloudy:
      CloudDriftOverlay(intensity: intensity)
    case .rain, .sleet:
      RainOverlay(particleCount: rainParticleCount)
    case .snow:
      SnowOverlay(particleCount: snowParticleCount)
    case .thunderstorm:
      ZStack {
        RainOverlay(particleCount: max(4, rainParticleCount / 2))
        LightningOverlay()
      }
    default:
      EmptyView()
    }
  }
}

// MARK: - Clear Shimmer

private struct ClearShimmerOverlay: View {
  let isDay: Bool
  let intensity: BackgroundIntensity

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { context in
      GeometryReader { geo in
        let time = context.date.timeIntervalSinceReferenceDate
        let pulse = sin(time * 0.35) * 0.5 + 0.5
        let drift = sin(time * 0.18) * geo.size.width * 0.03
        let shimmerOpacity = intensity == .full ? 0.22 : 0.12

        if isDay {
          Ellipse()
            .fill(
              RadialGradient(
                colors: [
                  Color(red: 1.0, green: 0.82, blue: 0.45).opacity(0.35 + pulse * 0.25),
                  Color.clear,
                ],
                center: .center,
                startRadius: 0,
                endRadius: geo.size.width * 0.35
              )
            )
            .frame(width: geo.size.width * 0.7, height: geo.size.height * 0.35)
            .offset(x: drift, y: -geo.size.height * 0.32)
            .opacity(shimmerOpacity)

          Rectangle()
            .fill(
              LinearGradient(
                colors: [
                  Color.white.opacity(0.06 + pulse * 0.08),
                  Color.clear,
                  Color.white.opacity(0.04 + pulse * 0.05),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
        } else {
          Circle()
            .fill(
              RadialGradient(
                colors: [
                  Color(red: 0.75, green: 0.82, blue: 1.0).opacity(0.18 + pulse * 0.12),
                  Color.clear,
                ],
                center: .center,
                startRadius: 0,
                endRadius: geo.size.width * 0.12
              )
            )
            .frame(width: geo.size.width * 0.18, height: geo.size.width * 0.18)
            .offset(x: geo.size.width * 0.28 + drift * 0.5, y: -geo.size.height * 0.34)
            .opacity(shimmerOpacity * 0.9)
        }
      }
    }
  }
}

// MARK: - Rain

private struct RainOverlay: View {
  let particleCount: Int

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
      GeometryReader { geo in
        let time = context.date.timeIntervalSinceReferenceDate
        ForEach(0..<particleCount, id: \.self) { index in
          let seed = Double(index + 1)
          let x = (seed * 73.7).truncatingRemainder(dividingBy: max(geo.size.width, 1))
          let speed = 90 + (seed * 17).truncatingRemainder(dividingBy: 60)
          let phase = (seed * 31.3).truncatingRemainder(dividingBy: 1)
          let y =
            ((time * speed + phase * geo.size.height).truncatingRemainder(
              dividingBy: geo.size.height + 40
            )) - 20

          Rectangle()
            .fill(Color.white.opacity(0.18 + (seed.truncatingRemainder(dividingBy: 3) * 0.06)))
            .frame(width: 1.2, height: 10 + seed.truncatingRemainder(dividingBy: 8))
            .position(x: x, y: y)
        }
      }
    }
  }
}

// MARK: - Snow

private struct SnowOverlay: View {
  let particleCount: Int

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 18.0)) { context in
      GeometryReader { geo in
        let time = context.date.timeIntervalSinceReferenceDate
        ForEach(0..<particleCount, id: \.self) { index in
          let seed = Double(index + 1)
          let xBase = (seed * 59.1).truncatingRemainder(dividingBy: max(geo.size.width, 1))
          let drift = sin(time * 0.6 + seed) * 12
          let speed = 28 + (seed * 11).truncatingRemainder(dividingBy: 22)
          let phase = (seed * 19.7).truncatingRemainder(dividingBy: 1)
          let y =
            ((time * speed + phase * geo.size.height).truncatingRemainder(
              dividingBy: geo.size.height + 24
            )) - 12
          let size = 3 + seed.truncatingRemainder(dividingBy: 4)

          Circle()
            .fill(Color.white.opacity(0.35 + seed.truncatingRemainder(dividingBy: 2) * 0.15))
            .frame(width: size, height: size)
            .position(x: xBase + drift, y: y)
        }
      }
    }
  }
}

// MARK: - Cloud Drift

private struct CloudDriftOverlay: View {
  let intensity: BackgroundIntensity

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { context in
      GeometryReader { geo in
        let time = context.date.timeIntervalSinceReferenceDate
        let drift = sin(time * 0.15) * geo.size.width * 0.04
        let cloudOpacity = intensity == .full ? 0.14 : 0.08

        Ellipse()
          .fill(Color.white.opacity(cloudOpacity))
          .frame(width: geo.size.width * 0.55, height: geo.size.height * 0.12)
          .offset(x: drift - geo.size.width * 0.08, y: -geo.size.height * 0.28)

        Ellipse()
          .fill(Color.white.opacity(cloudOpacity * 0.85))
          .frame(width: geo.size.width * 0.42, height: geo.size.height * 0.09)
          .offset(x: -drift * 0.6 + geo.size.width * 0.12, y: -geo.size.height * 0.12)
      }
    }
  }
}

// MARK: - Lightning

private struct LightningOverlay: View {
  var body: some View {
    TimelineView(.animation(minimumInterval: 0.5)) { context in
      let time = context.date.timeIntervalSinceReferenceDate
      let flashPhase = sin(time * 1.7) * sin(time * 0.31)
      let flashOpacity = max(0, flashPhase > 0.92 ? 0.22 : 0)

      Rectangle()
        .fill(
          LinearGradient(
            colors: [
              Color.purple.opacity(flashOpacity),
              Color.white.opacity(flashOpacity * 0.6),
              Color.clear,
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )
    }
  }
}

// MARK: - View Modifier

private struct WeatherBackgroundModifier: ViewModifier {
  let conditionCode: Int?
  var isDay: Bool
  var intensity: BackgroundIntensity
  var extraOpacity: Double

  func body(content: Content) -> some View {
    ZStack {
      DesignTokens.Palette.bgPrimary
        .ignoresSafeArea()

      WeatherBackgroundView(
        conditionCode: conditionCode,
        isDay: isDay,
        intensity: intensity
      )
      .ignoresSafeArea()
      .opacity(extraOpacity)
      .animation(.easeInOut(duration: 1.0), value: conditionCode)
      .allowsHitTesting(false)

      content
    }
  }
}

extension View {
  func weatherBackground(
    conditionCode: Int?,
    isDay: Bool = WeatherBackgroundView.inferredIsDay,
    intensity: BackgroundIntensity = .full,
    extraOpacity: Double = 1.0
  ) -> some View {
    modifier(
      WeatherBackgroundModifier(
        conditionCode: conditionCode,
        isDay: isDay,
        intensity: intensity,
        extraOpacity: extraOpacity
      )
    )
  }
}

extension WeatherBackgroundView {
  /// Heuristic day/night when Open-Meteo `is_day` is not on `GrokCastWeather`.
  static var inferredIsDay: Bool {
    let hour = Calendar.current.component(.hour, from: Date())
    return hour >= 6 && hour < 20
  }

  static func isDay(from symbolName: String) -> Bool {
    !symbolName.localizedCaseInsensitiveContains("moon")
  }
}

#Preview("Clear Day") {
  WeatherBackgroundView(conditionCode: 0, isDay: true, intensity: .full)
    .preferredColorScheme(.dark)
}

#Preview("Rain Subtle") {
  WeatherBackgroundView(conditionCode: 63, intensity: .subtle)
    .preferredColorScheme(.dark)
}
