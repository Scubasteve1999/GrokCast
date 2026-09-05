import SwiftUI

/// Plain-English Grok summary when active NWS alerts are present.
struct AlertsGrokSummaryCard: View {
  /// Free-user CTA on the locked AI summary card (matches Sky Check empty state).
  static let unlockCTATitle = "Unlock with Pro"

  /// Whether the CTA renders at all. This surface intentionally never
  /// advertises BYOK (see `.grok/skills/daycast/SKILL.md`), so when Pro can't
  /// actually unlock Grok (proxy not configured) the CTA is hidden rather than
  /// swapped for a "use your own key" fallback — showing a Pro upsell that
  /// can't work is worse than showing none. This also keeps an already-Pro
  /// subscriber (proxy misconfigured on their build) from ever being shown a
  /// paywall for something they already own.
  static var showsUnlockButton: Bool {
    PaywallCoordinator.shared.canUnlockGrokViaPro
  }

  @Environment(WeatherStore.self) private var store

  let alerts: [NWSAlert]

  @State private var summary: String?
  @State private var isLoading = false
  @State private var errorMessage: String?

  private var cacheKey: String {
    let ids = alerts.map(\.id).sorted().joined(separator: "-")
    return "grok_alert_summary_\(ids)"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Layout.cardInnerSpacing) {
      if isLoading {
        HStack(spacing: 8) {
          ProgressView().scaleEffect(0.75)
          Text("Summarizing alerts…")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
      } else if let summary {
        Text(GrokBriefText.visible(summary))
          .font(DesignTokens.Typography.callout())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      } else if let errorMessage {
        Text(errorMessage)
          .font(DesignTokens.Typography.callout())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
        if store.canUseGrok {
          Button("Try Again") { Task { await fetchSummary(force: true) } }
            .font(DesignTokens.Typography.caption())
        }
      } else if !store.canUseGrok {
        Text(GrokAccessRules.lockedAlertsSummaryCopy)
          .font(DesignTokens.Typography.callout())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
        if Self.showsUnlockButton {
          unlockWithProButton
        }
      } else {
        Text(readyPrompt)
          .font(DesignTokens.Typography.callout())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .onTapGesture {
            Task { await fetchSummary(force: false) }
          }
      }
    }
    .padding(DesignTokens.Layout.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardHairline,
      cornerRadius: DesignTokens.Layout.cardRadius
    )
    .task(id: cacheKey) {
      if let cached = UserDefaults.standard.string(forKey: cacheKey),
        let accepted = GrokContentFilter.acceptedText(GrokBriefText.visible(cached))
      {
        summary = accepted
      }
    }
  }

  private var readyPrompt: String {
    let location = store.currentLocation?.name ?? "your area"
    let count = alerts.count
    let noun = count == 1 ? "alert" : "alerts"
    return "Tap to summarize \(count) active \(noun) for \(location)."
  }

  private var unlockWithProButton: some View {
    Button(Self.unlockCTATitle) {
      Haptic.impact(.light)
      PaywallCoordinator.shared.present(.grokAI)
    }
    .font(DesignTokens.Typography.caption())
    .buttonStyle(.borderedProminent)
    .tint(DesignTokens.Palette.accent)
    .controlSize(.small)
    .accessibilityIdentifier("alerts.unlockWithPro")
  }

  @MainActor
  private func fetchSummary(force: Bool) async {
    guard store.canUseGrok else { return }
    if !force, summary != nil { return }

    isLoading = true
    errorMessage = nil
    do {
      let text = try await store.grokAIViewModel.fetchAlertsPlainEnglishSummary(alerts: alerts)
      let visible = GrokBriefText.visible(text)
      summary = visible
      UserDefaults.standard.set(visible, forKey: cacheKey)
    } catch {
      errorMessage = error.localizedDescription
    }
    isLoading = false
  }
}
