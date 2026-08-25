import SwiftUI
import UIKit

/// Your News rail. Today is home; Alerts reuses the same cards.
/// Max 3 NWS AFD/PNS cards. Tap opens weather.gov in Safari.
/// Photo only when `item.imageURL` is a real source image. Load fail → text-only.
struct LocalBriefingSection: View {
  let items: [LocalBriefingItem]
  var accessibilityID: String = DayCastAccessibility.Alerts.localBriefing

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
      .accessibilityIdentifier(accessibilityID)
    }
  }
}

private struct YourNewsCard: View {
  let item: LocalBriefingItem

  var body: some View {
    Button {
      Haptic.impact(.light)
      Analytics.track(.feedCardTap, parameters: ["card": FeedItem.yourNews.analyticsName])
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

        Text(item.displayTitle)
          .font(DesignTokens.Typography.headline())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .multilineTextAlignment(.leading)
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)

        Text("\(item.relativeIssuedLabel()) · \(item.sourceName)")
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabelText)
    .accessibilityHint("Opens the National Weather Service product in Safari")
    .accessibilityAddTraits(.isButton)
  }

  private var accessibilityLabelText: String {
    let display = item.displayTitle
    let office = item.title
    let meta = "\(item.relativeIssuedLabel()) · \(item.sourceName)"
    if display == office {
      return "\(display). \(meta)"
    }
    return "\(display). \(office). \(meta)"
  }
}
