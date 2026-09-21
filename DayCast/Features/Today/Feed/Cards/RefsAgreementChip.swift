import SwiftUI

/// Thin timing chip. A window and a tier, not a map and not a minute clock.
/// Not `HonestyStrip`. Not `ForecastEraNotice`.
struct RefsAgreementChip: View {
  let payload: RefsAgreementPayload
  var timeZone: TimeZone = .current

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
      Text(RefsAgreementCopy.tierTitle(payload.agreementTier))
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
      Text(RefsAgreementCopy.primaryLine(payload, timeZone: timeZone))
        .font(
          payload.timingWindow == nil
            ? DesignTokens.Typography.callout() : DesignTokens.Typography.headline()
        )
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
      let sources = RefsAgreementCopy.sourceLine(payload.sources.labels)
      if !sources.isEmpty {
        Text(sources)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      }
      if payload.timingWindow != nil,
        let sentence = payload.divergence?.sentence,
        payload.divergence?.present == true
      {
        Text(sentence)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      if payload.stub == true {
        Text("Sample")
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }
    }
    .padding(.horizontal, DesignTokens.Spacing.space12)
    .padding(.vertical, DesignTokens.Spacing.space12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
        .fill(DesignTokens.Palette.cardBackground)
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel(RefsAgreementCopy.accessibility(payload, timeZone: timeZone))
    .accessibilityIdentifier(DayCastAccessibility.Today.refsAgreement)
  }
}
