//  GrokQuickPromptButton.swift
//  GrokCast
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
        .font(.subheadline.weight(.medium))
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
    .buttonStyle(.plain)
  }
}

#Preview {
  GrokQuickPromptButton(title: "What should I wear?") {
    // action
  }
  .padding()
  .background(Color.black)
}
