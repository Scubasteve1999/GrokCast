import SwiftUI

enum AlertsGrokSummaryPresentation {
  case standard
  /// Figma Alerts screen: single secondary line in a simple card.
  case figma
}

/// Plain-English Grok summary when active NWS alerts are present.
struct AlertsGrokSummaryCard: View {
  @Environment(WeatherStore.self) private var store

  let alerts: [NWSAlert]
  var presentation: AlertsGrokSummaryPresentation = .standard

  @State private var summary: String?
  @State private var isLoading = false
  @State private var errorMessage: String?

  private var cacheKey: String {
    let ids = alerts.map(\.id).sorted().joined(separator: "-")
    return "grok_alert_summary_\(ids)"
  }

  var body: some View {
    Group {
      switch presentation {
      case .standard:
        standardBody
      case .figma:
        figmaBody
      }
    }
    .task(id: cacheKey) {
      summary = UserDefaults.standard.string(forKey: cacheKey)
    }
  }

  @ViewBuilder
  private var figmaBody: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Layout.cardInnerSpacing) {
      if isLoading {
        HStack(spacing: 8) {
          ProgressView().scaleEffect(0.75)
          Text("Summarizing alerts…")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
      } else if let summary {
        Text(summary)
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
        Text("Add an xAI key in Settings for AI alert summaries.")
          .font(DesignTokens.Typography.callout())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      } else {
        Text(figmaReadyPrompt)
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
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Layout.cardRadius
    )
  }

  private var figmaReadyPrompt: String {
    let location = store.currentLocation?.name ?? "your area"
    let count = alerts.count
    let noun = count == 1 ? "alert" : "alerts"
    return "Tap to summarize \(count) active \(noun) for \(location)."
  }

  private var standardBody: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      HStack {
        Label("IN PLAIN ENGLISH", systemImage: "text.bubble")
          .font(DesignTokens.Typography.caption())
          .tracking(DesignTokens.Typography.cardLabelTracking)
          .foregroundStyle(DesignTokens.Palette.warning)
        Spacer()
        if isLoading {
          ProgressView().scaleEffect(0.75)
        }
      }

      if let summary {
        Text(summary)
          .font(DesignTokens.Typography.body())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .fixedSize(horizontal: false, vertical: true)

        ShareLink(
          item: ShareableBriefText.alertsSummary(
            locationName: store.currentLocation?.name ?? "Your area",
            summary: summary,
            alertEvents: alerts.map(\.event)
          )
        ) {
          Label("Share Summary", systemImage: "square.and.arrow.up")
            .font(DesignTokens.Typography.caption())
        }
        .foregroundStyle(DesignTokens.Palette.accent)
        // ShareLink reports no completion, so intent is all this surface can
        // measure. The campaign token in the shared link covers the rest.
        .simultaneousGesture(
          TapGesture().onEnded {
            Analytics.track(.shareStarted, parameters: ["surface": "share_alerts"])
          }
        )
      } else if let errorMessage {
        Text(errorMessage)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
        if store.canUseGrok {
          Button("Try Again") { Task { await fetchSummary(force: true) } }
            .font(DesignTokens.Typography.caption())
        }
      } else if !store.canUseGrok {
        Text("Add an xAI key in Settings for AI alert summaries.")
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      } else {
        Button {
          Task { await fetchSummary(force: false) }
        } label: {
          Label("Summarize active alerts", systemImage: "sparkles")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(DesignTokens.Palette.warning)
        .disabled(isLoading)
      }
    }
    .padding(DesignTokens.Spacing.space16)
    .glassCardStyle(strokeTint: DesignTokens.Palette.warning.opacity(0.4))
  }

  @MainActor
  private func fetchSummary(force: Bool) async {
    guard store.canUseGrok else { return }
    if !force, summary != nil { return }

    isLoading = true
    errorMessage = nil
    do {
      let text = try await store.grokAIViewModel.fetchAlertsPlainEnglishSummary(alerts: alerts)
      summary = text
      UserDefaults.standard.set(text, forKey: cacheKey)
    } catch {
      errorMessage = error.localizedDescription
    }
    isLoading = false
  }
}
