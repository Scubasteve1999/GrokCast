import SwiftUI

/// Modern dark professional background that reacts subtly to weather conditions.
/// Base is always the deep #0F0F0F. Overlays/tints are very low-opacity for premium calm feel.
/// Night always biases cooler. Designed to sit behind hero + tactical cards.
struct DynamicBackgroundView: View {
  let conditionCode: Int?
  var isDay: Bool = true

  private var isNight: Bool {
    !isDay
  }

  var body: some View {
    ZStack {
      // Deep dark base — the foundation (#0F0F0F) for all conditions.
      Color(hex: "#0F0F0F")

      // Subtle vertical depth on the base (almost imperceptible).
      depthGradient
        .opacity(0.40)

      // Condition + night reactive mood tint (very low opacity colored overlay).
      // This is where the magic happens: soft warm/cool/purple shifts.
      moodTint
        .opacity(moodOpacity)
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
  }

  // Very subtle depth gradient (same for all, just adds premium vertical interest on the deep base).
  private var depthGradient: some View {
    LinearGradient(
      colors: [Color(hex: "#0F0F0F"), Color(hex: "#0A0A0A")],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  // The weather-reactive part: low-opacity tint that shifts hue slightly.
  // Delegates to WeatherCondition (centralized; night bias + exact prior hex values preserved for no visual change).
  private var moodTint: some View {
    let hex =
      conditionCode.map { WeatherCondition(fromWMO: $0).moodTintHex(isDay: isDay) }
      ?? (isNight ? "#0B0E14" : "#0F0F0F")
    let tint = Color(hex: hex)

    // Vertical soft gradient overlay so the tint feels natural and not flat.
    return LinearGradient(
      colors: [tint.opacity(0.0), tint, tint.opacity(0.75)],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  private var moodOpacity: Double {
    // ~0.10 - 0.20 range (slightly increased visibility for premium calm effects).
    // Night gets a hair more presence for moodier feel.
    // Delegates to WeatherCondition (centralized, night bias + exact prior values).
    if let code = conditionCode {
      return WeatherCondition(fromWMO: code).moodOpacity(isNight: isNight)
    }
    return isNight ? 0.18 : 0.10
  }
}

// Hex helper provided by Shared/Design/DesignTokens.swift (central Color extension).
