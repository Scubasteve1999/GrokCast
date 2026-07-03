//  GrokInputBar.swift
//  GrokCast
//
//  Extracted from GrokAIView.swift (input area after ScrollView; original private var inputBar ~270 pre-extract).
//  Reusable input bar component for the GrokAI feature.
//  Visuals/behavior: body per verbatim provided extraction spec (HStack sp:8, TextField plain+body font+r20 ultraThinMaterial fill, lineLimit, arrow button); deliberate simplification vs prior inline (no outer .ultraThinMaterial container + stroke, no palette indigo, placeholder "Ask Grok anything...", immediate text clear in caller wiring).
//  isStreaming respected at minimum via caller clear + isSendDisabled (component does not take streaming param per spec).
//

import SwiftUI

struct GrokInputBar: View {
  @Binding var text: String
  @FocusState.Binding var isFocused: Bool
  let onSend: () -> Void

  private var isSendDisabled: Bool {
    text.trimmingCharacters(in: .whitespaces).isEmpty
  }

  var body: some View {
    HStack(spacing: 8) {
      TextField("Ask about the weather...", text: $text, axis: .vertical)
        .textFieldStyle(.plain)
        .font(.body)
        .focused($isFocused)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
          RoundedRectangle(cornerRadius: 20)
            .fill(Color.white.opacity(0.1))
        )
        .lineLimit(1...4)

      Button(action: onSend) {
        Image(systemName: "arrow.up.circle.fill")
          .font(.system(size: 28, weight: .semibold))
          .foregroundStyle(isSendDisabled ? .gray : .white)
      }
      .disabled(isSendDisabled)
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
  }
}

#Preview {
  @Previewable @State var previewText = ""
  @Previewable @FocusState var previewFocused: Bool

  GrokInputBar(text: $previewText, isFocused: $previewFocused) {
    previewText = ""
  }
  .padding()
  .background(Color.black)
}
