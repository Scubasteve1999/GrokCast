import SwiftUI

/// Finished Sky Check chat reply: short answer, 2–3 facts, sources behind Details.
struct SkyCheckGlanceCard: View {
  let result: SkyCheckGlance.Result
  var onForecast: () -> Void
  var onRadar: () -> Void

  @State private var showDetails = false

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      markdownText(result.shortAnswer)
        .font(DesignTokens.Typography.body())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel(result.shortAnswer)

      if !result.changes.isEmpty {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
          ForEach(Array(result.changes.enumerated()), id: \.offset) { _, fact in
            HStack(alignment: .top, spacing: DesignTokens.Spacing.space8) {
              Text("•")
                .font(DesignTokens.Typography.callout())
                .foregroundStyle(DesignTokens.Palette.textSecondary)
                .accessibilityHidden(true)
              markdownText(fact)
                .font(DesignTokens.Typography.callout())
                .foregroundStyle(DesignTokens.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
          }
        }
      }

      if result.showsDetails, let details = result.details {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
          Button {
            Haptic.impact(.light)
            withAnimation(.easeInOut(duration: 0.2)) {
              showDetails.toggle()
            }
          } label: {
            HStack(spacing: DesignTokens.Spacing.space8) {
              Text(SkyCheckDeskCopy.detailsTitle)
                .font(DesignTokens.Typography.caption())
                .foregroundStyle(DesignTokens.Palette.textTertiary)
              Spacer(minLength: 0)
              Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                .font(DesignTokens.Typography.caption())
                .foregroundStyle(DesignTokens.Palette.textTertiary)
            }
            .frame(minHeight: DesignTokens.Layout.minHitTarget)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier(DayCastAccessibility.Grok.glanceDetails)
          .accessibilityLabel(SkyCheckDeskCopy.detailsTitle)
          .accessibilityHint(
            showDetails ? "Hides NWS and model sources" : "Shows NWS and model sources")
          .accessibilityAddTraits(.isButton)

          if showDetails {
            markdownText(details)
              .font(DesignTokens.Typography.caption())
              .foregroundStyle(DesignTokens.Palette.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }

      HStack(spacing: DesignTokens.Spacing.space8) {
        SkyCheckSolidChip(
          title: SkyCheckDeskCopy.forecastAction,
          identifier: DayCastAccessibility.Grok.glanceForecast,
          action: onForecast
        )
        SkyCheckSolidChip(
          title: SkyCheckDeskCopy.radarAction,
          identifier: DayCastAccessibility.Grok.glanceRadar,
          action: onRadar
        )
      }
    }
    .padding(.horizontal, DesignTokens.Spacing.space16)
    .padding(.vertical, DesignTokens.Spacing.space12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadiusMedium
    )
  }

  @ViewBuilder
  private func markdownText(_ content: String) -> some View {
    let display = SkyCheckMessageDisplay.markdown(content)
    if let attributed = try? AttributedString(markdown: display) {
      Text(attributed)
    } else {
      Text(display)
    }
  }
}
