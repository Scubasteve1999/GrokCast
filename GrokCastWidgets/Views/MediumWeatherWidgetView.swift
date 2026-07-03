import SwiftUI
import WidgetKit

struct MediumWeatherWidgetView: View {
  let entry: WeatherWidgetEntry
  @Environment(\.colorScheme) private var colorScheme

  private var style: WidgetStyle { WidgetStyle(colorScheme: colorScheme) }

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
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 4) {
            Image(systemName: "mappin.and.ellipse")
              .font(.caption2)
              .foregroundStyle(style.secondaryText)
            Text(snapshot.location.name)
              .font(.caption.weight(.semibold))
              .foregroundStyle(style.secondaryText)
              .lineLimit(1)
          }

          HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(Int(snapshot.currentTemp.rounded()))°")
              .font(.system(size: 36, weight: .bold, design: .rounded))
              .foregroundStyle(style.primaryText)
            Image(systemName: snapshot.symbolName)
              .font(.title3)
              .symbolRenderingMode(.multicolor)
          }

          HStack(spacing: 10) {
            Label("H \(Int(snapshot.high.rounded()))°", systemImage: "arrow.up")
            Label("L \(Int(snapshot.low.rounded()))°", systemImage: "arrow.down")
          }
          .font(.caption.weight(.semibold))
          .foregroundStyle(style.secondaryText)
          .labelStyle(.titleOnly)

          if let score = snapshot.grokCastScore, let label = snapshot.grokCastScoreLabel {
            Text("Score \(score) · \(label)")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(style.secondaryText)
              .lineLimit(1)
          }

          if let brief = snapshot.grokBriefOneLiner, !brief.isEmpty {
            HStack(alignment: .top, spacing: 4) {
              Image(systemName: "sparkles")
                .font(.caption2)
                .foregroundStyle(style.secondaryText)
              Text(brief)
                .font(.caption2)
                .foregroundStyle(style.primaryText)
                .lineLimit(2)
            }
          } else if let minutecast = snapshot.minutecastMessage {
            Text(minutecast)
              .font(.caption2)
              .foregroundStyle(style.secondaryText)
              .lineLimit(1)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        hourlyStrip(snapshot.hourly)
      }
      .opacity(entry.isStale ? style.staleContentOpacity : 1)

      if entry.hasActiveAlert, let summary = entry.alertSummary {
        WidgetAlertBadge(summary: summary, style: style, relativeTo: entry.date)
      }

      WidgetUpdatedFooter(
        fetchedAt: snapshot.fetchedAt,
        isStale: entry.isStale,
        style: style,
        relativeTo: entry.date
      )
    }
    .padding(14)
  }

  private func hourlyStrip(_ hourly: [HourlyForecast]) -> some View {
    HStack(spacing: 8) {
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
        .frame(minWidth: 36)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(style.cardBackground, in: RoundedRectangle(cornerRadius: 8))
      }
    }
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

struct GrokCastMediumWeatherWidget: Widget {
  let kind = "GrokCastMediumWeatherWidget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind,
      intent: WidgetLocationSelectionIntent.self,
      provider: WeatherTimelineProvider()
    ) { entry in
      MediumWeatherWidgetView(entry: entry)
    }
    .configurationDisplayName("GrokCast Forecast")
    .description("Today's high/low and the next few hours.")
    .supportedFamilies([.systemMedium])
  }
}

#Preview(as: .systemMedium) {
  GrokCastMediumWeatherWidget()
} timeline: {
  WeatherWidgetEntry(
    date: .now, snapshot: .preview, alertSummary: nil, isStale: false, emptyReason: .none)
  WeatherWidgetEntry(
    date: .now, snapshot: .preview, alertSummary: .preview, isStale: false, emptyReason: .none)
  WeatherWidgetEntry(
    date: .now, snapshot: .preview, alertSummary: nil, isStale: true, emptyReason: .none)
  WeatherWidgetEntry(
    date: .now, snapshot: nil, alertSummary: nil, isStale: false, emptyReason: .noData)
  WeatherWidgetEntry(
    date: .now, snapshot: nil, alertSummary: nil, isStale: false,
    emptyReason: .locationMismatch(locationName: "Memphis, TN"))
}
