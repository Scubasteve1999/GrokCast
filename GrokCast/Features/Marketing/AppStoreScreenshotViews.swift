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
          Text("SpotterCast")
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

struct AppStoreScreenshotWidgets: View {
  var body: some View {
    ZStack {
      DesignTokens.Palette.bgPrimary.ignoresSafeArea()
      VStack(spacing: 24) {
        Text("Widgets Everywhere")
          .font(.title.bold())
          .frame(maxWidth: .infinity, alignment: .leading)

        VStack(alignment: .leading, spacing: 12) {
          Label("HOME SCREEN", systemImage: "square.grid.2x2")
            .font(.caption.weight(.heavy))
            .foregroundStyle(DesignTokens.Palette.accent)
          Text("Small, Medium, and Large widgets with live temperature, daily forecast, and Grok AI insights.")
            .font(.body)
        }
        .padding(16)
        .glassCardStyle()

        VStack(alignment: .leading, spacing: 12) {
          Label("LOCK SCREEN", systemImage: "lock.rectangle.stack.fill")
            .font(.caption.weight(.heavy))
            .foregroundStyle(DesignTokens.Palette.accentCool)
          Text("Circular gauge, rectangular forecast, and inline conditions — always visible at a glance.")
            .font(.body)
        }
        .padding(16)
        .glassCardStyle()

        VStack(alignment: .leading, spacing: 12) {
          Label("APPLE WATCH", systemImage: "applewatch")
            .font(.caption.weight(.heavy))
            .foregroundStyle(DesignTokens.Palette.accentWarm)
          Text("Temperature range gauge, AI brief, and GrokCast Score right on your wrist.")
            .font(.body)
        }
        .padding(16)
        .glassCardStyle()

        Spacer(minLength: 0)
      }
      .padding(24)
      .foregroundStyle(DesignTokens.Palette.textPrimary)
    }
    .preferredColorScheme(.dark)
  }
}

struct AppStoreScreenshotAlerts: View {
  var body: some View {
    ZStack {
      DesignTokens.Palette.bgPrimary.ignoresSafeArea()
      VStack(alignment: .leading, spacing: 20) {
        Text("Severe Weather Alerts")
          .font(.title.bold())

        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.title2)
              .foregroundStyle(DesignTokens.Palette.danger)
            VStack(alignment: .leading) {
              Text("TORNADO WARNING")
                .font(.caption.weight(.black))
              Text("DeSoto County, MS · Expires in 45m")
                .font(.caption2)
                .foregroundStyle(DesignTokens.Palette.textSecondary)
            }
          }
          Text("TAKE SHELTER NOW. Move to an interior room on the lowest floor of a sturdy building. Avoid windows.")
            .font(.caption)
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
        .padding(16)
        .background(DesignTokens.Palette.danger.opacity(0.1))
        .cardStyle(stroke: DesignTokens.Palette.danger.opacity(0.4))

        VStack(alignment: .leading, spacing: 8) {
          Label("TIME-SENSITIVE ALERTS", systemImage: "bell.badge.fill")
            .font(.caption.weight(.heavy))
            .foregroundStyle(DesignTokens.Palette.danger)
          Text("Warnings and watches use iOS time-sensitive notifications so severe weather reaches you promptly when alerts are enabled.")
            .font(.body)
        }
        .padding(16)
        .glassCardStyle()

        VStack(alignment: .leading, spacing: 8) {
          Label("AI MORNING BRIEF", systemImage: "sunrise.fill")
            .font(.caption.weight(.heavy))
            .foregroundStyle(DesignTokens.Palette.accentWarm)
          Text("\"Light jacket this morning — great afternoon for a walk. UV peaks around 2pm, sunscreen if you'll be outside.\"")
            .font(.body.italic())
        }
        .padding(16)
        .glassCardStyle()

        Spacer(minLength: 0)
      }
      .padding(24)
      .foregroundStyle(DesignTokens.Palette.textPrimary)
    }
    .preferredColorScheme(.dark)
  }
}

#if DEBUG
enum MarketingScreenshotMode: String {
  case today
  case radar
  case grok
  case widgets
  case alerts
}

/// Launch with: `-MarketingScreenshot today|radar|grok` (used by Scripts/capture_aso_screenshots.sh).
struct MarketingScreenshotLauncher: View {
  private var mode: MarketingScreenshotMode {
    let args = ProcessInfo.processInfo.arguments
    guard let flagIndex = args.firstIndex(of: "-MarketingScreenshot"),
      flagIndex + 1 < args.count,
      let parsed = MarketingScreenshotMode(rawValue: args[flagIndex + 1])
    else { return .today }
    return parsed
  }

  var body: some View {
    Group {
      switch mode {
      case .today: AppStoreScreenshotToday()
      case .radar: AppStoreScreenshotRadar()
      case .grok: AppStoreScreenshotGrok()
      case .widgets: AppStoreScreenshotWidgets()
      case .alerts: AppStoreScreenshotAlerts()
      }
    }
    .preferredColorScheme(.dark)
  }
}

#Preview("ASO — Today") {
  AppStoreScreenshotToday()
}

#Preview("ASO — Radar") {
  AppStoreScreenshotRadar()
}

#Preview("ASO — Grok") {
  AppStoreScreenshotGrok()
}

#Preview("ASO — Widgets") {
  AppStoreScreenshotWidgets()
}

#Preview("ASO — Alerts") {
  AppStoreScreenshotAlerts()
}
#endif
