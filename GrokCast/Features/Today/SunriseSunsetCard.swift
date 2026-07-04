import SwiftUI

struct SunriseSunsetCard: View {
  let sunrise: Date?
  let sunset: Date?

  private var daylight: String? {
    guard let rise = sunrise, let set = sunset else { return nil }
    let seconds = set.timeIntervalSince(rise)
    let hours = Int(seconds) / 3600
    let minutes = (Int(seconds) % 3600) / 60
    return "\(hours)h \(minutes)m"
  }

  private var sunProgress: Double {
    guard let rise = sunrise, let set = sunset else { return 0.5 }
    let now = Date()
    if now < rise { return 0 }
    if now > set { return 1 }
    return now.timeIntervalSince(rise) / set.timeIntervalSince(rise)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      HStack {
        Text("SUNRISE & SUNSET")
          .font(.caption.weight(.bold))
          .tracking(DesignTokens.Typography.cardLabelTracking)
          .foregroundStyle(DesignTokens.Palette.textTertiary)
        Spacer()
        if let daylight {
          Text(daylight)
            .font(.caption2.weight(.medium))
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
      }

      sunArcView
        .frame(height: 60)

      HStack {
        Label(formatTime(sunrise), systemImage: "sunrise.fill")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(DesignTokens.Palette.accentWarm)
        Spacer()
        Label(formatTime(sunset), systemImage: "sunset.fill")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(DesignTokens.Palette.accentCool)
      }
    }
    .padding(DesignTokens.Spacing.space16)
    .glassCardStyle()
  }

  private var sunArcView: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      let arcPath = Path { path in
        path.move(to: CGPoint(x: 0, y: h))
        path.addQuadCurve(
          to: CGPoint(x: w, y: h),
          control: CGPoint(x: w / 2, y: -h * 0.6)
        )
      }

      ZStack {
        arcPath
          .stroke(
            DesignTokens.Palette.textTertiary.opacity(0.3),
            style: StrokeStyle(lineWidth: 2, dash: [4, 4])
          )

        arcPath
          .trim(from: 0, to: sunProgress)
          .stroke(
            LinearGradient(
              colors: [DesignTokens.Palette.accentWarm, DesignTokens.Palette.accent],
              startPoint: .leading,
              endPoint: .trailing
            ),
            lineWidth: 3
          )

        if sunProgress > 0 && sunProgress < 1 {
          let point = arcPoint(progress: sunProgress, width: w, height: h)
          Circle()
            .fill(DesignTokens.Palette.accentWarm)
            .frame(width: 12, height: 12)
            .shadow(color: DesignTokens.Palette.accentWarm.opacity(0.5), radius: 4)
            .position(point)
        }
      }
    }
  }

  private func arcPoint(progress: Double, width: CGFloat, height: CGFloat) -> CGPoint {
    let t = progress
    let x = width * t
    let y = height - 4 * height * 0.8 * t * (1 - t)
    return CGPoint(x: x, y: y)
  }

  private func formatTime(_ date: Date?) -> String {
    guard let date else { return "--:--" }
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    return f.string(from: date)
  }
}
