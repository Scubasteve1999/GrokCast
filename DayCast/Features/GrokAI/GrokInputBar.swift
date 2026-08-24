//  GrokInputBar.swift
//  DayCast
//
//  Extracted from GrokAIView.swift (input area after ScrollView; original private var inputBar ~270 pre-extract).
//  Reusable input bar component for the GrokAI feature.
//  Visuals/behavior: body per verbatim provided extraction spec (HStack sp:8, TextField plain+body font+r20 ultraThinMaterial fill, lineLimit, arrow button); deliberate simplification vs prior inline (no outer .ultraThinMaterial container + stroke, no palette indigo, placeholder "Ask Grok anything...", immediate text clear in caller wiring).
//  isStreaming respected at minimum via caller clear + isSendDisabled (component does not take streaming param per spec).
//

import SwiftUI

enum GrokInputBarLayout {
  case standard
  /// Compact Sky Check: elevated pill, secondary placeholder on dark fill.
  case figma
}

struct GrokInputBar: View {
  @Binding var text: String
  @FocusState.Binding var isFocused: Bool
  var layout: GrokInputBarLayout = .standard
  let onSend: () -> Void

  private var isSendDisabled: Bool {
    text.trimmingCharacters(in: .whitespaces).isEmpty
  }

  /// Gray system placeholder washes out on `cardElevated`. Secondary still
  /// reads quieter than typed primary.
  private var weatherPrompt: Text {
    Text("Ask about the weather…")
      .foregroundStyle(DesignTokens.Palette.textSecondary)
  }

  var body: some View {
    switch layout {
    case .standard:
      standardBar
    case .figma:
      figmaBar
    }
  }

  private var figmaBar: some View {
    HStack(spacing: DesignTokens.Spacing.space8) {
      TextField(
        "Ask about the weather…",
        text: $text,
        prompt: weatherPrompt,
        axis: .vertical
      )
      .textFieldStyle(.plain)
      .font(DesignTokens.Typography.body())
      .foregroundStyle(DesignTokens.Palette.textPrimary)
      .focused($isFocused)
      .accessibilityIdentifier(DayCastAccessibility.Grok.chatField)
      .lineLimit(1...4)
      .submitLabel(.send)
      .onSubmit(send)

      Button(action: send) {
        Image(systemName: "arrow.up.circle.fill")
          .font(DesignTokens.Typography.studioTitle())
          .symbolRenderingMode(.palette)
          .foregroundStyle(
            isSendDisabled ? DesignTokens.Palette.textTertiary : DesignTokens.Palette.bgPrimary,
            isSendDisabled ? DesignTokens.Palette.cardStroke : DesignTokens.Palette.accent
          )
      }
      .disabled(isSendDisabled)
      .accessibilityLabel("Send")
    }
    .padding(.horizontal, DesignTokens.Spacing.space16)
    .padding(.vertical, DesignTokens.Spacing.space12)
    .cardStyle(
      background: DesignTokens.Palette.cardElevated,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: 24
    )
  }

  private var standardBar: some View {
    HStack(spacing: 8) {
      TextField(
        "Ask about the weather…",
        text: $text,
        prompt: weatherPrompt,
        axis: .vertical
      )
      .textFieldStyle(.plain)
      .font(DesignTokens.Typography.body())
      .foregroundStyle(DesignTokens.Palette.textPrimary)
      .focused($isFocused)
      .accessibilityIdentifier(DayCastAccessibility.Grok.chatField)
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 20)
          .fill(Color.white.opacity(0.1))
      )
      .lineLimit(1...4)
      .submitLabel(.send)
      .onSubmit(send)

      Button(action: send) {
        Image(systemName: "arrow.up.circle.fill")
          .font(DesignTokens.Typography.title())
          .foregroundStyle(
            isSendDisabled ? DesignTokens.Palette.textTertiary : DesignTokens.Palette.textPrimary)
      }
      .disabled(isSendDisabled)
      .accessibilityLabel("Send")
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
  }

  private func send() {
    guard !isSendDisabled else { return }
    isFocused = false
    onSend()
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
