import ActivityKit
import SwiftUI
import WidgetKit

struct WeatherLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WeatherLiveActivityAttributes.self) { context in
      lockScreenBanner(context: context)
        .activityBackgroundTint(backgroundTint(for: context.state))
        .widgetURL(deepLink(for: context.state.variant))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: context.state.symbolName)
            .font(DesignTokens.Typography.studioTitle())
            .symbolRenderingMode(.multicolor)
            .foregroundStyle(accentColor(for: context.state))
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(context.state.temperatureText)
            .font(DesignTokens.Typography.metric())
            .monospacedDigit()
        }
        DynamicIslandExpandedRegion(.center) {
          Text(expandedCenterTitle(for: context.state))
            .font(DesignTokens.Typography.caption())
            .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.bottom) {
          expandedBottom(for: context.state)
        }
      } compactLeading: {
        Image(systemName: context.state.symbolName)
          .symbolRenderingMode(.multicolor)
          .foregroundStyle(accentColor(for: context.state))
      } compactTrailing: {
        compactTrailing(for: context.state)
      } minimal: {
        Image(systemName: minimalSymbol(for: context.state))
          .symbolRenderingMode(.multicolor)
          .foregroundStyle(accentColor(for: context.state))
      }
    }
  }

  // MARK: - Lock Screen

  @ViewBuilder
  private func lockScreenBanner(
    context: ActivityViewContext<WeatherLiveActivityAttributes>
  ) -> some View {
    let state = context.state
    HStack(spacing: 12) {
      Image(systemName: state.symbolName)
        .font(DesignTokens.Typography.studioTitle())
        .symbolRenderingMode(.multicolor)
        .foregroundStyle(accentColor(for: state))
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Text(state.locationName)
            .font(DesignTokens.Typography.caption())
          Spacer()
          Text(state.temperatureText)
            .font(DesignTokens.Typography.headline())
            .monospacedDigit()
        }
        switch state.variant {
        case .severeAlert:
          Text(state.headline ?? "Severe Weather")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(accentColor(for: state))
            .lineLimit(1)
          if let detail = state.detail {
            Text(detail)
              .font(DesignTokens.Typography.micro())
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        case .radarEvent:
          Text(state.headline ?? "Radar")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(Color.cyan)
            .lineLimit(1)
          Text(state.detail ?? state.minutecastMessage)
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(.secondary)
            .lineLimit(1)
        case .standard:
          Text(state.conditionText)
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(.secondary)
          Text("Score \(state.score) · \(state.minutecastMessage)")
            .font(DesignTokens.Typography.micro())
            .lineLimit(1)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }

  // MARK: - Dynamic Island helpers

  private func expandedCenterTitle(
    for state: WeatherLiveActivityAttributes.ContentState
  ) -> String {
    switch state.variant {
    case .severeAlert:
      return state.headline ?? state.locationName
    case .radarEvent:
      return state.headline ?? state.locationName
    case .standard:
      return state.locationName
    }
  }

  @ViewBuilder
  private func expandedBottom(
    for state: WeatherLiveActivityAttributes.ContentState
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      switch state.variant {
      case .severeAlert:
        Text(state.headline ?? "Severe Weather")
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(accentColor(for: state))
          .lineLimit(2)
        Text(state.detail ?? "Score \(state.score) · \(state.scoreLabel)")
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(.secondary)
          .lineLimit(2)
      case .radarEvent:
        Text(state.detail ?? state.minutecastMessage)
          .font(DesignTokens.Typography.caption())
          .lineLimit(2)
        Text("Score \(state.score) · \(state.scoreLabel)")
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(.secondary)
      case .standard:
        Text("Score \(state.score) · \(state.scoreLabel)")
          .font(DesignTokens.Typography.caption())
        Text(state.minutecastMessage)
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
  }

  @ViewBuilder
  private func compactTrailing(
    for state: WeatherLiveActivityAttributes.ContentState
  ) -> some View {
    switch state.variant {
    case .severeAlert:
      Text("!")
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(accentColor(for: state))
    case .radarEvent:
      Text(state.temperatureText)
        .font(DesignTokens.Typography.caption())
        .monospacedDigit()
    case .standard:
      Text("\(state.score)")
        .font(DesignTokens.Typography.caption())
        .monospacedDigit()
    }
  }

  private func minimalSymbol(
    for state: WeatherLiveActivityAttributes.ContentState
  ) -> String {
    switch state.variant {
    case .severeAlert:
      return "exclamationmark.triangle.fill"
    case .radarEvent:
      return state.symbolName
    case .standard:
      return "cloud.sun.fill"
    }
  }

  // MARK: - Style / deep link

  private func accentColor(
    for state: WeatherLiveActivityAttributes.ContentState
  ) -> Color {
    switch state.variant {
    case .severeAlert:
      if state.severityLevel >= 3 { return .red }
      if state.severityLevel >= 2 { return .orange }
      return .orange
    case .radarEvent:
      return .cyan
    case .standard:
      return .primary
    }
  }

  private func backgroundTint(
    for state: WeatherLiveActivityAttributes.ContentState
  ) -> Color {
    switch state.variant {
    case .severeAlert:
      if state.severityLevel >= 3 {
        return DesignTokens.Palette.danger.opacity(0.55)
      }
      return DesignTokens.Palette.warning.opacity(0.5)
    case .radarEvent:
      return DesignTokens.Palette.accentCool.opacity(0.35)
    case .standard:
      return DesignTokens.Palette.bgPrimary.opacity(0.85)
    }
  }

  private func deepLink(
    for variant: WeatherLiveActivityAttributes.Variant
  ) -> URL {
    switch variant {
    case .severeAlert:
      return DayCastDeepLinks.alertsURL
    case .radarEvent:
      return DayCastDeepLinks.radarURL
    case .standard:
      return DayCastDeepLinks.todayURL
    }
  }
}
