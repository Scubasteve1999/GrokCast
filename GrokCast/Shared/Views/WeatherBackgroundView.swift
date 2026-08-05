import SwiftUI

// MARK: - Intensity

enum BackgroundIntensity {
  case full
  case subtle
  /// Static gradient only — default for calm DayCast UI.
  case staticOnly
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
  var intensity: BackgroundIntensity = .staticOnly

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
    // Calm redesign: no perpetual particle theater on main surfaces.
    guard shouldAnimate else { return false }
    return intensity == .full
  }

  private var rainParticleCount: Int {
    intensity == .full ? 8 : 0
  }

  private var snowParticleCount: Int {
    intensity == .full ? 6 : 0
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

  // MARK: - Static Base (TWC-style immersive sky — no particle theater)

  private var staticBaseLayer: some View {
    GeometryReader { geo in
      ZStack {
        // Full-bleed sky (Weather Channel “live look” is mostly a rich sky plate).
        skyPlate
          .opacity(skyOpacity)

        // Soft sun / moon for clear & partly cloudy.
        if category == .clear || category == .partlyCloudy {
          celestialGlow(in: geo.size)
        }

        // Static cloud banks — broadcast weather, not animated fluff.
        if category == .partlyCloudy || category == .overcast || category == .rain
          || category == .sleet || category == .thunderstorm
        {
          staticCloudDeck(in: geo.size)
        }

        if category == .fog {
          fogVeil
        }

        if category == .rain || category == .sleet {
          rainCurtain
        }

        // Light bottom fade only — TWC keeps most of the sky photo bright behind the hero.
        LinearGradient(
          colors: [
            Color.clear,
            Color.clear,
            Color.black.opacity(0.25),
            Color.black.opacity(0.55),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      }
    }
  }

  private var skyOpacity: Double {
    switch intensity {
    case .full: return 1.0
    case .subtle: return 0.72
    case .staticOnly: return 0.92
    }
  }

  private var particleOpacity: Double {
    intensity == .full ? 0.35 : 0
  }

  // MARK: - Sky plates (condition colors)

  @ViewBuilder
  private var skyPlate: some View {
    switch category {
    case .clear:
      LinearGradient(
        colors: isDay
          ? [
            Color(red: 0.25, green: 0.55, blue: 0.95),
            Color(red: 0.40, green: 0.68, blue: 0.98),
            Color(red: 0.55, green: 0.75, blue: 0.95),
            Color(red: 0.18, green: 0.35, blue: 0.62),
          ]
          : [
            Color(red: 0.04, green: 0.06, blue: 0.18),
            Color(red: 0.08, green: 0.12, blue: 0.32),
            Color(red: 0.12, green: 0.14, blue: 0.28),
            Color(red: 0.02, green: 0.03, blue: 0.10),
          ],
        startPoint: .top,
        endPoint: .bottom
      )
    case .partlyCloudy:
      // Match TWC: deep blue sky plate under wispy cirrus texture.
      LinearGradient(
        colors: isDay
          ? [
            Color(red: 0.22, green: 0.42, blue: 0.72),
            Color(red: 0.30, green: 0.52, blue: 0.82),
            Color(red: 0.38, green: 0.58, blue: 0.86),
            Color(red: 0.28, green: 0.48, blue: 0.78),
          ]
          : [
            Color(red: 0.08, green: 0.10, blue: 0.22),
            Color(red: 0.14, green: 0.16, blue: 0.28),
            Color(red: 0.10, green: 0.12, blue: 0.20),
          ],
        startPoint: .top,
        endPoint: .bottom
      )
    case .overcast:
      LinearGradient(
        colors: [
          Color(red: 0.42, green: 0.46, blue: 0.52),
          Color(red: 0.28, green: 0.32, blue: 0.38),
          Color(red: 0.16, green: 0.18, blue: 0.22),
          Color(red: 0.08, green: 0.09, blue: 0.11),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    case .fog:
      LinearGradient(
        colors: [
          Color(red: 0.55, green: 0.58, blue: 0.62),
          Color(red: 0.38, green: 0.40, blue: 0.44),
          Color(red: 0.20, green: 0.22, blue: 0.25),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    case .rain, .sleet:
      LinearGradient(
        colors: [
          Color(red: 0.18, green: 0.28, blue: 0.42),
          Color(red: 0.12, green: 0.20, blue: 0.34),
          Color(red: 0.08, green: 0.12, blue: 0.22),
          Color(red: 0.04, green: 0.06, blue: 0.12),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    case .snow:
      LinearGradient(
        colors: [
          Color(red: 0.55, green: 0.62, blue: 0.75),
          Color(red: 0.38, green: 0.45, blue: 0.58),
          Color(red: 0.20, green: 0.26, blue: 0.36),
          Color(red: 0.10, green: 0.12, blue: 0.18),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    case .thunderstorm:
      LinearGradient(
        colors: [
          Color(red: 0.18, green: 0.14, blue: 0.32),
          Color(red: 0.12, green: 0.16, blue: 0.28),
          Color(red: 0.08, green: 0.08, blue: 0.16),
          Color(red: 0.03, green: 0.03, blue: 0.08),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    case .neutral:
      LinearGradient(
        colors: [
          Color(red: 0.16, green: 0.22, blue: 0.34),
          Color(red: 0.08, green: 0.10, blue: 0.16),
          Color(red: 0.04, green: 0.05, blue: 0.08),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    }
  }

  private func celestialGlow(in size: CGSize) -> some View {
    let orb = isDay
      ? Color(red: 1.0, green: 0.92, blue: 0.55)
      : Color(red: 0.85, green: 0.90, blue: 1.0)
    return ZStack {
      Circle()
        .fill(
          RadialGradient(
            colors: [orb.opacity(isDay ? 0.55 : 0.25), Color.clear],
            center: .center,
            startRadius: 0,
            endRadius: size.width * 0.42
          )
        )
        .frame(width: size.width * 0.85, height: size.width * 0.85)
        .offset(x: size.width * 0.18, y: -size.height * 0.28)
      Circle()
        .fill(orb.opacity(isDay ? 0.85 : 0.35))
        .frame(width: isDay ? 56 : 36, height: isDay ? 56 : 36)
        .blur(radius: isDay ? 1 : 0.5)
        .offset(x: size.width * 0.22, y: -size.height * 0.26)
    }
    .allowsHitTesting(false)
  }

  /// Wispy cirrus / streaked cloud field like TWC photo skies (static Canvas).
  private func staticCloudDeck(in size: CGSize) -> some View {
    let heavy = category == .overcast || category == .thunderstorm
    return Canvas { context, canvasSize in
      // Diagonal streak field (high cloud texture).
      for i in 0..<28 {
        let t = CGFloat(i) / 28
        var path = Path()
        let y = canvasSize.height * (0.05 + t * 0.55)
        let x0 = -canvasSize.width * 0.15 + CGFloat(i % 5) * 18
        path.move(to: CGPoint(x: x0, y: y))
        path.addQuadCurve(
          to: CGPoint(x: canvasSize.width * 1.15, y: y + canvasSize.height * 0.08),
          control: CGPoint(x: canvasSize.width * 0.45, y: y - 24 + CGFloat(i % 3) * 10)
        )
        context.stroke(
          path,
          with: .color(.white.opacity(heavy ? 0.10 : 0.14 + Double(i % 4) * 0.02)),
          style: StrokeStyle(lineWidth: heavy ? 28 : 18 + CGFloat(i % 5) * 3, lineCap: .round)
        )
      }
      // Soft billows
      for i in 0..<8 {
        let rect = CGRect(
          x: CGFloat(i) * canvasSize.width * 0.18 - 40,
          y: canvasSize.height * (0.08 + CGFloat(i % 3) * 0.07),
          width: canvasSize.width * 0.55,
          height: canvasSize.height * 0.12
        )
        context.fill(
          Path(ellipseIn: rect),
          with: .color(.white.opacity(heavy ? 0.12 : 0.08))
        )
      }
    }
    .blur(radius: heavy ? 18 : 12)
    .opacity(heavy ? 0.85 : 0.95)
    .allowsHitTesting(false)
  }

  private var fogVeil: some View {
    LinearGradient(
      colors: [
        Color.white.opacity(0.08),
        Color.white.opacity(0.22),
        Color.white.opacity(0.10),
      ],
      startPoint: .top,
      endPoint: .bottom
    )
    .blur(radius: 8)
    .allowsHitTesting(false)
  }

  private var rainCurtain: some View {
    LinearGradient(
      colors: [
        Color(red: 0.15, green: 0.25, blue: 0.40).opacity(0.0),
        Color(red: 0.10, green: 0.18, blue: 0.32).opacity(0.35),
        Color(red: 0.05, green: 0.08, blue: 0.16).opacity(0.55),
      ],
      startPoint: .top,
      endPoint: .bottom
    )
    .allowsHitTesting(false)
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

struct WeatherBackgroundLayer: View {
  let conditionCode: Int?
  var isDay: Bool = WeatherBackgroundView.inferredIsDay
  var intensity: BackgroundIntensity = .staticOnly
  var extraOpacity: Double = 1.0

  var body: some View {
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
      .animation(.easeInOut(duration: 0.35), value: conditionCode)
    }
    .allowsHitTesting(false)
  }
}

extension WeatherBackgroundView {
  /// Heuristic day/night when Open-Meteo `is_day` is not on `GrokCastWeather`.
  static var inferredIsDay: Bool {
    inferredIsDay(timeZone: .current)
  }

  /// Day/night heuristic using the location timezone when available.
  static func inferredIsDay(timeZone: TimeZone) -> Bool {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let hour = calendar.component(.hour, from: Date())
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
