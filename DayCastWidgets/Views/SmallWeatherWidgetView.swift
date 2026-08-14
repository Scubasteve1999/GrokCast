import SwiftUI
import WidgetKit

struct SmallWeatherWidgetView: View {
  let entry: WeatherWidgetEntry
  @Environment(\.colorScheme) private var colorScheme

  private var style: WidgetStyle { WidgetStyle(colorScheme: colorScheme) }

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
      HStack(spacing: 4) {
        HStack(spacing: 4) {
          Image(systemName: "mappin.and.ellipse")
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(style.secondaryText)
          Text(snapshot.location.name)
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(style.secondaryText)
            .lineLimit(1)
        }
        .opacity(entry.isStale ? style.staleContentOpacity : 1)

        Spacer(minLength: 0)

        if entry.hasActiveAlert, let summary = entry.alertSummary {
          Image(systemName: WidgetAlertStyle.iconName(for: summary))
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(WidgetAlertStyle.tint(for: summary))
        }
      }

      Spacer(minLength: 0)

      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .center, spacing: 8) {
          Image(systemName: snapshot.symbolName)
            .font(DesignTokens.Typography.studioTitle())
            .symbolRenderingMode(.multicolor)
            .foregroundStyle(style.primaryText)

          Text("\(Int(snapshot.currentTemp.rounded()))°")
            .font(DesignTokens.Typography.widgetTemp(34))
            .foregroundStyle(style.primaryText)
            .minimumScaleFactor(0.8)
        }

        Text(snapshot.conditionText)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(style.secondaryText)
          .lineLimit(1)
      }
      .opacity(entry.isStale ? style.staleContentOpacity : 1)

      if entry.hasActiveAlert, let summary = entry.alertSummary {
        WidgetAlertBadge(
          summary: summary, style: style, compact: true, relativeTo: entry.date)
      }

      WidgetUpdatedFooter(
        fetchedAt: snapshot.fetchedAt,
        isStale: entry.isStale,
        style: style,
        relativeTo: entry.date
      )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(14)
  }
}

struct DayCastSmallWeatherWidget: Widget {
  let kind = "DayCastSmallWeatherWidget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind,
      intent: WidgetLocationSelectionIntent.self,
      provider: WeatherTimelineProvider()
    ) { entry in
      SmallWeatherWidgetView(entry: entry)
    }
    .configurationDisplayName("DayCast Weather")
    .description("Current conditions at a glance.")
    .supportedFamilies([.systemSmall])
  }
}

#Preview(as: .systemSmall) {
  DayCastSmallWeatherWidget()
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
