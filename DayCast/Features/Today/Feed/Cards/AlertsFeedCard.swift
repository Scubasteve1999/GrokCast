import SwiftUI

struct AlertsFeedCard: View {
  let alerts: [NWSAlert]
  var sitsOnPhoto: Bool = false
  var onSelect: (NWSAlert) -> Void

  var body: some View {
    if Self.glanceChips(from: alerts).isEmpty {
      EmptyView()
    } else {
      cardBody
    }
  }

  private var cardBody: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      ForEach(Self.glanceChips(from: alerts)) { alert in
        Button {
          Haptic.impact(.light)
          onSelect(alert)
        } label: {
          HStack(spacing: DesignTokens.Spacing.space8) {
            Image(systemName: NWSAlertStyle.iconName(for: alert))
              .font(DesignTokens.Typography.subsection())
              .foregroundStyle(tint(for: alert))

            VStack(alignment: .leading, spacing: 2) {
              Text(Self.chipTitle(for: alert))
                .font(DesignTokens.Typography.subsection())
                .foregroundStyle(DesignTokens.Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
              Text(Self.chipUntil(for: alert))
                .font(DesignTokens.Typography.caption())
                .foregroundStyle(DesignTokens.Palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            }
            .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
              .font(DesignTokens.Typography.caption())
              .foregroundStyle(DesignTokens.Palette.textTertiary)
          }
          .padding(.horizontal, DesignTokens.Spacing.space12)
          .padding(.vertical, DesignTokens.Spacing.space8)
          .frame(
            maxWidth: .infinity,
            minHeight: TodayGlanceLayout.alertChipMinHeight,
            alignment: .leading
          )
          .background(
            sitsOnPhoto
              ? Color.black.opacity(0.46)
              : tint(for: alert).opacity(0.12)
          )
          .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
              .stroke(DesignTokens.Palette.cardHairline, lineWidth: DesignTokens.Card.strokeWidth)
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

  /// Today is one official chip. Outlook / MD / extra products stay on Alerts.
  static let maxGlanceChips = 1

  static func glanceChips(from alerts: [NWSAlert]) -> [NWSAlert] {
    let live = NWSAlertGrouping.representatives(from: alerts).filter { !$0.isExpired }
    return Array(live.sorted(by: Self.isMoreSevere).prefix(maxGlanceChips))
  }

  /// Warning > watch > advisory, then NWS `severityLevel`.
  static func isMoreSevere(_ lhs: NWSAlert, _ rhs: NWSAlert) -> Bool {
    if glanceRank(lhs) != glanceRank(rhs) {
      return glanceRank(lhs) > glanceRank(rhs)
    }
    return lhs.severityLevel > rhs.severityLevel
  }

  static func glanceRank(_ alert: NWSAlert) -> Int {
    if alert.isWarning || alert.isLifeThreatening { return 3 }
    if alert.isWatch { return 2 }
    return 1
  }

  static func chipTitle(for alert: NWSAlert) -> String {
    alert.event
  }

  static func chipUntil(for alert: NWSAlert) -> String {
    AlertsActiveCopy.untilLine(expires: alert.expires, areaDesc: nil)
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
