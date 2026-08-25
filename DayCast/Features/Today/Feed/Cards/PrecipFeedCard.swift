import SwiftUI

struct PrecipFeedCard: View {
  let summary: MinutecastSummary
  var sourceLabel: String? = nil
  var disagreementCaption: String? = nil
  /// Plain rain-timing sentence when strip is empty but message is still useful.
  var timingSentence: String? = nil
  var onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
        HStack {
          Text(PrecipOutlookCopy.title)
            .font(DesignTokens.Typography.subsection())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
            .tracking(DesignTokens.Typography.cardLabelTracking)
          Spacer()
          Image(systemName: "chevron.right")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }

        if summary.kind != .clear, !summary.strip.isEmpty {
          MinutecastStrip(
            summary: summary,
            sourceLabel: sourceLabel,
            disagreementCaption: disagreementCaption
          )
        } else if let timingSentence, !timingSentence.isEmpty {
          Text(timingSentence)
            .font(DesignTokens.Typography.body())
            .foregroundStyle(DesignTokens.Palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          MinutecastStrip(
            summary: summary,
            sourceLabel: sourceLabel,
            disagreementCaption: disagreementCaption
          )
        }
      }
      .padding(DesignTokens.Spacing.space16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .weatherModuleStyle()
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      Self.accessibilityLabel(
        message: summary.message,
        disagreementCaption: disagreementCaption
      )
    )
    .accessibilityAddTraits(.isButton)
  }

  /// One VoiceOver string for the card. Children stay visual-only.
  static func accessibilityLabel(
    message: String,
    disagreementCaption: String? = nil
  ) -> String {
    let caption = disagreementCaption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if caption.isEmpty {
      return "\(PrecipOutlookCopy.title). \(message). Opens forecast."
    }
    return "\(PrecipOutlookCopy.title). \(message). \(caption). Opens forecast."
  }
}

enum PrecipFeedVisibility {
  /// Wet Next 2 Hours content. Drives story-day radar teaser copy, not feed order.
  static func hasContent(summary: MinutecastSummary) -> Bool {
    switch summary.kind {
    case .clear:
      return false
    case .startsSoon, .ongoing, .stoppingSoon:
      return true
    }
  }

  /// Next-event card, including "Dry for the next 2 hours". Hide only when data is missing.
  static func showsCard(summary: MinutecastSummary) -> Bool {
    if summary.kind == .clear && summary.strip.isEmpty { return false }
    return !summary.message.isEmpty
  }

  /// Prefer the engine message as a timing sentence when bars are unavailable.
  static func timingSentence(for summary: MinutecastSummary) -> String? {
    if summary.kind == .clear && summary.strip.isEmpty { return nil }
    let trimmed = summary.message.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
