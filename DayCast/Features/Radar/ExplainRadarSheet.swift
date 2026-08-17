import SwiftUI

struct RadarExplainContext: Equatable {
  let modeLabel: String
  let frameLabel: String
  /// Plain-language name shown to the user.
  let productName: String
  /// Meteorological name sent to Grok — the plain label is too vague to prompt with.
  let productTechnicalName: String
  let locationName: String
}

struct ExplainRadarSheet: View {
  @Environment(WeatherStore.self) private var store
  @Environment(\.dismiss) private var dismiss

  let context: RadarExplainContext

  @State private var explanation: String?
  @State private var isLoading = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
          contextCard

          if !store.canUseGrok {
            GrokAPIKeyEmptyStateView(store: store, subscription: SubscriptionManager.shared)
          } else if isLoading {
            HStack(spacing: 10) {
              ProgressView()
              Text("Reading the radar…")
                .font(DesignTokens.Typography.callout())
                .foregroundStyle(DesignTokens.Palette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
          } else if let explanation {
            Text(explanation)
              .font(DesignTokens.Typography.body())
              .foregroundStyle(DesignTokens.Palette.textPrimary)
              .fixedSize(horizontal: false, vertical: true)
          } else if let errorMessage {
            Text(errorMessage)
              .font(DesignTokens.Typography.callout())
              .foregroundStyle(DesignTokens.Palette.danger)
          }
        }
        .padding(DesignTokens.Spacing.space20)
      }
      .background {
        WeatherBackgroundView(
          conditionCode: store.currentWeather?.conditionCode,
          isDay: false,
          intensity: .subtle
        )
        .ignoresSafeArea()
      }
      .navigationTitle("Explain Radar")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
        }
        if explanation != nil {
          ToolbarItem(placement: .primaryAction) {
            ShareLink(
              item: ShareableBriefText.radarExplanation(context: context, body: explanation ?? "")
            )
            .simultaneousGesture(
              TapGesture().onEnded {
                Analytics.track(.shareStarted, parameters: ["surface": "share_radar"])
              }
            )
          }
        }
      }
      .task { await loadExplanation() }
    }
    .preferredColorScheme(.dark)
  }

  private var contextCard: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      Label("Radar Brief", systemImage: "sparkles")
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.accent)
      Text("\(context.locationName) · \(context.productName)")
        .font(DesignTokens.Typography.subsection())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
      Text("\(context.modeLabel) · \(context.frameLabel)")
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textSecondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(DesignTokens.Spacing.space16)
    .glassCardStyle()
  }

  private func loadExplanation() async {
    guard explanation == nil, !isLoading, store.canUseGrok else { return }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      explanation = try await store.grokAIViewModel.fetchRadarExplanation(context: context)
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

#if DEBUG
#Preview {
  ExplainRadarSheet(
    context: RadarExplainContext(
      modeLabel: "Live",
      frameLabel: "Now",
      productName: "Rain",
      productTechnicalName: "composite reflectivity",
      locationName: "Olive Branch"
    )
  )
  .environment(WeatherStore.shared)
}
#endif
