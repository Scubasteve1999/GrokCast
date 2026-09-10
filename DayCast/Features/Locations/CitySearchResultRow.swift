import SwiftUI

struct CitySearchResultRow: View {
  let result: CitySearchResult

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(result.name)
          .font(DesignTokens.Typography.headline())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        if let subtitle = result.subtitle {
          Text(subtitle)
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
            .lineLimit(2)
        }
      }
      Spacer()
      Image(systemName: "plus.circle")
        .foregroundStyle(DesignTokens.Palette.accent)
        .accessibilityHidden(true)
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Add \(result.name)")
    .accessibilityAddTraits(.isButton)
  }
}
