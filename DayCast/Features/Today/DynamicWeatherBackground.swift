import SwiftUI

// DynamicWeatherBackground
// Simple condition-aware gradient background for Today screen.
// Follows DesignSystem colors where possible, subtle effects.
// Merged from proposed upgrade for Phase 2.

struct DynamicWeatherBackground: View {
  let conditionCode: Int?
  var isDay: Bool = true

  var body: some View {
    ZStack {
      LinearGradient(
        colors: gradientColors,
        startPoint: .top,
        endPoint: .bottom
      )
      .animation(.easeInOut(duration: 1.2), value: conditionCode)

      // Subtle effects for premium feel (clear skies sun glow, etc.)
      if isClear {
        Circle()
          .fill(Color.yellow.opacity(0.12))
          .blur(radius: 80)
          .offset(y: -120)
          .allowsHitTesting(false)
      }
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
  }

  private var isClear: Bool {
    guard let code = conditionCode else { return false }
    return code == 0 || code == 1
  }

  private var gradientColors: [Color] {
    guard let code = conditionCode else {
      return [DesignTokens.Palette.bgPrimary, DesignTokens.Palette.bgSecondary]
    }

    switch code {
    case 0, 1:  // Clear / Mostly clear
      return [Color(hex: "1E2A4A"), Color(hex: "3B4F7A")]
    case 2, 3:  // Partly / Overcast
      return [Color(hex: "1F2A3C"), Color(hex: "2C3E5A")]
    case 45, 48:  // Fog
      return [Color(hex: "2A2F3D"), Color(hex: "3A4050")]
    case 51...67, 80...82:  // Rain / Drizzle / Showers
      return [Color(hex: "1A2338"), Color(hex: "2A3A5F")]
    case 71...77, 85, 86:  // Snow
      return [Color(hex: "1C2538"), Color(hex: "2E3A55")]
    case 95...99:  // Thunderstorm
      return [Color(hex: "1A1F2E"), Color(hex: "2A3550")]
    default:
      return [DesignTokens.Palette.bgPrimary, DesignTokens.Palette.bgSecondary]
    }
  }
}
