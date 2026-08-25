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
          Text("DayCast")
            .font(.largeTitle.bold())
          Spacer()
          Text("Olive Branch")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }

        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Image(systemName: "cloud.sun.fill")
            .font(DesignTokens.Typography.symbol(48))
            .symbolRenderingMode(.multicolor)
          Text("72°")
            .font(DesignTokens.Typography.heroTemperature())
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        DayCastScoreCard(
          score: DayCastScore(value: 84, label: "Go Outside", subtitle: "Great conditions", icon: "figure.walk"),
          locationName: "Olive Branch"
        )

        VStack(alignment: .leading, spacing: 8) {
          Label("TODAY'S TAKE", systemImage: "sparkles")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.accent)
          Text("Clear morning, comfortable afternoon — sunscreen after lunch if you're outside long.")
            .font(DesignTokens.Typography.headline())
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
                  .font(DesignTokens.Typography.caption())
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
        Text("Future")
          .font(DesignTokens.Typography.caption())
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
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        Text("Sky Check")
          .font(DesignTokens.Typography.title())
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
          Label("Sky Check", systemImage: "cloud.bolt.fill")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.accent)
          ZStack {
            Image("NewsHeroDawn")
              .resizable()
              .scaledToFill()
              .frame(maxWidth: .infinity)
              .frame(height: DesignTokens.Spacing.space48 * 3, alignment: .top)
              .clipped()
            Label("Check this sky", systemImage: "photo")
              .font(DesignTokens.Typography.subsection())
              .foregroundStyle(DesignTokens.Palette.textPrimary)
          }
          .clipShape(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
          )
          Text(SkyCheckDeskCopy.emptyPitch)
            .font(DesignTokens.Typography.body())
        }
        .padding(DesignTokens.Spacing.space16)
        .glassCardStyle(strokeTint: DesignTokens.Palette.cardStroke)
        HStack(spacing: DesignTokens.Spacing.space8) {
          screenshotChip("Threat check")
          screenshotChip("Outside now?")
          screenshotChip("Outlook")
        }
        Spacer(minLength: 0)
      }
      .padding(DesignTokens.Spacing.space24)
      .foregroundStyle(DesignTokens.Palette.textPrimary)
    }
    .preferredColorScheme(.dark)
  }

  private func screenshotChip(_ title: String) -> some View {
    Text(title)
      .font(DesignTokens.Typography.callout())
      .lineLimit(1)
      .minimumScaleFactor(0.85)
      .frame(maxWidth: .infinity)
      .padding(.vertical, DesignTokens.Spacing.space8)
      .background(Color.white.opacity(0.08), in: Capsule())
  }
}

struct AppStoreScreenshotWidgets: View {
  var body: some View {
    ZStack {
      DesignTokens.Palette.bgPrimary.ignoresSafeArea()
      VStack(spacing: 24) {
        Text("Widgets Everywhere")
          .font(DesignTokens.Typography.title())
          .frame(maxWidth: .infinity, alignment: .leading)

        VStack(alignment: .leading, spacing: 12) {
          Label("HOME SCREEN", systemImage: "square.grid.2x2")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.accent)
          Text("Small, Medium, and Large widgets with live temperature, daily forecast, and AI insights.")
            .font(DesignTokens.Typography.body())
        }
        .padding(16)
        .glassCardStyle()

        VStack(alignment: .leading, spacing: 12) {
          Label("LOCK SCREEN", systemImage: "lock.rectangle.stack.fill")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.accentCool)
          Text("Circular gauge, rectangular forecast, and inline conditions — always visible at a glance.")
            .font(DesignTokens.Typography.body())
        }
        .padding(16)
        .glassCardStyle()

        VStack(alignment: .leading, spacing: 12) {
          Label("APPLE WATCH", systemImage: "applewatch")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.accentWarm)
          Text("Temperature range gauge, AI brief, and DayCast Score right on your wrist.")
            .font(DesignTokens.Typography.body())
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
          .font(DesignTokens.Typography.title())

        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(DesignTokens.Typography.studioTitle())
              .foregroundStyle(DesignTokens.Palette.danger)
            VStack(alignment: .leading) {
              Text("TORNADO WARNING")
                .font(DesignTokens.Typography.caption())
              Text("DeSoto County, MS · Expires in 45m")
                .font(DesignTokens.Typography.micro())
                .foregroundStyle(DesignTokens.Palette.textSecondary)
            }
          }
          Text("TAKE SHELTER NOW. Move to an interior room on the lowest floor of a sturdy building. Avoid windows.")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
        .padding(16)
        .background(DesignTokens.Palette.danger.opacity(0.1))
        .cardStyle(stroke: DesignTokens.Palette.danger.opacity(0.4))

        VStack(alignment: .leading, spacing: 8) {
          Label("Time-sensitive alerts", systemImage: "bell.badge.fill")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.accent)
          Text("Warnings and watches use iOS time-sensitive notifications so severe weather reaches you promptly when alerts are enabled.")
            .font(DesignTokens.Typography.body())
        }
        .padding(16)
        .glassCardStyle()

        VStack(alignment: .leading, spacing: 8) {
          Label("AI MORNING BRIEF", systemImage: "sunrise.fill")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.accentWarm)
          Text("\"Light jacket this morning — great afternoon for a walk. UV peaks around 2pm, sunscreen if you'll be outside.\"")
            .font(DesignTokens.Typography.body())
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
