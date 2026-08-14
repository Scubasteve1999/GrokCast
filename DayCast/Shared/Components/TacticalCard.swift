//  TacticalCard.swift
//  DayCast
//
//  Extracted from TodayView.swift as dedicated reusable component (Deep Polish – Today tab).
//  The canonical "tactical detail" card used for feels-like, humidity, wind, UV, precip, AQI, pollen, NWS etc.
//  Visuals: icon + uppercase label (small tracking), large bold rounded value.
//  Uses DesignTokens + .dayCastCard() (medium radius, shared card chrome).
//  Reusable across tabs/features as the standard small info card in the dark professional design system.
//
//  No behavior changes. Presentation polish + tokenization only.

import SwiftUI

struct TacticalCard: View {
  let label: String
  let value: String
  let icon: String

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      HStack(spacing: DesignTokens.Spacing.space8) {
        Image(systemName: icon)
          .font(DesignTokens.Typography.symbol())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
        Text(label)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      }

      Text(value)
        .font(DesignTokens.Typography.metric())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .monospacedDigit()
        .lineLimit(1)
    }
    .padding(DesignTokens.Spacing.space16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .dayCastCard()
  }
}
