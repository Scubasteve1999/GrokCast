import SwiftUI
import UIKit

/// Keyword → bundled still for the Alerts **Your News** rail.
/// Match the AFD KEY MESSAGE / PNS headline; no stored field on `LocalBriefingItem`.
enum LocalBriefingHero: String, CaseIterable, Equatable, Sendable {
  case storm
  case lightning
  case sky
  case flood
  case haze
  case dawn

  var assetName: String {
    switch self {
    case .storm: return "NewsHeroStorm"
    case .lightning: return "NewsHeroLightning"
    case .sky: return "NewsHeroSky"
    case .flood: return "NewsHeroFlood"
    case .haze: return "NewsHeroHaze"
    case .dawn: return "NewsHeroDawn"
    }
  }

  /// When the preferred still is already on this rail, walk this order for the next unused crop.
  static let uniquenessOrder: [LocalBriefingHero] = [
    .storm, .lightning, .sky, .flood, .haze, .dawn,
  ]

  static func matching(title: String) -> LocalBriefingHero {
    let hay = title.lowercased()
    if hay.contains("lightning") { return .lightning }
    if containsAny(hay, ["flood", "inundat"]) { return .flood }
    if containsAny(hay, ["wildfire", "smoke", "haze", "fire weather"]) { return .haze }
    if containsAny(hay, ["storm", "severe", "hail", "tornado", "wind", "warning", "watch"]) {
      return .storm
    }
    if hay.contains("thunder") { return .lightning }
    if containsAny(hay, ["clear", "sunny", "fair", "dry", "pleasant", "high pressure"]) {
      return .dawn
    }
    return .sky
  }

  static func uniqueHeroes(for titles: [String]) -> [LocalBriefingHero] {
    var used: Set<LocalBriefingHero> = []
    return titles.map { title in
      let preferred = matching(title: title)
      if used.insert(preferred).inserted {
        return preferred
      }
      let pick = uniquenessOrder.first { !used.contains($0) } ?? preferred
      used.insert(pick)
      return pick
    }
  }

  private static func containsAny(_ haystack: String, _ needles: [String]) -> Bool {
    needles.contains { haystack.contains($0) }
  }
}

/// Alerts → Your News. Max 3 NWS AFD/PNS cards. Tap opens weather.gov in Safari.
struct LocalBriefingSection: View {
  let items: [LocalBriefingItem]

  var body: some View {
    if !items.isEmpty {
      let visible = Array(items.prefix(LocalBriefingParser.maxCards))
      let heroes = LocalBriefingHero.uniqueHeroes(for: visible.map(\.title))

      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
        Text("Your News")
          .font(DesignTokens.Typography.metric())
          .fontWeight(.bold)
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .accessibilityAddTraits(.isHeader)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: DesignTokens.Spacing.space12) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
              YourNewsCard(item: item, hero: heroes[index])
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
  let hero: LocalBriefingHero

  var body: some View {
    Button {
      Haptic.impact(.light)
      UIApplication.shared.open(item.url)
    } label: {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
        Color.clear
          .aspectRatio(16 / 9, contentMode: .fit)
          .overlay {
            Image(hero.assetName)
              .resizable()
              .scaledToFill()
          }
          .clipped()
          .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

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
