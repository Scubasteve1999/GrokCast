import SwiftUI

/// One-line (expandable) Grok insight on the Today tab — daily habit + screenshot moment.
struct GrokBriefCard: View {
  @Environment(WeatherStore.self) private var store

  @State private var briefText: String?
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var isExpanded = false

  private var cacheKey: String {
    let loc = store.currentLocation?.id.uuidString ?? "none"
    let day = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
    return "grok_brief_\(loc)_\(Int(day))"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      HStack {
        Label("GROK'S TAKE", systemImage: "sparkles")
          .font(.caption.weight(.heavy))
          .tracking(DesignTokens.Typography.cardLabelTracking)
          .foregroundStyle(DesignTokens.Palette.accent)
        Spacer()
        if isLoading {
          ProgressView()
            .scaleEffect(0.75)
            .tint(DesignTokens.Palette.accent)
        }
      }

      if let briefText {
        Text(briefText)
          .font(.body.weight(.medium))
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .lineLimit(isExpanded ? nil : 3)
          .fixedSize(horizontal: false, vertical: true)
          .animation(.easeInOut(duration: 0.2), value: isExpanded)

        HStack(spacing: DesignTokens.Spacing.space16) {
          if briefText.count > 120 {
            Button(isExpanded ? "Show less" : "Show more") {
              withAnimation { isExpanded.toggle() }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(DesignTokens.Palette.accent)
          }

          Button("Refresh") {
            Task { await fetchBrief(force: true) }
          }
          .font(.caption.weight(.semibold))
          .foregroundStyle(DesignTokens.Palette.textTertiary)

          Spacer()

          ShareLink(
            item: shareText(for: briefText),
            subject: Text("GrokCast Weather Brief"),
            message: Text(shareText(for: briefText))
          ) {
            Image(systemName: "square.and.arrow.up")
              .font(.caption.weight(.semibold))
          }
          .foregroundStyle(DesignTokens.Palette.accent)

          Button {
            store.selectedTab = .grok
          } label: {
            Text("Ask Grok")
              .font(.caption.weight(.semibold))
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
          .tint(DesignTokens.Palette.accent)
        }
      } else if let errorMessage {
        Text(errorMessage)
          .font(.subheadline)
          .foregroundStyle(DesignTokens.Palette.textSecondary)

        if !store.xaiService.hasValidKey {
          Button("Upgrade to GrokCast Pro") {
            PaywallCoordinator.shared.present(.grokAI)
          }
          .font(.caption.weight(.semibold))
          .buttonStyle(.borderedProminent)
          .tint(DesignTokens.Palette.accent)
          .controlSize(.small)
        } else {
          Button("Try Again") {
            Task { await fetchBrief(force: true) }
          }
          .font(.caption.weight(.semibold))
          .buttonStyle(.bordered)
          .controlSize(.small)
        }
      } else {
        Text("A quick, practical read on today's weather — outfit tips, outdoor windows, and anything worth watching.")
          .font(.subheadline)
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .fixedSize(horizontal: false, vertical: true)

        Button {
          Task { await fetchBrief(force: false) }
        } label: {
          Label("Get Grok's Take", systemImage: "sparkles")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(DesignTokens.Palette.accent)
        .disabled(!store.xaiService.hasValidKey || isLoading)
      }
    }
    .padding(DesignTokens.Spacing.space20)
    .glassCardStyle(strokeTint: DesignTokens.Palette.accent.opacity(0.35))
    .task(id: cacheKey) {
      loadCachedBrief()
      if briefText == nil, store.xaiService.hasValidKey, !isLoading {
        await fetchBrief(force: false)
      }
    }
  }

  private func loadCachedBrief() {
    briefText = UserDefaults.standard.string(forKey: cacheKey)
  }

  private func saveCachedBrief(_ text: String) {
    UserDefaults.standard.set(text, forKey: cacheKey)
    briefText = text
    store.refreshWidgetSnapshotGrokBrief()
    Task { await store.syncMorningBriefNotification(briefBody: text) }
  }

  private func shareText(for brief: String) -> String {
    let loc = store.currentLocation?.name ?? "My location"
    let tempLine = store.currentWeather.map { store.formatTemperature($0.currentTemp) }
    let condition = store.currentWeather?.conditionText
    return ShareableBriefText.weatherBrief(
      locationName: loc,
      temperatureLine: tempLine,
      condition: condition,
      brief: brief
    )
  }

  @MainActor
  private func fetchBrief(force: Bool) async {
    guard store.xaiService.hasValidKey else {
      errorMessage = "Add your xAI developer key in Settings to unlock Grok's take."
      return
    }
    if !force, briefText != nil { return }

    isLoading = true
    errorMessage = nil

    do {
      let response = try await store.grokAIViewModel.fetchWeatherBrief()
      saveCachedBrief(response)
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }
}

#Preview {
  GrokBriefCard()
    .environment(WeatherStore())
    .padding()
    .preferredColorScheme(.dark)
}
