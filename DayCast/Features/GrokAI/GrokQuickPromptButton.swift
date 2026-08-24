//  GrokQuickPromptButton.swift
//  DayCast
//
//  Extracted from GrokAIView.swift:191 (quickPromptsSection; original inline structs ~341).
//  Reusable quick prompt button used in the GrokAI feature.
//  Visuals/behavior identical (composition in horizontal scroll row); styling per provided extraction bodies (DesignTokens + subheadline).
//

import SwiftUI

enum GrokQuickPromptLayout {
  case chip
  /// Figma Briefing Studio: icon + label in a grid tile.
  case figmaTile
}

struct GrokQuickPromptButton: View {
  let title: String
  var icon: String? = nil
  var layout: GrokQuickPromptLayout = .chip
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      switch layout {
      case .chip:
        chipLabel
      case .figmaTile:
        figmaTileLabel
      }
    }
    .buttonStyle(.plain)
  }

  private var chipLabel: some View {
    Text(title)
      .font(DesignTokens.Typography.callout())
      .tracking(DesignTokens.Typography.cardLabelTracking)
      .foregroundStyle(.white.opacity(DesignTokens.Opacity.iconWhite))
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .center)
      .background(
        Capsule()
          .fill(Color.white.opacity(0.08))
      )
  }

  private var figmaTileLabel: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      Image(systemName: icon ?? "sparkles")
        .font(DesignTokens.Typography.symbol(16))
        .foregroundStyle(DesignTokens.Palette.accent)

      Text(title)
        .font(DesignTokens.Typography.micro())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .multilineTextAlignment(.leading)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
    .padding(14)
    .cardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadiusMedium
    )
  }
}

#Preview {
  GrokQuickPromptButton(title: SkyCheckDeskCopy.outlook.title) {
    // action
  }
  .padding()
  .background(Color.black)
}
