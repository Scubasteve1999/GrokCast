import UIKit

enum Haptic {
  private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
  private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
  private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
  private static let softImpact = UIImpactFeedbackGenerator(style: .soft)
  private static let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
  private static let notificationGenerator = UINotificationFeedbackGenerator()
  private static let selectionGenerator = UISelectionFeedbackGenerator()

  private static var shouldSkip: Bool {
    UIAccessibility.isReduceMotionEnabled
  }

  static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
    guard !shouldSkip else { return }
    switch style {
    case .light:
      lightImpact.impactOccurred()
    case .heavy:
      heavyImpact.impactOccurred()
    case .soft:
      softImpact.impactOccurred()
    case .rigid:
      rigidImpact.impactOccurred()
    case .medium:
      fallthrough
    @unknown default:
      mediumImpact.impactOccurred()
    }
  }

  static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
    guard !shouldSkip else { return }
    notificationGenerator.notificationOccurred(type)
  }

  static func selection() {
    guard !shouldSkip else { return }
    selectionGenerator.selectionChanged()
  }
}
