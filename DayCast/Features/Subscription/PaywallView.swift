import StoreKit
import SwiftUI

/// Primary upsell surface for DayCast Pro.
struct PaywallView: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var subscription: SubscriptionManager

  var feature: PaywallFeature

  @State private var selectedProductID: String = DayCastProProducts.yearly

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
      .navigationTitle("DayCast Pro")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Not now") { dismiss() }
        }
      }
      .onAppear {
        Analytics.track(.paywallView, parameters: ["feature": feature.analyticsName])
      }
      .task {
        if subscription.products.isEmpty {
          await subscription.loadProducts()
        }
        if subscription.yearlyProduct != nil {
          selectedProductID = DayCastProProducts.yearly
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
        .font(DesignTokens.Typography.studioTitle())
        .foregroundStyle(DesignTokens.Palette.textPrimary)

      Text(feature.subheadline)
        .font(DesignTokens.Typography.callout())
        .foregroundStyle(DesignTokens.Palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var featureList: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      paywallRow(
        "AI weather intelligence",
        "sparkles",
        "Chat, Today's Take, Explain Radar, morning brief, and Storm Spotter photo analysis"
      )
      paywallRow(
        "Forecast radar (FUTURE)",
        "cloud.rain.fill",
        "Animated precipitation outlook you can scrub ahead"
      )
      paywallRow(
        "Live Activity",
        "lock.rectangle.stack.fill",
        "Score + Minutecast on Lock Screen when DayCast refreshes weather"
      )
      paywallRow(
        "Home Screen widgets",
        "rectangle.3.group.fill",
        "Score, Minutecast, and the AI one-liner on widgets"
      )
      paywallRow(
        "Unlimited saved locations",
        "mappin.and.ellipse",
        "Track every place you care about"
      )

      Text(
        "AI features have a generous daily limit that resets at midnight UTC. Weather, radar, and NWS alerts stay free for everyone."
      )
      .font(DesignTokens.Typography.micro())
      .foregroundStyle(DesignTokens.Palette.textTertiary)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.top, DesignTokens.Spacing.space4)
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
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
        Text(title)
          .font(DesignTokens.Typography.subsection())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        Text(detail)
          .font(DesignTokens.Typography.caption())
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
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.warning)
          .multilineTextAlignment(.center)
        Button {
          Task { await subscription.loadProducts() }
        } label: {
          Label("Retry", systemImage: "arrow.clockwise")
            .font(DesignTokens.Typography.subsection())
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
          Text(product.displayName)
            .font(DesignTokens.Typography.headline())
            .foregroundStyle(DesignTokens.Palette.textPrimary)
          Text(product.description)
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
            .multilineTextAlignment(.leading)
        }
        Spacer()
        Text(product.displayPrice)
          .font(DesignTokens.Typography.headline())
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

  private var purchaseButtons: some View {
    VStack(spacing: DesignTokens.Spacing.space12) {
      if let product = subscription.products.first(where: { $0.id == selectedProductID }) {
        Button {
          Task {
            do {
              Analytics.track(.subscribeTap, parameters: ["product_id": product.id])
              try await subscription.purchase(product)
              if subscription.isPro {
                Analytics.track(.subscribeSuccess, parameters: ["product_id": product.id])
                dismiss()
              }
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
        Task {
          await subscription.restorePurchases()
          if subscription.isPro {
            Analytics.track(.restoreSuccess)
          }
        }
      }
      .font(DesignTokens.Typography.caption())
      .disabled(subscription.purchaseInFlight)

      if let error = subscription.lastErrorMessage {
        Text(error)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.danger)
          .multilineTextAlignment(.center)
      }
    }
  }

  private var legalFooter: some View {
    VStack(spacing: DesignTokens.Spacing.space8) {
      Text("Payment charged to your Apple ID. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period.")
        .font(DesignTokens.Typography.micro())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .multilineTextAlignment(.center)

      HStack(spacing: DesignTokens.Spacing.space16) {
        Link("Privacy Policy", destination: AppLinks.privacyPolicy)
        Link("Terms of Use (EULA)", destination: AppLinks.termsOfUse)
      }
      .font(DesignTokens.Typography.micro())
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
    case .grokAI: "Tools for storm spotters"
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
      "AI chat needs an xAI developer key in Settings. DayCast Pro unlocks forecast radar, Live Activity, and unlimited locations — not hosted AI (yet)."
    case .radarFuture:
      "Pro unlocks animated forecast radar so you can scrub ahead and plan around incoming rain."
    case .locations:
      "Save unlimited cities and switch between them from Today, Radar, and widgets."
    case .liveActivity:
      "Pro shows DayCast Score and Minutecast on the Lock Screen. It updates when the app refreshes weather — not a continuous background push feed yet."
    case .morningBrief:
      "Schedule a local morning notification from your cached Today's Take. Generating that take needs an xAI key in Settings."
    case .severeAlerts:
      "NWS warnings and watches with notifications are free for all users. Pro adds forecast radar, Lock Screen weather, and unlimited locations."
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

  var analyticsName: String {
    switch self {
    case .grokAI: "grok_ai"
    case .radarFuture: "radar_future"
    case .locations: "locations"
    case .liveActivity: "live_activity"
    case .morningBrief: "morning_brief"
    case .severeAlerts: "severe_alerts"
    }
  }
}

#Preview {
  PaywallView(feature: .grokAI, subscription: SubscriptionManager.shared)
}
