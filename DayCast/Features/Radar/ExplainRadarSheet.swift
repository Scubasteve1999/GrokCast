import SwiftUI

struct RadarExplainContext: Equatable {
  let modeLabel: String
  let frameLabel: String
  /// Plain-language name shown to the user.
  let productName: String
  /// Meteorological name sent to Grok — the plain label is too vague to prompt with.
  let productTechnicalName: String
  let locationName: String
  /// Selected pin identity so a city switch does not reuse another city's brief.
  let locationID: UUID?
  /// Selected city's current condition (from `displayedWeather`).
  let conditionText: String?
  /// Selected city's current precip chance (from `displayedWeather`).
  let precipitationChance: Int?

  var taskID: String {
    [
      locationID?.uuidString ?? locationName,
      productTechnicalName,
      modeLabel,
      frameLabel,
      conditionText ?? "",
      precipitationChance.map(String.init) ?? "",
    ].joined(separator: "|")
  }
}

/// Deterministic radar copy keyed to the selected city's forecast.
enum RadarExplainCopy {
  /// No precip at the pin, or no forecast yet — do not ask a model to invent echoes.
  static func shouldUseLocalExplanation(_ context: RadarExplainContext) -> Bool {
    guard let chance = context.precipitationChance else { return true }
    return chance == 0
  }

  static func localExplanation(for context: RadarExplainContext) -> String {
    let place = context.locationName
    let product =
      "This view is \(context.productTechnicalName) (labeled \"\(context.productName)\")."
    if let condition = context.conditionText, let chance = context.precipitationChance {
      let forecast =
        "\(place) is currently \(condition), with a \(chance)% chance of precipitation at the selected pin."
      if chance == 0 {
        return
          "\(forecast) \(product) That layer lights up liquid when it is present. There is no precipitation in the forecast for this pin, so color on the map is not rain here — it is returns away from the city or clear-air clutter."
      }
      return
        "\(forecast) \(product) \(context.modeLabel) · \(context.frameLabel)."
    }
    return
      "No current forecast is loaded for \(place). \(product) Until the selected city's forecast arrives, DayCast will not guess precipitation at this pin."
  }

  static func systemPrompt(for context: RadarExplainContext) -> String {
    var prompt = """
      You are a helpful weather assistant explaining weather radar to a non-meteorologist inside DayCast.
      Location: \(context.locationName). Product: \(context.productTechnicalName) (shown as "\(context.productName)"). Mode: \(context.modeLabel). Frame: \(context.frameLabel).
      """
    if let condition = context.conditionText, let chance = context.precipitationChance {
      prompt += """

        Selected city forecast (source of truth for this pin): \(condition), \(chance)% chance of precipitation.
        Do not invent precipitation at this pin. If the chance is 0, say there is no precipitation forecast here. The product label "\(context.productName)" is the radar layer name, not a statement that it is raining.
        """
    }
    prompt += """

      In 3–5 short sentences, describe what this view means for the selected city. No markdown. If uncertain, say so plainly.
      """
    return prompt
  }

  static func inventsPrecipitationAtPin(_ text: String, context: RadarExplainContext) -> Bool {
    guard context.precipitationChance == 0 else { return false }
    let lower = text.lowercased()
    let claims = [
      "raining", "it's raining", "it is raining", "showers", "downpour",
      "storm moving", "rain is falling", "rain over \(context.locationName.lowercased())",
      "precipitation is falling",
    ]
    return claims.contains { lower.contains($0) }
  }
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
          conditionCode: store.displayedWeather?.conditionCode,
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
      .task(id: context.taskID) { await loadExplanation() }
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
    guard !isLoading, store.canUseGrok else { return }
    isLoading = true
    errorMessage = nil
    explanation = nil
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
      locationName: "Olive Branch",
      locationID: nil,
      conditionText: "Clear",
      precipitationChance: 0
    )
  )
  .environment(WeatherStore.shared)
}
#endif
