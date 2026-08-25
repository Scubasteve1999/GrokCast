//  GrokQuickPromptButton.swift
//  DayCast
//
//  Extracted from GrokAIView.swift:191 (quickPromptsSection; original inline structs ~341).
//  Reusable quick prompt button used in the GrokAI feature.
//  Visuals/behavior identical (composition in horizontal scroll row); styling per provided extraction bodies (DesignTokens + subheadline).
//

import SwiftUI

struct GrokQuickPromptButton: View {
  let title: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(DesignTokens.Typography.callout())
        .tracking(DesignTokens.Typography.cardLabelTracking)
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .padding(.horizontal, DesignTokens.Spacing.space12)
        .frame(maxWidth: .infinity, minHeight: DesignTokens.Layout.minHitTarget, alignment: .center)
        .background(
          Capsule()
            .fill(DesignTokens.Palette.cardElevated)
        )
        .overlay(
          Capsule()
            .stroke(
              DesignTokens.Palette.cardStroke,
              lineWidth: DesignTokens.Card.strokeWidth
            )
        )
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  GrokQuickPromptButton(title: SkyCheckDeskCopy.outlook.title) {
    // action
  }
  .padding()
  .background(Color.black)
}
