//  GrokThinkingIndicator.swift
//  GrokCast
//
//  Extracted from GrokAIView.swift:68 (response area; original responseCard ~282 pre-extract; numbers are pre-edit snapshots).
//  Animated thinking indicator shown while Grok is generating a response.
//  Visuals/behavior per verbatim provided extraction body (fixed "Grok is thinking..." text + subheadline + Progress scale; simplified from prior conditional uppercase+tracking+storm mode in old responseCard).
//  Used exclusively from GrokAIResponseView. Header matches style/detail of prior extractions (GrokQuickPromptButton etc).
//
//  Note on simplification: per the provided verbatim bodies, this is rendered bare (no surrounding card bg/rounding) when the parent GrokAIResponseView is in isThinking state. Card styling is applied only once a response appears.
//

import SwiftUI

struct GrokThinkingIndicator: View {
  var body: some View {
    HStack(spacing: 8) {
      ProgressView()
        .tint(.white.opacity(0.7))
        .scaleEffect(0.8)

      Text("Thinking...")
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.7))
    }
    .padding(.vertical, 8)
  }
}

#Preview {
  GrokThinkingIndicator()
    .padding()
    .background(Color.black)
}
