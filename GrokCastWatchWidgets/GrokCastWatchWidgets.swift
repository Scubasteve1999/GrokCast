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
      let lo = min(snapshot.low, snapshot.high)
      let hi = max(snapshot.low, snapshot.high)
      let safeRange = lo < hi ? lo...hi : (lo - 1)...(lo + 1)
      Gauge(value: snapshot.currentTemp, in: safeRange) {
        Image(systemName: snapshot.symbolName)
          .symbolRenderingMode(.multicolor)
      } currentValueLabel: {
        Text("\(Int(snapshot.currentTemp.rounded()))°")
          .font(.system(.body, design: .rounded).weight(.bold))
      }
      .gaugeStyle(.accessoryCircular)
    } else {
      Image(systemName: "cloud")
    }
  }
}

struct WatchRectangularComplicationView: View {
  let entry: WatchWeatherComplicationEntry

  var body: some View {
    if let snapshot = entry.snapshot {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 4) {
          Image(systemName: snapshot.symbolName)
            .symbolRenderingMode(.multicolor)
          Text("\(Int(snapshot.currentTemp.rounded()))° \(snapshot.conditionText)")
            .font(.headline)
            .lineLimit(1)
        }
        HStack(spacing: 8) {
          Text("H:\(Int(snapshot.high.rounded()))° L:\(Int(snapshot.low.rounded()))°")
            .font(.caption2.weight(.semibold))
          if let score = snapshot.grokCastScore, let label = snapshot.grokCastScoreLabel {
            Text("Score \(score) · \(label)")
              .font(.caption2)
              .foregroundStyle(.blue)
          }
        }
        if let brief = snapshot.grokBriefOneLiner, !brief.isEmpty {
          Text(brief)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        } else if let hourly = snapshot.hourly.first, hourly.precipChance > 20 {
          Text("\(hourly.precipChance)% chance of rain")
            .font(.caption2)
            .foregroundStyle(.cyan)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      VStack(alignment: .leading) {
        Text("GrokCast")
          .font(.headline)
        Text("Open app to refresh")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
  }
}

struct WatchInlineComplicationView: View {
  let entry: WatchWeatherComplicationEntry

  var body: some View {
    if let snapshot = entry.snapshot {
      if let score = snapshot.grokCastScore {
        Text("\(Int(snapshot.currentTemp.rounded()))° \(snapshot.conditionText) · \(score)")
      } else {
        Text("\(Int(snapshot.currentTemp.rounded()))° · \(snapshot.conditionText)")
      }
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

struct WatchCornerComplicationView: View {
  let entry: WatchWeatherComplicationEntry

  var body: some View {
    if let snapshot = entry.snapshot {
      Text("\(Int(snapshot.currentTemp.rounded()))°")
        .font(.system(.title3, design: .rounded).weight(.bold))
        .widgetLabel {
          Text(snapshot.conditionText)
        }
    } else {
      Image(systemName: "cloud")
    }
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
    case .accessoryCorner:
      WatchCornerComplicationView(entry: entry)
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
