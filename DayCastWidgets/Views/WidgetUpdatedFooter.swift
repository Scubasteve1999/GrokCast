import SwiftUI

struct WidgetUpdatedFooter: View {
  let fetchedAt: Date
  let isStale: Bool
  let style: WidgetStyle
  var relativeTo: Date = Date()

  var body: some View {
    if isStale {
      Text("Open DayCast to refresh")
        .font(DesignTokens.Typography.micro())
        .foregroundStyle(style.secondaryText.opacity(0.8))
        .lineLimit(1)
    } else {
      Text(WidgetRelativeTime.updatedLabel(for: fetchedAt, relativeTo: relativeTo))
        .font(DesignTokens.Typography.micro())
        .foregroundStyle(style.secondaryText.opacity(0.85))
        .lineLimit(1)
    }
  }
}

struct WidgetAlertBadge: View {
  let summary: WidgetAlertSummary
  let style: WidgetStyle
  var compact: Bool = false
  var relativeTo: Date = Date()

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: WidgetAlertStyle.iconName(for: summary))
        .font(compact ? DesignTokens.Typography.micro() : DesignTokens.Typography.caption())
        .foregroundStyle(WidgetAlertStyle.tint(for: summary))
      Text(summary.displayText(relativeTo: relativeTo))
        .font(compact ? DesignTokens.Typography.micro() : DesignTokens.Typography.caption())
        .foregroundStyle(style.primaryText)
        .lineLimit(1)
    }
  }
}
