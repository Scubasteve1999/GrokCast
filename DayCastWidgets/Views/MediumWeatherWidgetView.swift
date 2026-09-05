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
              .font(DesignTokens.Typography.micro())
              .foregroundStyle(style.secondaryText)
            Text(snapshot.location.name)
              .font(DesignTokens.Typography.caption())
              .foregroundStyle(style.secondaryText)
              .lineLimit(1)
          }

          HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(Int(snapshot.currentTemp.rounded()))°")
              .font(DesignTokens.Typography.widgetTemp(36))
              .foregroundStyle(style.primaryText)
            Image(systemName: snapshot.symbolName)
              .font(DesignTokens.Typography.metric())
              .symbolRenderingMode(.multicolor)
          }

          Text(snapshot.conditionText)
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(style.secondaryText)
            .lineLimit(1)

          HStack(spacing: 10) {
            Label("H \(Int(snapshot.high.rounded()))°", systemImage: "arrow.up")
            Label("L \(Int(snapshot.low.rounded()))°", systemImage: "arrow.down")
          }
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(style.secondaryText)
          .labelStyle(.titleOnly)

          if let minutecast = snapshot.minutecastMessage, !minutecast.isEmpty {
            Text(minutecast)
              .font(DesignTokens.Typography.micro())
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
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(style.secondaryText)
          Image(systemName: hour.symbolName)
            .font(DesignTokens.Typography.caption())
            .symbolRenderingMode(.multicolor)
          Text("\(Int(hour.temp.rounded()))°")
            .font(DesignTokens.Typography.caption())
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

struct DayCastMediumWeatherWidget: Widget {
  let kind = "DayCastMediumWeatherWidget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind,
      intent: WidgetLocationSelectionIntent.self,
      provider: WeatherTimelineProvider()
    ) { entry in
      MediumWeatherWidgetView(entry: entry)
    }
    .configurationDisplayName("DayCast Forecast")
    .description("Today's high/low and the next few hours.")
    .supportedFamilies([.systemMedium])
  }
}

#Preview(as: .systemMedium) {
  DayCastMediumWeatherWidget()
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
  WeatherWidgetEntry(
    date: .now, snapshot: nil, alertSummary: nil, isStale: false, emptyReason: .requiresYearly)
}
