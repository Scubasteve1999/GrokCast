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
          Text("Next hour")
            .font(DesignTokens.Figma.Typography.subsectionLabel)
            .foregroundStyle(DesignTokens.Palette.textTertiary)
            .textCase(.uppercase)
            .tracking(DesignTokens.Typography.cardLabelTracking)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }

        if !summary.strip.isEmpty {
          MinutecastStrip(
            summary: summary,
            sourceLabel: sourceLabel,
            disagreementCaption: disagreementCaption
          )
        } else if let timingSentence, !timingSentence.isEmpty {
          HStack(alignment: .top, spacing: DesignTokens.Spacing.space8) {
            Image(systemName: summary.icon)
              .foregroundStyle(DesignTokens.Palette.accentCool)
            Text(timingSentence)
              .font(.subheadline)
              .foregroundStyle(DesignTokens.Palette.textPrimary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(DesignTokens.Spacing.space12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .cardStyle(cornerRadius: DesignTokens.Radius.small)
        } else {
          MinutecastStrip(
            summary: summary,
            sourceLabel: sourceLabel,
            disagreementCaption: disagreementCaption
          )
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Next hour. \(summary.message). Opens forecast.")
    .accessibilityAddTraits(.isButton)
  }
}

enum PrecipFeedVisibility {
  /// Meaningful precip content for the feed (not clear-sky empty shells).
  static func hasContent(summary: MinutecastSummary) -> Bool {
    switch summary.kind {
    case .clear:
      return false
    case .startsSoon, .ongoing, .stoppingSoon:
      return true
    }
  }

  /// Prefer the engine message as a timing sentence when bars are unavailable.
  static func timingSentence(for summary: MinutecastSummary) -> String? {
    guard hasContent(summary: summary) else { return nil }
    let trimmed = summary.message.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
