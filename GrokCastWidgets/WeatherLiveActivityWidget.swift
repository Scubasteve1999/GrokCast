import ActivityKit
import SwiftUI
import WidgetKit

struct WeatherLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WeatherLiveActivityAttributes.self) { context in
      lockScreenBanner(context: context)
        .activityBackgroundTint(Color.black.opacity(0.75))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: context.state.symbolName)
            .font(.title2)
            .symbolRenderingMode(.multicolor)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(context.state.temperatureText)
            .font(.title3.bold())
            .monospacedDigit()
        }
        DynamicIslandExpandedRegion(.center) {
          Text(context.state.locationName)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Score \(context.state.score) · \(context.state.scoreLabel)")
              .font(.caption.weight(.semibold))
            Text(context.state.minutecastMessage)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
        }
      } compactLeading: {
        Image(systemName: context.state.symbolName)
          .symbolRenderingMode(.multicolor)
      } compactTrailing: {
        Text("\(context.state.score)")
          .font(.caption.bold())
          .monospacedDigit()
      } minimal: {
        Image(systemName: "cloud.sun.fill")
          .symbolRenderingMode(.multicolor)
      }
    }
  }

  @ViewBuilder
  private func lockScreenBanner(context: ActivityViewContext<WeatherLiveActivityAttributes>) -> some View {
    HStack(spacing: 12) {
      Image(systemName: context.state.symbolName)
        .font(.title2)
        .symbolRenderingMode(.multicolor)
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Text(context.state.locationName)
            .font(.caption.weight(.semibold))
          Spacer()
          Text(context.state.temperatureText)
            .font(.headline.bold())
            .monospacedDigit()
        }
        Text(context.state.conditionText)
          .font(.caption2)
          .foregroundStyle(.secondary)
        Text("Score \(context.state.score) · \(context.state.minutecastMessage)")
          .font(.caption2)
          .lineLimit(1)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }
}
