//  TacticalCard.swift
//  GrokCast
//
//  Extracted from TodayView.swift as dedicated reusable component (Deep Polish – Today tab).
//  The canonical "tactical detail" card used for feels-like, humidity, wind, UV, precip, AQI, pollen, NWS etc.
//  Visuals: icon + uppercase label (small tracking), large bold rounded value.
//  Uses DesignTokens + .tacticalCard() (18pt radius, 0.045 fill / 0.08 stroke) for consistency with Forecast rows/headers and Today hero.
//  Paddings (16h/14v) provide breathing room matching polished Forecast rhythm.
//  Reusable across tabs/features as the standard small info card in the dark professional design system.
//
//  No behavior changes. Presentation polish + tokenization only.

import SwiftUI

struct TacticalCard: View {
  let label: String
  let value: String
  let icon: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(DesignTokens.Palette.textSecondary)
        Text(label)
          .font(.system(size: 10, weight: .semibold))
          .tracking(DesignTokens.Typography.cardLabelTracking)
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }

      Text(value)
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .monospacedDigit()
        .lineLimit(1)
    }
    .padding(.horizontal, DesignTokens.Spacing.space20)
    .padding(.vertical, DesignTokens.Spacing.space20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tacticalCard()
  }
}
