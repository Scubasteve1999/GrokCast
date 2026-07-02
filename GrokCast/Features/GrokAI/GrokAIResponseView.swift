//  GrokAIResponseView.swift
//  GrokCast
//
//  Extracted from GrokAIView.swift:68 (response area; original responseCard ~282 pre-extract; numbers are pre-edit snapshots).
//  Main container for displaying Grok's response or thinking state.
//  Delegates to GrokThinkingIndicator (when isThinking) or GrokResponseCard (private).
//  GrokResponseCard uses StreamingText(text:isStreaming) branch when streaming (minimal adaptation to preserve original typing/cursor from pre-extract StreamingText usage); Text otherwise. Padding/bg per provided spec (no overlay stroke to match verbatim).
//  Visuals/behavior of response area intended identical post-extract; see caller site for wiring. Header style matches GrokInputBar, Grok*Button extractions.
//
//  Deliberate simplification (per verbatim provided spec): when isThinking we render bare GrokThinkingIndicator() with no card wrapper/bg/rounding.
//  The GrokResponseCard (with padding, background 0.06 r14, textSelection) appears only for actual responses. This matches the extraction bodies exactly.
//  Inner structure of GrokResponseCard (VStack spacing:6 + duplicated font/foreground on the if/else branches) kept verbatim; the if-isStreaming branch was the minimal adaptation required to preserve typing/cursor behavior. Spacing and duplication are harmless for current single-child use.
//

import SwiftUI

struct GrokAIResponseView: View {
  let response: String?
  let isThinking: Bool
  let isStreaming: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if isThinking {
        GrokThinkingIndicator()
      } else if let response = response, !response.isEmpty {
        GrokResponseCard(text: response, isStreaming: isStreaming)
      }
    }
  }
}

// Private wrapper to keep styling consistent
private struct GrokResponseCard: View {
  let text: String
  let isStreaming: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if isStreaming {
        StreamingText(text: text, isStreaming: isStreaming)
          .font(.body)
          .foregroundStyle(.white.opacity(0.9))
      } else {
        Text(text)
          .font(.body)
          .foregroundStyle(.white.opacity(0.9))
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 14)
        .fill(Color.white.opacity(0.06))
    )
    .textSelection(.enabled)
  }
}

#Preview {
  VStack(spacing: 20) {
    GrokAIResponseView(response: nil, isThinking: true, isStreaming: false)

    GrokAIResponseView(
      response: "This is a sample response from Grok about current weather conditions.",
      isThinking: false,
      isStreaming: false
    )
  }
  .padding()
  .background(Color.black)
}
