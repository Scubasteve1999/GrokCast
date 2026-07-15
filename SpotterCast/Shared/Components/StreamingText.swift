import SwiftUI

struct StreamingText: View {
  let text: String
  let isStreaming: Bool

  @State private var displayedText: String = ""
  @State private var showCursor: Bool = true
  @State private var typingTask: Task<Void, Never>?
  @State private var cursorTask: Task<Void, Never>?

  var body: some View {
    Text(displayedText + (isStreaming ? (showCursor ? "|" : " ") : ""))
      .frame(maxWidth: .infinity, alignment: .leading)
      .animation(.easeInOut(duration: 0.6), value: showCursor)
      .onChange(of: text) { _, newValue in
        updateDisplayedText(to: newValue)
      }
      .onChange(of: isStreaming) { _, newValue in
        if newValue {
          startCursorAnimation()
        } else {
          cursorTask?.cancel()
          showCursor = false
          // Note: do *not* cancel typingTask here. Let any in-flight typer (started by prior onChange(text))
          // finish its captured target so final catch-up completes on natural end (or last partial on Stop).
          // | is already hidden via body ternary (keys off isStreaming). New deltas/reset still cancel prior.
        }
      }
      .onAppear {
        displayedText = text
        if isStreaming {
          startCursorAnimation()
        }
      }
      .onDisappear {
        typingTask?.cancel()
        cursorTask?.cancel()
      }
  }

  private func updateDisplayedText(to newText: String) {
    // Simple character-by-character effect driven by single cancellable Task.
    // Cancels prior work on new delta / reset (text shorter) to prevent races/dupes.
    // Current target always runs to completion (even after isStreaming=false on natural end
    // or Stop) so displayed catches up to final responseText / stopped partial. New onChange(text)
    // or reset still cancels the *prior* typer before starting for the new target. onDisappear
    // cancels for lifecycle.
    if newText.count <= displayedText.count {
      displayedText = newText
      typingTask?.cancel()
      typingTask = nil
      return
    }

    typingTask?.cancel()
    let target = newText
    typingTask = Task { @MainActor in
      while displayedText.count < target.count && !Task.isCancelled {
        let nextIndex = target.index(target.startIndex, offsetBy: displayedText.count)
        displayedText.append(target[nextIndex])
        try? await Task.sleep(for: .milliseconds(15))
      }
    }
  }

  private func startCursorAnimation() {
    cursorTask?.cancel()
    showCursor = true  // visible immediately on start/re-true (first 600ms on, then blink)
    cursorTask = Task { @MainActor in
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(600))
        showCursor.toggle()
      }
    }
  }
}
