import SwiftUI
import UIKit

/// Alerts → Your News. Max 3 NWS AFD/PNS cards. Tap opens weather.gov in Safari.
/// Photo only when `item.imageURL` is a real source image. Load fail → text-only.
struct LocalBriefingSection: View {
  let items: [LocalBriefingItem]

  var body: some View {
    if !items.isEmpty {
      let visible = Array(items.prefix(LocalBriefingParser.maxCards))

      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
        Text("Your News")
          .font(DesignTokens.Typography.metric())
          .fontWeight(.bold)
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .accessibilityAddTraits(.isHeader)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(alignment: .top, spacing: DesignTokens.Spacing.space12) {
            ForEach(visible) { item in
              YourNewsCard(item: item)
                .containerRelativeFrame(.horizontal) { len, _ in min(280, len * 0.72) }
            }
          }
          .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .padding(.horizontal, -DesignTokens.Layout.horizontalPadding)
        .padding(.leading, DesignTokens.Layout.horizontalPadding)
      }
      .accessibilityIdentifier(DayCastAccessibility.Alerts.localBriefing)
    }
  }
}

private struct YourNewsCard: View {
  let item: LocalBriefingItem

  var body: some View {
    Button {
      Haptic.impact(.light)
      UIApplication.shared.open(item.url)
    } label: {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
        if let imageURL = item.imageURL {
          AsyncImage(url: imageURL) { phase in
            switch phase {
            case .success(let image):
              Color.clear
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                  image
                    .resizable()
                    .scaledToFill()
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            default:
              EmptyView()
            }
          }
        }

        Text(item.title)
          .font(DesignTokens.Typography.headline())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .multilineTextAlignment(.leading)
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: DesignTokens.Spacing.space4) {
          Image(systemName: "newspaper")
            .font(DesignTokens.Typography.caption())
            .accessibilityHidden(true)
          Text("\(item.relativeIssuedLabel()) · \(item.sourceName)")
            .font(DesignTokens.Typography.caption())
            .lineLimit(1)
        }
        .foregroundStyle(DesignTokens.Palette.textTertiary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityHint("Opens the National Weather Service product in Safari")
  }
}
