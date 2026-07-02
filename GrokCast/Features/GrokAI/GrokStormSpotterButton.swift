//  GrokStormSpotterButton.swift
//  GrokCast
//
//  Extracted from GrokAIView.swift:191 (quickPromptsSection; original inline structs ~341).
//  Button used to trigger storm photo analysis in GrokAI.
//  Visuals/behavior identical (composition in horizontal scroll row); "Analyze Storm Photo" label per verbatim provided extraction body.
//

import SwiftUI

struct GrokStormSpotterButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: "camera.fill")
          .font(.system(size: 15, weight: .semibold))

        Text("Analyze Storm Photo")
          .font(.subheadline.weight(.semibold))
          .tracking(DesignTokens.Typography.cardLabelTracking)
      }
      .foregroundStyle(.white)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(
        Capsule()
          .fill(Color.white.opacity(0.1))
      )
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  GrokStormSpotterButton {
    // tapped
  }
  .padding()
  .background(Color.black)
}
