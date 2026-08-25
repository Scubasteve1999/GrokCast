import SwiftUI

struct AlertsFeedCard: View {
  let alerts: [NWSAlert]
  var severeContext: SevereWeatherContext? = nil
  var onSelect: (NWSAlert) -> Void

  var body: some View {
    if alerts.isEmpty && severeContext == nil {
      EmptyView()
    } else {
      cardBody
    }
  }

  private var cardBody: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      if let severeContext {
        SevereContextCard(context: severeContext)
      }

      ForEach(Self.glanceChips(from: alerts)) { alert in
        Button {
          Haptic.impact(.light)
          onSelect(alert)
        } label: {
          HStack(spacing: DesignTokens.Spacing.space8) {
            Image(systemName: NWSAlertStyle.iconName(for: alert))
              .font(DesignTokens.Typography.subsection())
              .foregroundStyle(tint(for: alert))

            Text(Self.chipTitle(for: alert, in: alerts))
              .font(DesignTokens.Typography.subsection())
              .foregroundStyle(DesignTokens.Palette.textPrimary)
              .lineLimit(1)
              .minimumScaleFactor(0.85)
              .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
              .font(DesignTokens.Typography.caption())
              .foregroundStyle(DesignTokens.Palette.textTertiary)
          }
          .padding(.horizontal, DesignTokens.Spacing.space12)
          .frame(
            maxWidth: .infinity,
            minHeight: TodayGlanceLayout.alertChipMinHeight,
            alignment: .leading
          )
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
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(DayCastAccessibility.Today.alertsSlot)
  }

  /// Today is a chip rail, not the Alerts list. Collapse duplicate events; cap at 2.
  static let maxGlanceChips = 2

  static func glanceChips(from alerts: [NWSAlert]) -> [NWSAlert] {
    var seen = Set<String>()
    var chips: [NWSAlert] = []
    for alert in alerts {
      if seen.insert(alert.event).inserted {
        chips.append(alert)
      }
      if chips.count == maxGlanceChips { break }
    }
    return chips
  }

  static func chipTitle(for alert: NWSAlert, in alerts: [NWSAlert]) -> String {
    let count = alerts.filter { $0.event == alert.event }.count
    return count > 1 ? "\(alert.event) · \(count)" : alert.event
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
