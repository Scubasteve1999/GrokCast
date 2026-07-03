import SwiftUI

// Apple-Weather-inspired *bright* theme, scoped to the Today tab only.
//
// This deliberately departs from the dark-first tokens in DesignSystem.md / CLAUDE.md:
// Today uses a full-bleed condition-driven *sky* backdrop with translucent frosted
// cards (Apple Weather aesthetic), while the other six tabs keep the dark palette.
// Keeping it isolated here means the design system stays the source of truth everywhere
// else. Text stays white/light because the frosted cards read as translucent-dark panels.

enum TodayBright {
  /// Text on the bright sky backdrop / frosted cards — white with descending emphasis.
  static let textPrimary = Color.white
  static let textSecondary = Color.white.opacity(0.82)
  static let textTertiary = Color.white.opacity(0.60)

  /// Frosted card surfaces.
  static let cardStroke = Color.white.opacity(0.18)
  static let cardTint = Color.white.opacity(0.10)
  static let divider = Color.white.opacity(0.15)
}

// MARK: - Sky backdrop

/// Full-bleed, condition + day/night gradient sky for the Today tab, with a soft
/// sun/moon glow. Brighter counterpart to `WeatherBackgroundView`, tuned so white
/// text and frosted cards stay legible.
struct TodaySkyBackground: View {
  let conditionCode: Int
  var isDay: Bool = true

  var body: some View {
    ZStack {
      LinearGradient(colors: skyColors, startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.0), value: conditionCode)

      if showsGlow {
        RadialGradient(
          colors: [glowColor.opacity(isDay ? 0.55 : 0.32), .clear],
          center: UnitPoint(x: 0.30, y: 0.12),
          startRadius: 0,
          endRadius: 360
        )
        .blendMode(.screen)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.0), value: conditionCode)
      }
    }
    .allowsHitTesting(false)
  }

  private enum Sky {
    case clear, partlyCloudy, overcast, fog, rain, snow, thunderstorm
  }

  private var category: Sky {
    switch conditionCode {
    case 0: return .clear
    case 1, 2: return .partlyCloudy
    case 3: return .overcast
    case 45, 48: return .fog
    case 51, 53, 55, 61, 63, 65, 66, 67, 80, 81, 82: return .rain
    case 71, 73, 75, 77, 85, 86: return .snow
    case 95, 96, 99: return .thunderstorm
    default: return .partlyCloudy
    }
  }

  private var showsGlow: Bool {
    switch category {
    case .clear, .partlyCloudy: return true
    default: return false
    }
  }

  private var glowColor: Color {
    isDay ? Color(hex: "FFE9A8") : Color(hex: "C8D4FF")
  }

  private var skyColors: [Color] {
    switch (category, isDay) {
    case (.clear, true):
      return [Color(hex: "1E63B4"), Color(hex: "3E86D6"), Color(hex: "78B0E0")]
    case (.clear, false):
      return [Color(hex: "0A1430"), Color(hex: "15224A"), Color(hex: "23315C")]
    case (.partlyCloudy, true):
      return [Color(hex: "35699E"), Color(hex: "5E8FBD"), Color(hex: "8FB4D2")]
    case (.partlyCloudy, false):
      return [Color(hex: "0E1A38"), Color(hex: "1B2A50"), Color(hex: "2B3B62")]
    case (.overcast, true):
      return [Color(hex: "51606F"), Color(hex: "6B7987"), Color(hex: "8C99A6")]
    case (.overcast, false):
      return [Color(hex: "1E2833"), Color(hex: "2C3844"), Color(hex: "3B4956")]
    case (.fog, _):
      return [Color(hex: "5E6772"), Color(hex: "808893"), Color(hex: "9EA6B0")]
    case (.rain, true):
      return [Color(hex: "324B66"), Color(hex: "466079"), Color(hex: "5E7789")]
    case (.rain, false):
      return [Color(hex: "121E30"), Color(hex: "1E2C42"), Color(hex: "2B3B54")]
    case (.snow, true):
      return [Color(hex: "6C7F94"), Color(hex: "93A6BA"), Color(hex: "BFCEDB")]
    case (.snow, false):
      return [Color(hex: "1B2536"), Color(hex: "2C3A50"), Color(hex: "3D4E66")]
    case (.thunderstorm, true):
      return [Color(hex: "2C3550"), Color(hex: "414A66"), Color(hex: "59617A")]
    case (.thunderstorm, false):
      return [Color(hex: "0C0F1C"), Color(hex: "1A1F33"), Color(hex: "2A2F48")]
    }
  }
}

// MARK: - Frosted card + text helpers

extension View {
  /// Apple-style translucent frosted panel used by every card on the bright Today tab.
  func todayGlassCard(cornerRadius: CGFloat = 20) -> some View {
    self
      .background(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(.ultraThinMaterial)
          .environment(\.colorScheme, .dark)
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(TodayBright.cardTint)
      )
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(TodayBright.cardStroke, lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
  }

  /// Soft legibility shadow for white text/glyphs floating directly on the sky.
  func skyTextShadow() -> some View {
    shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 2)
  }
}

// MARK: - Small caps section header (e.g. "☷ 10-DAY FORECAST")

struct TodaySectionHeader: View {
  let title: String
  let systemImage: String

  var body: some View {
    Label {
      Text(title)
        .font(.caption.weight(.semibold))
        .tracking(0.6)
    } icon: {
      Image(systemName: systemImage)
        .font(.caption)
    }
    .foregroundStyle(TodayBright.textTertiary)
  }
}
