import SwiftUI

/// SPC outlook / MD / LSR sections for the Alerts tab (data-first phase 1 UI).
struct SevereProductsSections: View {
  let context: SevereWeatherContext

  var body: some View {
    Group {
      if context.day1Outlook.isMeaningful {
        outlookSection
      }
      if !context.mesoscaleDiscussions.isEmpty {
        mdSection
      }
    }
  }

  private var outlookSection: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
      Text("Day 1 Outlook")
        .font(DesignTokens.Typography.subsection())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)

      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
        Text(context.day1Outlook.category.displayName)
          .font(DesignTokens.Typography.headline())
          .foregroundStyle(outlookColor)

        Text(context.day1Outlook.summaryLine)
          .font(DesignTokens.Typography.body())
          .foregroundStyle(DesignTokens.Palette.textPrimary)

        if let detail = context.day1Outlook.labelDetail, !detail.isEmpty {
          Text(detail)
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
      }
      .padding(DesignTokens.Spacing.space16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .cardStyle(
        background: DesignTokens.Palette.cardBackground,
        stroke: DesignTokens.Palette.cardHairline,
        cornerRadius: DesignTokens.Card.cornerRadiusMedium
      )
    }
  }

  private var mdSection: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
      Text("Mesoscale Discussions")
        .font(DesignTokens.Typography.subsection())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)

      VStack(spacing: DesignTokens.Spacing.space12) {
        ForEach(context.mesoscaleDiscussions.prefix(6)) { md in
          VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
            Text(md.title)
              .font(DesignTokens.Typography.subsection())
              .foregroundStyle(DesignTokens.Palette.textPrimary)
            if let detail = md.detailLine {
              Text(detail)
                .font(DesignTokens.Typography.caption())
                .foregroundStyle(DesignTokens.Palette.textSecondary)
                .lineLimit(3)
            }
          }
          .padding(DesignTokens.Spacing.space16)
          .frame(maxWidth: .infinity, alignment: .leading)
          .cardStyle(
            background: DesignTokens.Palette.cardBackground,
            stroke: DesignTokens.Palette.cardHairline,
            cornerRadius: DesignTokens.Card.cornerRadiusMedium
          )
        }
      }
    }
  }

  private var outlookColor: Color {
    SevereOutlookAccent.color(for: context.day1Outlook.category)
  }
}

/// Spotter-mode LSR list. Hidden unless Settings → Storm reports is on.
struct StormReportsSection: View {
  let reports: [SPCLocalStormReport]

  var body: some View {
    if !reports.isEmpty {
      VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
        Text("Nearby Storm Reports")
          .font(DesignTokens.Typography.subsection())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityAddTraits(.isHeader)

        VStack(spacing: DesignTokens.Spacing.space12) {
          ForEach(reports.prefix(8)) { report in
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
              Text(report.title)
                .font(DesignTokens.Typography.subsection())
                .foregroundStyle(DesignTokens.Palette.textPrimary)
              if !report.subtitle.isEmpty {
                Text(report.subtitle)
                  .font(DesignTokens.Typography.caption())
                  .foregroundStyle(DesignTokens.Palette.textSecondary)
                  .lineLimit(2)
              }
              if let remarks = report.remarks, !remarks.isEmpty {
                Text(remarks)
                  .font(DesignTokens.Typography.micro())
                  .foregroundStyle(DesignTokens.Palette.textTertiary)
                  .lineLimit(2)
              }
            }
            .padding(DesignTokens.Spacing.space16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(
              background: DesignTokens.Palette.cardBackground,
              stroke: DesignTokens.Palette.cardHairline,
              cornerRadius: DesignTokens.Card.cornerRadiusMedium
            )
          }
        }
      }
      .accessibilityIdentifier(DayCastAccessibility.Alerts.stormReports)
    }
  }
}

enum StormReportsVisibility {
  static func isSectionVisible(reportCount: Int, preferenceEnabled: Bool) -> Bool {
    preferenceEnabled && reportCount > 0
  }
}

enum StormReportsPreference {
  static let key = "daycast_storm_reports_enabled"

  /// Overridable so tests run against an isolated suite. The unit-test bundle is
  /// hosted by the app and shares its `standard` domain.
  nonisolated(unsafe) static var store: UserDefaults = .standard

  static var isEnabled: Bool {
    get { store.bool(forKey: key) }
    set { store.set(newValue, forKey: key) }
  }
}

/// Compact Today-tab severe context card.
struct SevereContextCard: View {
  let context: SevereWeatherContext

  private var hasNWSSevere: Bool {
    context.alerts.contains { $0.isSevereEvent && !$0.isExpired }
  }

  private var outlookColor: Color {
    SevereOutlookAccent.color(for: context.day1Outlook.category)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      HStack(spacing: DesignTokens.Spacing.space8) {
        Image(systemName: hasNWSSevere ? "exclamationmark.triangle.fill" : "cloud.bolt.rain.fill")
          .font(DesignTokens.Typography.metric())
          .foregroundStyle(hasNWSSevere ? DesignTokens.Palette.warning : outlookColor)
          .accessibilityHidden(true)
        Text(hasNWSSevere ? "Severe weather" : AlertsHonesty.todayOutlookCardHeading)
          .font(DesignTokens.Typography.subsection())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        Spacer()
      }

      if context.day1Outlook.isMeaningful {
        Text(context.day1Outlook.summaryLine)
          .font(DesignTokens.Typography.headline())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
      }

      if let md = context.mesoscaleDiscussions.first {
        Text(md.todayCardLine)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .lineLimit(2)
      }

      if context.alerts.contains(where: { $0.isSevereEvent && !$0.isExpired }) {
        let count = context.alerts.filter { $0.isSevereEvent && !$0.isExpired }.count
        Text("\(count) active watch/warning\(count == 1 ? "" : "s") for this location")
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }
    }
    .padding(DesignTokens.Spacing.space16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .elevatedCardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: hasNWSSevere
        ? DesignTokens.Palette.warning.opacity(0.45)
        : outlookColor.opacity(0.45),
      cornerRadius: DesignTokens.Card.cornerRadiusMedium
    )
    .accessibilityElement(children: .combine)
  }
}

private enum SevereOutlookAccent {
  static func color(for category: SPCOutlookCategory) -> Color {
    switch category {
    case .none:
      DesignTokens.Palette.textSecondary
    case .generalThunderstorm, .marginal:
      DesignTokens.Palette.accentWarm
    case .slight:
      DesignTokens.Palette.warning
    case .enhanced, .moderate, .high:
      DesignTokens.Palette.danger
    }
  }
}
