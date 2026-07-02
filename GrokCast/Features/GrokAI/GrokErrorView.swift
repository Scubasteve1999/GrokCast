//  GrokErrorView.swift
//  GrokCast
//
//  Extracted from GrokAIView.swift (error handling block ~80-126 pre-edit snapshot; numbers are historical).
//  Reusable error state with retry button for the GrokAI feature.
//  Visuals/behavior: per provided extraction spec (unified red banner + capsule retry; label changes for storm). Eliminates the two near-identical retry button implementations (old red-tinted caption HStack with separate conditional retry capsules vs unified red banner + always-present retry).
//  Header style matches previous GrokAI extractions (GrokInputBar.swift, GrokQuickPromptButton.swift, GrokStormSpotterButton.swift, GrokAIResponseView.swift, GrokThinkingIndicator.swift).
//

import SwiftUI

struct GrokErrorView: View {
  let message: String
  let retryAction: () -> Void
  var isStormError: Bool = false

  var body: some View {
    VStack(spacing: 12) {
      Text(message)
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.85))
        .multilineTextAlignment(.center)

      Button(action: retryAction) {
        Text(isStormError ? "Try Again" : "Retry")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, 20)
          .padding(.vertical, 8)
          .background(
            Capsule()
              .fill(Color.red.opacity(0.85))
          )
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(
      RoundedRectangle(cornerRadius: 14)
        .fill(Color.red.opacity(0.15))
    )
  }
}

#Preview {
  VStack(spacing: 30) {
    GrokErrorView(
      message: "Something went wrong while analyzing the photo.",
      retryAction: {},
      isStormError: true
    )

    GrokErrorView(
      message: "Failed to get a response from Grok.",
      retryAction: {}
    )
  }
  .padding()
  .background(Color.black)
}
