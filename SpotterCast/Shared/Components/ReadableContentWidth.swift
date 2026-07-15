import SwiftUI
import UIKit

/// Centers scrollable and form content on iPad while keeping phone layouts edge-to-edge.
enum ReadableContentWidth {
  static let compact: CGFloat = 600
  static let standard: CGFloat = 680
  /// Non-adaptive tabs (Settings, Locations) — unchanged from pre-layout work.
  static let wide: CGFloat = 760
}

/// Shared thresholds for responsive multi-column layouts on large screens.
enum AdaptiveLayout {
  /// Single cap used for adaptive `maxWidth` and two-column threshold (keeps them aligned).
  static let contentCap: CGFloat = 700

  static var twoColumnMinWidth: CGFloat { contentCap }

  static func isLayoutBranchingReady(width: CGFloat) -> Bool {
    width > 0
  }

  static func isPotentialAdaptiveLayout(horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
    UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
  }

  /// True while iPad regular layout is waiting for the first capped width measurement.
  static func awaitingWidthMeasurement(
    width: CGFloat,
    horizontalSizeClass: UserInterfaceSizeClass?
  ) -> Bool {
    isPotentialAdaptiveLayout(horizontalSizeClass: horizontalSizeClass)
      && !isLayoutBranchingReady(width: width)
  }

  static func prefersTwoColumn(
    width: CGFloat,
    horizontalSizeClass: UserInterfaceSizeClass?
  ) -> Bool {
    guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
    guard horizontalSizeClass == .regular else { return false }
    // Safe narrow default until the first capped measurement arrives.
    guard isLayoutBranchingReady(width: width) else { return false }
    return width >= twoColumnMinWidth
  }
}

private struct AdaptiveContainerWidthKey: EnvironmentKey {
  static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
  /// Width of the nearest adaptive layout container (set by `adaptiveContainerWidth()`).
  var adaptiveContainerWidth: CGFloat {
    get { self[AdaptiveContainerWidthKey.self] }
    set { self[AdaptiveContainerWidthKey.self] = newValue }
  }
}

private struct ContainerWidthPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

struct ReadableContentModifier: ViewModifier {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var maxWidth: CGFloat = ReadableContentWidth.standard

  func body(content: Content) -> some View {
    Group {
      if horizontalSizeClass == .regular {
        content
          .frame(maxWidth: maxWidth)
          .frame(maxWidth: .infinity)
      } else {
        content
      }
    }
  }
}

/// Reports measured width to descendants and applies readable max-width on regular size class.
struct AdaptiveContainerWidthModifier: ViewModifier {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var measuredWidth: CGFloat = 0

  var maxWidth: CGFloat = AdaptiveLayout.contentCap

  func body(content: Content) -> some View {
    Group {
      if horizontalSizeClass == .regular {
        content
          .frame(maxWidth: maxWidth)
      } else {
        content
      }
    }
    .background {
      GeometryReader { geometry in
        Color.clear.preference(key: ContainerWidthPreferenceKey.self, value: geometry.size.width)
      }
    }
    .onPreferenceChange(ContainerWidthPreferenceKey.self) { measuredWidth = $0 }
    .environment(\.adaptiveContainerWidth, measuredWidth)
    .frame(maxWidth: .infinity)
  }
}

extension View {
  func readableContentWidth(_ maxWidth: CGFloat = ReadableContentWidth.standard) -> some View {
    modifier(ReadableContentModifier(maxWidth: maxWidth))
  }

  /// Measures available width for adaptive layouts while capping and centering on iPad.
  func adaptiveContainerWidth(_ maxWidth: CGFloat = AdaptiveLayout.contentCap) -> some View {
    modifier(AdaptiveContainerWidthModifier(maxWidth: maxWidth))
  }
}

// MARK: - Adaptive layout previews (manual QA at common iPad widths)

#if DEBUG
  private struct AdaptiveWidthProbe: View {
    @Environment(\.adaptiveContainerWidth) private var width
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let label: String

    var body: some View {
      let twoColumn = AdaptiveLayout.prefersTwoColumn(
        width: width,
        horizontalSizeClass: horizontalSizeClass
      )
      VStack(alignment: .leading, spacing: 8) {
        Text(label).font(.headline)
        Text("measured: \(Int(width))pt")
        Text("two-column: \(twoColumn ? "yes" : "no")")
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
      .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
      .adaptiveContainerWidth()
    }
  }

  #Preview("Adaptive 500pt") {
    AdaptiveWidthProbe(label: "500pt column")
      .frame(width: 500, height: 200)
      .environment(\.horizontalSizeClass, .regular)
  }

  #Preview("Adaptive 650pt") {
    AdaptiveWidthProbe(label: "650pt column")
      .frame(width: 650, height: 200)
      .environment(\.horizontalSizeClass, .regular)
  }

  #Preview("Adaptive 700pt") {
    AdaptiveWidthProbe(label: "700pt column")
      .frame(width: 700, height: 200)
      .environment(\.horizontalSizeClass, .regular)
  }

  #Preview("Adaptive 1024pt") {
    AdaptiveWidthProbe(label: "1024pt column")
      .frame(width: 1024, height: 200)
      .environment(\.horizontalSizeClass, .regular)
  }

  #Preview("Adaptive 834pt (iPad Pro 11-inch)") {
    AdaptiveWidthProbe(label: "iPad Pro 11-inch")
      .frame(width: 834, height: 200)
      .environment(\.horizontalSizeClass, .regular)
  }
#endif
