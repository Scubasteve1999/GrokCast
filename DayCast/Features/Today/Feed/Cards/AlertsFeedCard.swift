import SwiftUI

struct AlertsFeedCard: View {
  let alerts: [NWSAlert]
  var severeContext: SevereWeatherContext? = nil
  var onSelect: (NWSAlert) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      Text("Active Alerts")
        .font(DesignTokens.Typography.subsection())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .tracking(DesignTokens.Typography.cardLabelTracking)

      if let severeContext {
        SevereContextCard(context: severeContext)
      }

      ForEach(alerts.prefix(5)) { alert in
        Button {
          Haptic.impact(.light)
          onSelect(alert)
        } label: {
          HStack(spacing: DesignTokens.Spacing.space8) {
            Image(systemName: NWSAlertStyle.iconName(for: alert))
              .font(DesignTokens.Typography.metric())
              .foregroundStyle(tint(for: alert))

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
              Text(alert.event)
                .font(DesignTokens.Typography.subsection())
                .foregroundStyle(DesignTokens.Palette.textPrimary)
                .multilineTextAlignment(.leading)
              if let headline = alert.headline, !headline.isEmpty {
                Text(headline)
                  .font(DesignTokens.Typography.caption())
                  .foregroundStyle(DesignTokens.Palette.textSecondary)
                  .lineLimit(2)
                  .multilineTextAlignment(.leading)
              }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
              .font(DesignTokens.Typography.caption())
              .foregroundStyle(DesignTokens.Palette.textTertiary)
          }
          .padding(DesignTokens.Spacing.space12)
          .background(tint(for: alert).opacity(0.12))
          .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
              .stroke(tint(for: alert).opacity(0.45), lineWidth: 1)
          )
          .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(alertAccessibility(alert))
      }
    }
    .padding(DesignTokens.Spacing.space16)
    .cardStyle()
    .accessibilityElement(children: .contain)
  }

  private func tint(for alert: NWSAlert) -> Color {
    if isFireWeather(alert) {
      return DesignTokens.Palette.accentWarm
    }
    return NWSAlertStyle.tint(for: alert)
  }

  private func isFireWeather(_ alert: NWSAlert) -> Bool {
    let event = alert.event.lowercased()
    return event.contains("red flag") || event.contains("fire weather")
  }

  private func alertAccessibility(_ alert: NWSAlert) -> String {
    let head = alert.headline?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if head.isEmpty {
      return "\(alert.event). Opens alert details."
    }
    return "\(alert.event). \(head). Opens alert details."
  }
}
