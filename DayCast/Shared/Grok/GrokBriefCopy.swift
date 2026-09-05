import Foundation

/// Copy and chrome constants for Today's Take. The Today-tab card is gone;
/// Settings / paywall / tests still share these strings.
enum GrokBriefCopy {
  static let optionsAccessibilityLabel = "Today's Take options"
  static let collapsedLineLimit = 3
  static let expandCharacterThreshold = 120
  /// Not-Pro path. Settings BYOK is not the unlock story here.
  static let lockedCopy = "DayCast Pro includes Today's Take."

  static func expandControlTitle(isExpanded: Bool) -> String {
    isExpanded ? "Less" : "More"
  }

  static func showsExpandControl(for text: String) -> Bool {
    text.count > expandCharacterThreshold
  }
}
