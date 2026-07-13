import StoreKit
import SwiftUI

/// Primary upsell surface for SpotterCast Pro.
struct PaywallView: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var subscription: SubscriptionManager

  var feature: PaywallFeature

  @State private var selectedProductID: String = GrokCastProProducts.yearly

  init(feature: PaywallFeature, subscription: SubscriptionManager) {
    self.feature = feature
    self.subscription = subscription
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space24) {
          header
          featureList
          productPicker
          purchaseButtons
          legalFooter
        }
        .padding(DesignTokens.Spacing.space20)
      }
      .background(DesignTokens.Palette.bgPrimary.ignoresSafeArea())
      .navigationTitle("SpotterCast Pro")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Not now") { dismiss() }
        }
      }
      .task {
        if subscription.products.isEmpty {
          await subscription.loadProducts()
        }
        if subscription.yearlyProduct != nil {
          selectedProductID = GrokCastProProducts.yearly
        } else if let first = subscription.products.first {
          selectedProductID = first.id
        }
      }
    }
    .preferredColorScheme(.dark)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      Label(feature.headline, systemImage: feature.icon)
        .font(.title2.weight(.bold))
        .foregroundStyle(DesignTokens.Palette.textPrimary)

      Text(feature.subheadline)
        .font(.subheadline)
        .foregroundStyle(DesignTokens.Palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var featureList: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      paywallRow("AI morning briefing", "sunrise.fill", "Daily notification with personalized forecast")
      paywallRow("Forecast radar (FUTURE)", "cloud.rain.fill", "Animated precipitation outlook")
      paywallRow("Live Activity & rich widgets", "lock.rectangle.stack.fill", "Score + Minutecast on Lock Screen")
      paywallRow("Unlimited saved locations", "mappin.and.ellipse", "Track every place you care about")
    }
    .padding(DesignTokens.Spacing.space16)
    .cardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadiusMedium
    )
  }

  private func paywallRow(_ title: String, _ icon: String, _ detail: String) -> some View {
    HStack(alignment: .top, spacing: DesignTokens.Spacing.space12) {
      Image(systemName: icon)
        .foregroundStyle(DesignTokens.Palette.accent)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        Text(detail)
          .font(.caption)
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      }
    }
  }

  @ViewBuilder
  private var productPicker: some View {
    if subscription.isLoadingProducts && subscription.products.isEmpty {
      ProgressView("Loading plans…")
        .frame(maxWidth: .infinity)
    } else if subscription.products.isEmpty {
      VStack(spacing: DesignTokens.Spacing.space12) {
        Text("Subscriptions unavailable. Check your connection or try again.")
          .font(.caption)
          .foregroundStyle(DesignTokens.Palette.warning)
          .multilineTextAlignment(.center)
        Button {
          Task { await subscription.loadProducts() }
        } label: {
          Label("Retry", systemImage: "arrow.clockwise")
            .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .tint(DesignTokens.Palette.accent)
      }
    } else {
      VStack(spacing: DesignTokens.Spacing.space12) {
        ForEach(subscription.products, id: \.id) { product in
          productRow(product)
        }
      }
    }
  }

  private func productRow(_ product: Product) -> some View {
    let isSelected = selectedProductID == product.id
    return Button {
      selectedProductID = product.id
      Haptic.impact(.light)
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(friendlyDisplayName(for: product))
            .font(.headline)
            .foregroundStyle(DesignTokens.Palette.textPrimary)
          Text(product.description)
            .font(.caption)
            .foregroundStyle(DesignTokens.Palette.textSecondary)
            .multilineTextAlignment(.leading)
        }
        Spacer()
        Text(product.displayPrice)
          .font(.headline)
          .foregroundStyle(DesignTokens.Palette.accentWarm)
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(isSelected ? DesignTokens.Palette.accent : DesignTokens.Palette.textTertiary)
      }
      .padding(DesignTokens.Spacing.space16)
      .background(
        isSelected ? DesignTokens.Palette.cardElevated : DesignTokens.Palette.cardBackground,
        in: RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadiusMedium)
      )
      .overlay(
        RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadiusMedium)
          .stroke(isSelected ? DesignTokens.Palette.accent : DesignTokens.Palette.cardStroke, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }

  /// Prefer SpotterCast labels even if App Store Connect still has legacy GrokCast product names.
  private func friendlyDisplayName(for product: Product) -> String {
    switch product.id {
    case GrokCastProProducts.monthly: return "SpotterCast Pro Monthly"
    case GrokCastProProducts.yearly: return "SpotterCast Pro Yearly"
    default:
      return product.displayName.replacingOccurrences(of: "GrokCast", with: "SpotterCast")
    }
  }

  private var purchaseButtons: some View {
    VStack(spacing: DesignTokens.Spacing.space12) {
      if let product = subscription.products.first(where: { $0.id == selectedProductID }) {
        Button {
          Task {
            do {
              try await subscription.purchase(product)
              if subscription.isPro { dismiss() }
            } catch {
              subscription.reportError(error.localizedDescription)
            }
          }
        } label: {
          Group {
            if subscription.purchaseInFlight {
              ProgressView()
            } else {
              Text("Subscribe — \(product.displayPrice)")
            }
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(DesignTokens.Palette.accent)
        .disabled(subscription.purchaseInFlight)
      }

      Button("Restore Purchases") {
        Task { await subscription.restorePurchases() }
      }
      .font(.footnote)
      .disabled(subscription.purchaseInFlight)

      if let error = subscription.lastErrorMessage {
        Text(error)
          .font(.caption)
          .foregroundStyle(DesignTokens.Palette.danger)
          .multilineTextAlignment(.center)
      }
    }
  }

  private var legalFooter: some View {
    VStack(spacing: DesignTokens.Spacing.space8) {
      Text("Payment charged to your Apple ID. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period.")
        .font(.caption2)
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .multilineTextAlignment(.center)

      HStack(spacing: 16) {
        Link("Privacy Policy", destination: AppLinks.privacyPolicy)
        Link("Terms of Use (EULA)", destination: AppLinks.termsOfUse)
      }
      .font(.caption2)
      .underline()
    }
    .frame(maxWidth: .infinity)
  }
}

enum PaywallFeature {
  case grokAI
  case radarFuture
  case locations
  case liveActivity
  case morningBrief
  case severeAlerts

  var headline: String {
    switch self {
    case .grokAI: "AI weather that just works"
    case .radarFuture: "See what's coming"
    case .locations: "Track every location"
    case .liveActivity: "Weather on your Lock Screen"
    case .morningBrief: "Your personal weather briefing"
    case .severeAlerts: "Never miss a severe alert"
    }
  }

  var subheadline: String {
    switch self {
    case .grokAI:
      "SpotterCast Pro unlocks forecast radar, Live Activity, and unlimited locations. AI chat needs an xAI developer key in Settings."
    case .radarFuture:
      "Pro unlocks animated forecast radar so you can scrub ahead and plan around incoming rain."
    case .locations:
      "Save unlimited cities and switch between them from Today, Radar, and widgets."
    case .liveActivity:
      "Live Activity shows your SpotterCast Score and Minutecast without opening the app."
    case .morningBrief:
      "Wake up to a personalized AI weather brief every morning — what to wear, when to leave, and what to watch for."
    case .severeAlerts:
      "NWS warnings and watches with rich, time-sensitive notifications — free for all users. SpotterCast Pro adds AI briefings and radar tools to help you plan around severe weather."
    }
  }

  var icon: String {
    switch self {
    case .grokAI: "sparkles"
    case .radarFuture: "cloud.rain.fill"
    case .locations: "mappin.and.ellipse"
    case .liveActivity: "lock.rectangle.stack.fill"
    case .morningBrief: "sunrise.fill"
    case .severeAlerts: "exclamationmark.triangle.fill"
    }
  }
}

#Preview {
  PaywallView(feature: .grokAI, subscription: SubscriptionManager.shared)
}
