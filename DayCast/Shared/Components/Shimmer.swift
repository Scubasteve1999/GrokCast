import SwiftUI

/// Soft loading placeholder — no sweeping “arcade” shimmer.
struct Shimmer: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var pulse = false

  func body(content: Content) -> some View {
    content
      .opacity(reduceMotion ? 0.55 : (pulse ? 0.45 : 0.70))
      .onAppear {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
          pulse = true
        }
      }
  }
}

extension View {
  func shimmer() -> some View {
    self.modifier(Shimmer())
  }
}

/// Solid skeleton block with optional soft pulse.
struct ShimmerBlock: View {
  var width: CGFloat? = nil
  var height: CGFloat = 16
  var cornerRadius: CGFloat = 8

  var body: some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      .fill(DesignTokens.Palette.cardElevated)
      .frame(width: width, height: height)
      .shimmer()
  }
}
