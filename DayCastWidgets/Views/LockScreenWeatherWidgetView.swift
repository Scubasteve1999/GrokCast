import SwiftUI
import WidgetKit

struct LockScreenWeatherWidgetView: View {
  let entry: WeatherWidgetEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    Group {
      if let snapshot = entry.snapshot {
        switch family {
        case .accessoryCircular:
          circularContent(snapshot: snapshot)
        case .accessoryRectangular:
          rectangularContent(snapshot: snapshot)
        case .accessoryInline:
          Text(inlineSummary(snapshot: snapshot))
        default:
          circularContent(snapshot: snapshot)
        }
      } else {
        emptyContent
      }
    }
    .widgetURL(WidgetDeepLink.url(hasActiveAlert: entry.hasActiveAlert))
  }

  @ViewBuilder
  private var emptyContent: some View {
    switch family {
    case .accessoryInline:
      Text(inlineEmptyMessage)
    case .accessoryRectangular:
      VStack(alignment: .leading, spacing: 2) {
        Text("DayCast")
          .font(DesignTokens.Typography.headline())
        Text(rectangularEmptyMessage)
          .font(DesignTokens.Typography.caption())
          .lineLimit(2)
      }
    default:
      Image(systemName: emptyIconName)
    }
  }

  private var emptyIconName: String { entry.emptyReason.iconName }

  private var inlineEmptyMessage: String {
    switch entry.emptyReason {
    case .requiresYearly:
      WidgetEmptyReason.requiresYearly.title
    case .locationMismatch(let name):
      "Open \(name) in DayCast"
    case .noData:
      "Open DayCast to refresh"
    case .none:
      "Open DayCast"
    }
  }

  private var rectangularEmptyMessage: String {
    switch entry.emptyReason {
    case .requiresYearly:
      WidgetEmptyReason.requiresYearly.message
    case .locationMismatch(let name):
      "Select \(name) in the app to update."
    case .noData:
      "Refresh weather in the app to update."
    case .none:
      "Open app to refresh"
    }
  }

  private func circularContent(snapshot: WidgetWeatherSnapshot) -> some View {
    Gauge(value: snapshot.currentTemp, in: snapshot.circularGaugeRange) {
      Image(systemName: snapshot.symbolName)
        .symbolRenderingMode(.multicolor)
    } currentValueLabel: {
      Text("\(Int(snapshot.currentTemp.rounded()))°")
        .font(DesignTokens.Typography.widgetTemp(17))
    }
    .gaugeStyle(.accessoryCircular)
    .opacity(entry.isStale ? WidgetStyle.staleContentOpacity : 1)
  }

  private func rectangularContent(snapshot: WidgetWeatherSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 4) {
        Image(systemName: snapshot.symbolName)
          .symbolRenderingMode(.multicolor)
        Text("\(Int(snapshot.currentTemp.rounded()))° · \(snapshot.conditionText)")
          .font(DesignTokens.Typography.headline())
          .lineLimit(1)
      }
      Text(snapshot.location.name)
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(.secondary)
        .lineLimit(1)
      if entry.hasActiveAlert, let summary = entry.alertSummary {
        HStack(spacing: 4) {
          Image(systemName: WidgetAlertStyle.iconName(for: summary))
            .foregroundStyle(WidgetAlertStyle.tint(for: summary))
          Text(summary.displayText(relativeTo: entry.date))
            .lineLimit(1)
        }
        .font(DesignTokens.Typography.micro())
      } else if !entry.isStale {
        Text(WidgetRelativeTime.updatedLabel(for: snapshot.fetchedAt, relativeTo: entry.date))
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(.secondary)
          .lineLimit(1)
      } else {
        Text("Open DayCast to refresh")
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func inlineSummary(snapshot: WidgetWeatherSnapshot) -> String {
    let temp = "\(Int(snapshot.currentTemp.rounded()))° \(snapshot.conditionText)"
    if entry.hasActiveAlert, let summary = entry.alertSummary {
      return "\(summary.displayText(relativeTo: entry.date)) · \(temp)"
    }
    return "\(temp) · \(snapshot.location.name)"
  }
}

struct DayCastLockScreenWeatherWidget: Widget {
  let kind = "DayCastLockScreenWeatherWidget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind,
      intent: WidgetLocationSelectionIntent.self,
      provider: WeatherTimelineProvider()
    ) { entry in
      LockScreenWeatherWidgetView(entry: entry)
    }
    .configurationDisplayName("DayCast Lock Screen")
    .description("Weather and alerts at a glance on your Lock Screen.")
    .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
  }
}

#Preview(as: .accessoryCircular) {
  DayCastLockScreenWeatherWidget()
} timeline: {
  WeatherWidgetEntry(
    date: .now, snapshot: .preview, alertSummary: nil, isStale: false, emptyReason: .none)
  WeatherWidgetEntry(
    date: .now, snapshot: .preview, alertSummary: nil, isStale: true, emptyReason: .none)
}

#Preview(as: .accessoryRectangular) {
  DayCastLockScreenWeatherWidget()
} timeline: {
  WeatherWidgetEntry(
    date: .now, snapshot: .preview, alertSummary: .preview, isStale: false, emptyReason: .none)
  WeatherWidgetEntry(
    date: .now, snapshot: .preview, alertSummary: nil, isStale: true, emptyReason: .none)
  WeatherWidgetEntry(
    date: .now, snapshot: nil, alertSummary: nil, isStale: false,
    emptyReason: .locationMismatch(locationName: "Memphis, TN"))
}

#Preview(as: .accessoryInline) {
  DayCastLockScreenWeatherWidget()
} timeline: {
  WeatherWidgetEntry(
    date: .now, snapshot: .preview, alertSummary: .preview, isStale: false, emptyReason: .none)
  WeatherWidgetEntry(
    date: .now, snapshot: .preview, alertSummary: nil, isStale: false, emptyReason: .none)
  WeatherWidgetEntry(
    date: .now, snapshot: nil, alertSummary: nil, isStale: false,
    emptyReason: .locationMismatch(locationName: "Memphis, TN"))
}
