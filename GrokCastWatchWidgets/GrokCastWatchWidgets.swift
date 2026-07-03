import SwiftUI
import WidgetKit

struct WatchWeatherComplicationEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetWeatherSnapshot?
}

struct WatchWeatherComplicationProvider: TimelineProvider {
  func placeholder(in context: Context) -> WatchWeatherComplicationEntry {
    WatchWeatherComplicationEntry(date: .now, snapshot: .preview)
  }

  func getSnapshot(in context: Context, completion: @escaping (WatchWeatherComplicationEntry) -> Void) {
    completion(
      WatchWeatherComplicationEntry(date: .now, snapshot: WidgetDataStore.loadSnapshot(for: nil))
    )
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<WatchWeatherComplicationEntry>) -> Void
  ) {
    let snapshot = WidgetDataStore.loadSnapshot(for: nil)
    let entry = WatchWeatherComplicationEntry(date: .now, snapshot: snapshot)
    let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
    completion(Timeline(entries: [entry], policy: .after(next)))
  }
}

struct WatchCircularComplicationView: View {
  let entry: WatchWeatherComplicationEntry

  var body: some View {
    if let snapshot = entry.snapshot {
      VStack(spacing: 0) {
        Image(systemName: snapshot.symbolName)
          .font(.caption)
        Text("\(Int(snapshot.currentTemp.rounded()))°")
          .font(.system(.body, design: .rounded).weight(.bold))
          .minimumScaleFactor(0.7)
      }
    } else {
      Image(systemName: "cloud")
    }
  }
}

struct WatchRectangularComplicationView: View {
  let entry: WatchWeatherComplicationEntry

  var body: some View {
    if let snapshot = entry.snapshot {
      HStack {
        VStack(alignment: .leading, spacing: 0) {
          Text("\(Int(snapshot.currentTemp.rounded()))°")
            .font(.headline.bold())
          Text(snapshot.conditionText)
            .font(.caption2)
            .lineLimit(1)
        }
        Spacer(minLength: 0)
        if let score = snapshot.grokCastScore {
          Text("\(score)")
            .font(.caption.bold())
            .foregroundStyle(.blue)
        }
      }
    } else {
      Text("GrokCast")
        .font(.caption)
    }
  }
}

struct WatchInlineComplicationView: View {
  let entry: WatchWeatherComplicationEntry

  var body: some View {
    if let snapshot = entry.snapshot {
      Text("\(Int(snapshot.currentTemp.rounded()))° · \(snapshot.conditionText)")
    } else {
      Text("GrokCast")
    }
  }
}

struct GrokCastWatchComplicationWidget: Widget {
  let kind = "GrokCastWatchComplication"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: WatchWeatherComplicationProvider()) { entry in
      WatchComplicationEntryView(entry: entry)
    }
    .configurationDisplayName("GrokCast")
    .description("Temperature, conditions, and score.")
    .supportedFamilies([
      .accessoryCircular,
      .accessoryRectangular,
      .accessoryInline,
      .accessoryCorner,
    ])
  }
}

struct WatchComplicationEntryView: View {
  let entry: WatchWeatherComplicationEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    switch family {
    case .accessoryRectangular:
      WatchRectangularComplicationView(entry: entry)
    case .accessoryInline:
      WatchInlineComplicationView(entry: entry)
    default:
      WatchCircularComplicationView(entry: entry)
    }
  }
}

@main
struct GrokCastWatchWidgets: WidgetBundle {
  var body: some Widget {
    GrokCastWatchComplicationWidget()
  }
}
