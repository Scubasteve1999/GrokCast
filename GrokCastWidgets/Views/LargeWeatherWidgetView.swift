import SwiftUI
import WidgetKit

struct LargeWeatherWidgetView: View {
  let entry: WeatherWidgetEntry
  @Environment(\.colorScheme) private var colorScheme

  private var style: WidgetStyle { WidgetStyle(colorScheme: colorScheme) }

  private static let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE"
    return formatter
  }()

  private static let hourFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "ha"
    return formatter
  }()

  var body: some View {
    Group {
      if let snapshot = entry.snapshot {
        content(snapshot: snapshot)
      } else {
        WidgetEmptyStateView(reason: entry.emptyReason, style: style)
      }
    }
    .widgetURL(WidgetDeepLink.url(hasActiveAlert: entry.hasActiveAlert))
    .widgetTacticalContainer()
  }

  private func content(snapshot: WidgetWeatherSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      headerSection(snapshot: snapshot)

      if entry.hasActiveAlert, let summary = entry.alertSummary {
        WidgetAlertBadge(summary: summary, style: style, relativeTo: entry.date)
      }

      if !snapshot.hourly.isEmpty {
        hourlySection(snapshot.hourly)
      }

      Divider().opacity(0.3)

      dailySection(snapshot.daily)

      Spacer(minLength: 0)

      if let brief = snapshot.grokBriefOneLiner, !brief.isEmpty {
        grokBriefSection(brief)
      }

      WidgetUpdatedFooter(
        fetchedAt: snapshot.fetchedAt,
        isStale: entry.isStale,
        style: style,
        relativeTo: entry.date
      )
    }
    .padding(14)
    .opacity(entry.isStale ? style.staleContentOpacity : 1)
  }

  private func headerSection(snapshot: WidgetWeatherSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 4) {
        Image(systemName: "mappin.and.ellipse")
          .font(.caption2)
          .foregroundStyle(style.secondaryText)
        Text(snapshot.location.name)
          .font(.caption.weight(.semibold))
          .foregroundStyle(style.secondaryText)
          .lineLimit(1)

        Spacer(minLength: 0)

        Text("H:\(Int(snapshot.high.rounded()))° L:\(Int(snapshot.low.rounded()))°")
          .font(.caption.weight(.semibold))
          .foregroundStyle(style.secondaryText)
      }

      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text("\(Int(snapshot.currentTemp.rounded()))°")
          .font(.system(size: 38, weight: .bold, design: .rounded))
          .foregroundStyle(style.primaryText)
        Image(systemName: snapshot.symbolName)
          .font(.title2)
          .symbolRenderingMode(.multicolor)

        Spacer(minLength: 0)

        if let score = snapshot.grokCastScore, let label = snapshot.grokCastScoreLabel {
          VStack(alignment: .trailing, spacing: 1) {
            Text("\(score)")
              .font(.system(size: 22, weight: .bold, design: .rounded))
              .foregroundStyle(style.primaryText)
            Text(label)
              .font(.caption2.weight(.medium))
              .foregroundStyle(style.secondaryText)
              .lineLimit(1)
          }
        }
      }

      Text(snapshot.conditionText)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(style.secondaryText)
        .lineLimit(1)
    }
  }

  private func hourlySection(_ hourly: [HourlyForecast]) -> some View {
    HStack(spacing: 0) {
      ForEach(hourly) { hour in
        VStack(spacing: 4) {
          Text(hourLabel(for: hour.time))
            .font(.caption2.weight(.medium))
            .foregroundStyle(style.secondaryText)
          Image(systemName: hour.symbolName)
            .font(.caption)
            .symbolRenderingMode(.multicolor)
          Text("\(Int(hour.temp.rounded()))°")
            .font(.caption.weight(.semibold))
            .foregroundStyle(style.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(style.cardBackground, in: RoundedRectangle(cornerRadius: 8))
      }
    }
  }

  private func dailySection(_ daily: [DailyForecast]) -> some View {
    let days = Array(daily.prefix(5))
    return VStack(spacing: 6) {
      ForEach(days) { day in
        dailyRow(day)
      }
    }
  }

  private func dailyRow(_ day: DailyForecast) -> some View {
    HStack(spacing: 8) {
      Text(dayLabel(for: day.date))
        .font(.caption.weight(.semibold))
        .foregroundStyle(style.primaryText)
        .frame(width: 36, alignment: .leading)

      Image(systemName: day.symbolName)
        .font(.caption)
        .symbolRenderingMode(.multicolor)
        .frame(width: 20)

      if day.precipChance > 0 {
        Text("\(day.precipChance)%")
          .font(.caption2.weight(.medium))
          .foregroundStyle(.cyan)
          .frame(width: 32, alignment: .leading)
      } else {
        Spacer().frame(width: 32)
      }

      Spacer(minLength: 0)

      tempBar(low: day.low, high: day.high)

      Text("\(Int(day.high.rounded()))°")
        .font(.caption.weight(.semibold))
        .foregroundStyle(style.primaryText)
        .frame(width: 28, alignment: .trailing)

      Text("\(Int(day.low.rounded()))°")
        .font(.caption2.weight(.medium))
        .foregroundStyle(style.secondaryText)
        .frame(width: 28, alignment: .trailing)
    }
  }

  private func tempBar(low: Double, high: Double) -> some View {
    GeometryReader { geo in
      Capsule()
        .fill(
          LinearGradient(
            colors: [.blue.opacity(0.6), .orange.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .frame(height: 4)
        .frame(maxHeight: .infinity, alignment: .center)
    }
    .frame(width: 50, height: 12)
  }

  private func grokBriefSection(_ brief: String) -> some View {
    HStack(alignment: .top, spacing: 4) {
      Image(systemName: "sparkles")
        .font(.caption2)
        .foregroundStyle(style.secondaryText)
      Text(brief)
        .font(.caption2)
        .foregroundStyle(style.primaryText)
        .lineLimit(3)
        .minimumScaleFactor(0.9)
    }
  }

  private func dayLabel(for date: Date) -> String {
    if Calendar.current.isDateInToday(date) {
      return "Today"
    }
    return Self.dayFormatter.string(from: date)
  }

  private func hourLabel(for date: Date) -> String {
    if Calendar.current.isDateInToday(date),
      abs(date.timeIntervalSinceNow) < 3600
    {
      return "Now"
    }
    return Self.hourFormatter.string(from: date).lowercased()
  }
}

struct GrokCastLargeWeatherWidget: Widget {
  let kind = "GrokCastLargeWeatherWidget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind,
      intent: WidgetLocationSelectionIntent.self,
      provider: WeatherTimelineProvider()
    ) { entry in
      LargeWeatherWidgetView(entry: entry)
    }
    .configurationDisplayName("GrokCast Daily")
    .description("Full forecast with hourly, daily, and AI insights.")
    .supportedFamilies([.systemLarge])
  }
}

#Preview(as: .systemLarge) {
  GrokCastLargeWeatherWidget()
} timeline: {
  WeatherWidgetEntry(
    date: .now, snapshot: .preview, alertSummary: nil, isStale: false, emptyReason: .none)
  WeatherWidgetEntry(
    date: .now, snapshot: .preview, alertSummary: .preview, isStale: false, emptyReason: .none)
  WeatherWidgetEntry(
    date: .now, snapshot: nil, alertSummary: nil, isStale: false, emptyReason: .noData)
}
