//  GrokStormSpotterButton.swift
//  DayCast
//
//  Extracted from GrokAIView.swift:191 (quickPromptsSection; original inline structs ~341).
//  Button used to trigger storm photo analysis in GrokAI.
//  Visuals/behavior identical (composition in horizontal scroll row); public CTA is a civilian sky/photo verb.
//

import SwiftUI

struct GrokStormSpotterButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: SkyCheckDeskCopy.photoGlyph)
          .font(DesignTokens.Typography.subsection())

        Text(SkyCheckDeskCopy.photoCTA)
          .font(DesignTokens.Typography.subsection())
          .tracking(DesignTokens.Typography.cardLabelTracking)
      }
      .foregroundStyle(DesignTokens.Palette.textPrimary)
      .padding(.horizontal, 16)
      .frame(minHeight: DesignTokens.Layout.minHitTarget)
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
    .accessibilityLabel(SkyCheckDeskCopy.photoCTA)
  }
}

#Preview {
  GrokStormSpotterButton {
    // tapped
  }
  .padding()
  .background(Color.black)
}
