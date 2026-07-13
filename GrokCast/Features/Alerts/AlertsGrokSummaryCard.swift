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
    VStack(alignment: .leading, spacing: DesignTokens.Figma.Metrics.cardInnerSpacing) {
      if isLoading {
        HStack(spacing: 8) {
          ProgressView().scaleEffect(0.75)
          Text("Summarizing alerts…")
            .font(DesignTokens.Figma.Typography.rowSubtitle)
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
      } else if let summary {
        Text(summary)
          .font(DesignTokens.Figma.Typography.body)
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      } else if let errorMessage {
        Text(errorMessage)
          .font(DesignTokens.Figma.Typography.body)
          .foregroundStyle(DesignTokens.Palette.textSecondary)
        if store.xaiService.hasValidKey {
          Button("Try Again") { Task { await fetchSummary(force: true) } }
            .font(.caption.weight(.semibold))
        }
      } else if !store.xaiService.hasValidKey {
        Text("Add an xAI key in Settings for AI alert summaries.")
          .font(DesignTokens.Figma.Typography.body)
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      } else {
        Text(figmaReadyPrompt)
          .font(DesignTokens.Figma.Typography.body)
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .onTapGesture {
            Task { await fetchSummary(force: false) }
          }
      }
    }
    .padding(DesignTokens.Figma.Metrics.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Figma.Metrics.cardRadius
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
          .font(.caption.weight(.heavy))
          .tracking(DesignTokens.Typography.cardLabelTracking)
          .foregroundStyle(DesignTokens.Palette.warning)
        Spacer()
        if isLoading {
          ProgressView().scaleEffect(0.75)
        }
      }

      if let summary {
        Text(summary)
          .font(.body)
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
            .font(.caption.weight(.semibold))
        }
        .foregroundStyle(DesignTokens.Palette.accent)
      } else if let errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundStyle(DesignTokens.Palette.textSecondary)
        if store.xaiService.hasValidKey {
          Button("Try Again") { Task { await fetchSummary(force: true) } }
            .font(.caption.weight(.semibold))
        }
      } else if !store.xaiService.hasValidKey {
        Text("Add an xAI key in Settings for AI alert summaries.")
          .font(.caption)
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
    guard store.xaiService.hasValidKey else { return }
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
