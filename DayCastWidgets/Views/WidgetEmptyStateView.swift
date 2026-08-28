import SwiftUI

struct WidgetEmptyStateView: View {
  let reason: WidgetEmptyReason
  let style: WidgetStyle

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: iconName)
        .font(DesignTokens.Typography.studioTitle())
        .foregroundStyle(style.secondaryText)
      Text(title)
        .font(DesignTokens.Typography.headline())
        .foregroundStyle(style.primaryText)
      Text(message)
        .font(DesignTokens.Typography.micro())
        .foregroundStyle(style.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(14)
  }

  private var iconName: String { reason.iconName }
  private var title: String { reason.title }
  private var message: String { reason.message }
}
