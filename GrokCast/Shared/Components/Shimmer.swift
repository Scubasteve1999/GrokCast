import SwiftUI

/// A reusable shimmer effect for skeleton loading.
/// Matches the dark tactical theme of GrokCast.
struct Shimmer: ViewModifier {
  @State private var phase: CGFloat = 0

  func body(content: Content) -> some View {
    content
      .overlay(
        GeometryReader { geometry in
          LinearGradient(
            gradient: Gradient(colors: [
              Color.white.opacity(0.0),
              Color.white.opacity(0.35),
              Color.white.opacity(0.0),
            ]),
            startPoint: .leading,
            endPoint: .trailing
          )
          .frame(width: geometry.size.width * 1.8)
          .offset(x: -geometry.size.width + (geometry.size.width * 1.8 * phase))
          .blendMode(.plusLighter)
        }
      )
      .mask(content)
      .onAppear {
        withAnimation(
          .linear(duration: 1.4)
            .repeatForever(autoreverses: false)
        ) {
          phase = 1
        }
      }
  }
}

extension View {
  /// Applies a subtle shimmer animation, ideal for skeleton loading in dark UIs.
  func shimmer() -> some View {
    self.modifier(Shimmer())
  }
}

/// A simple rounded rectangle skeleton block with shimmer.
struct ShimmerBlock: View {
  var width: CGFloat? = nil
  var height: CGFloat = 16
  var cornerRadius: CGFloat = 4

  var body: some View {
    RoundedRectangle(cornerRadius: cornerRadius)
      .fill(Color.white.opacity(0.12))
      .frame(width: width, height: height)
      .shimmer()
  }
}
