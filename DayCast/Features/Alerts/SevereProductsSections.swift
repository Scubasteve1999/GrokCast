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
      if !context.localStormReports.isEmpty {
        lsrSection
      }
    }
  }

  private var outlookSection: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
      FigmaAccentSectionLabel(
        title: "DAY 1 OUTLOOK",
        icon: "cloud.bolt.rain.fill",
        color: outlookColor
      )

      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
        Text(context.day1Outlook.category.displayName.uppercased())
          .font(DesignTokens.Typography.headline())
          .foregroundStyle(DesignTokens.Palette.textPrimary)

        Text(context.day1Outlook.summaryLine)
          .font(DesignTokens.Typography.callout())
          .foregroundStyle(DesignTokens.Palette.textSecondary)

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
        stroke: DesignTokens.Palette.cardStroke,
        cornerRadius: DesignTokens.Card.cornerRadiusMedium
      )
    }
  }

  private var mdSection: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
      FigmaAccentSectionLabel(
        title: "MESOSCALE DISCUSSIONS",
        icon: "text.bubble.fill",
        color: DesignTokens.Palette.warning
      )

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
            stroke: DesignTokens.Palette.cardStroke,
            cornerRadius: DesignTokens.Card.cornerRadiusMedium
          )
        }
      }
    }
  }

  private var lsrSection: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
      FigmaAccentSectionLabel(
        title: "NEARBY STORM REPORTS",
        icon: "mappin.and.ellipse",
        color: DesignTokens.Palette.danger
      )

      VStack(spacing: DesignTokens.Spacing.space12) {
        ForEach(context.localStormReports.prefix(8)) { report in
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
            stroke: DesignTokens.Palette.cardStroke,
            cornerRadius: DesignTokens.Card.cornerRadiusMedium
          )
        }
      }
    }
  }

  private var outlookColor: Color {
    switch context.day1Outlook.category {
    case .none, .generalThunderstorm: DesignTokens.Palette.textSecondary
    case .marginal: DesignTokens.Palette.success
    case .slight: DesignTokens.Palette.warning
    case .enhanced, .moderate, .high: DesignTokens.Palette.danger
    }
  }
}

/// Compact Today-tab severe context card.
struct SevereContextCard: View {
  let context: SevereWeatherContext

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      HStack(spacing: DesignTokens.Spacing.space8) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(DesignTokens.Typography.metric())
          .foregroundStyle(DesignTokens.Palette.warning)
        Text("Severe weather")
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        Spacer()
      }

      if context.day1Outlook.isMeaningful {
        Text(context.day1Outlook.summaryLine)
          .font(DesignTokens.Typography.subsection())
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
      stroke: DesignTokens.Palette.warning.opacity(0.45),
      cornerRadius: DesignTokens.Card.cornerRadiusMedium
    )
  }
}
