import SwiftUI

/// App Store marketing compositions — open in Xcode Previews and capture at 1290×2796 (6.7").
enum AppStoreScreenshotViews {
  static let phoneSize = CGSize(width: 393, height: 852)
  static let captureScale: CGFloat = 3.29
}

struct AppStoreScreenshotToday: View {
  var body: some View {
    ZStack {
      DesignTokens.Palette.bgPrimary.ignoresSafeArea()
      WeatherBackgroundView(conditionCode: 1, isDay: true, intensity: .full)
        .ignoresSafeArea()
        .opacity(0.85)

      VStack(spacing: 20) {
        HStack {
          Text("GrokCast")
            .font(.largeTitle.bold())
          Spacer()
          Text("OLIVE BRANCH")
            .font(.caption.weight(.heavy))
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }

        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Image(systemName: "cloud.sun.fill")
            .font(.system(size: 48))
            .symbolRenderingMode(.multicolor)
          Text("72°")
            .font(DesignTokens.Typography.heroTemperature())
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        GrokCastScoreCard(
          score: GrokCastScore(value: 84, label: "Go Outside", subtitle: "Great conditions", icon: "figure.walk"),
          locationName: "Olive Branch"
        )

        VStack(alignment: .leading, spacing: 8) {
          Label("GROK'S TAKE", systemImage: "sparkles")
            .font(.caption.weight(.heavy))
            .foregroundStyle(DesignTokens.Palette.accent)
          Text("Clear morning, comfortable afternoon — sunscreen after lunch if you're outside long.")
            .font(.body.weight(.medium))
        }
        .padding(20)
        .glassCardStyle(strokeTint: DesignTokens.Palette.accent.opacity(0.35))

        Spacer(minLength: 0)
      }
      .padding(24)
      .foregroundStyle(DesignTokens.Palette.textPrimary)
    }
    .preferredColorScheme(.dark)
  }
}

struct AppStoreScreenshotRadar: View {
  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      LinearGradient(
        colors: [Color(hex: "#1a2332"), Color(hex: "#0B0D14")],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      VStack {
        Spacer()
        RoundedRectangle(cornerRadius: 16)
          .fill(.ultraThinMaterial)
          .frame(height: 120)
          .overlay {
            VStack(spacing: 8) {
              HStack {
                Image(systemName: "cloud.rain.fill")
                  .foregroundStyle(DesignTokens.Palette.radarAccent)
                Text("Radar · Reflectivity")
                  .font(.caption.weight(.semibold))
                Spacer()
                Image(systemName: "sparkles")
                  .foregroundStyle(DesignTokens.Palette.radarAccent)
              }
              ProgressView(value: 0.65)
                .tint(DesignTokens.Palette.radarProgress)
            }
            .padding()
          }
          .padding()
      }

      VStack {
        Text("FUTURE")
          .font(.caption.weight(.heavy))
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(DesignTokens.Palette.radarAccent.opacity(0.25))
          .clipShape(Capsule())
        Spacer()
      }
      .padding(.top, 60)
    }
    .preferredColorScheme(.dark)
  }
}

struct AppStoreScreenshotGrok: View {
  var body: some View {
    ZStack {
      DesignTokens.Palette.bgPrimary.ignoresSafeArea()
      VStack(alignment: .leading, spacing: 16) {
        Text("Briefing Studio")
          .font(.title.bold())
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
          screenshotTile("Today's vibe", icon: "sparkles")
          screenshotTile("What to wear", icon: "tshirt")
          screenshotTile("Walk check", icon: "figure.walk")
          screenshotTile("Week ahead", icon: "calendar")
        }
        VStack(alignment: .leading, spacing: 8) {
          Label("STORM SPOTTER ANALYSIS", systemImage: "cloud.bolt.rain.fill")
            .font(.caption.weight(.heavy))
            .foregroundStyle(DesignTokens.Palette.danger)
          Text("Scud cloud with weak rotation aloft — monitor radar for the next 30–45 minutes.")
            .font(.body)
        }
        .padding(16)
        .glassCardStyle(strokeTint: DesignTokens.Palette.danger.opacity(0.45))
        Spacer(minLength: 0)
      }
      .padding(24)
      .foregroundStyle(DesignTokens.Palette.textPrimary)
    }
    .preferredColorScheme(.dark)
  }

  private func screenshotTile(_ title: String, icon: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundStyle(DesignTokens.Palette.accent)
      Text(title)
        .font(.caption.weight(.semibold))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .glassCardStyle()
  }
}

#if DEBUG
#Preview("ASO — Today") {
  AppStoreScreenshotToday()
}

#Preview("ASO — Radar") {
  AppStoreScreenshotRadar()
}

#Preview("ASO — Grok") {
  AppStoreScreenshotGrok()
}
#endif
