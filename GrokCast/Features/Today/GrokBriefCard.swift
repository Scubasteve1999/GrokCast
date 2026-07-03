import SwiftUI

/// One-line (expandable) Grok insight on the Today tab — daily habit + screenshot moment.
enum GrokBriefPresentation {
  case full
  /// Figma Today screen: card chrome + body only (actions on tap-through to Grok tab).
  case figma
}

struct GrokBriefCard: View {
  @Environment(WeatherStore.self) private var store
  var presentation: GrokBriefPresentation = .full

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
    VStack(alignment: .leading, spacing: DesignTokens.Figma.Metrics.cardInnerSpacing) {
      if presentation == .figma {
        figmaHeader
      } else {
        fullHeader
      }

      if let briefText {
        Text(briefText)
          .font(presentation == .figma ? DesignTokens.Figma.Typography.body : .body.weight(.medium))
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .lineLimit(isExpanded ? nil : (presentation == .figma ? 6 : 3))
          .fixedSize(horizontal: false, vertical: true)
          .animation(.easeInOut(duration: 0.2), value: isExpanded)

        if presentation == .full {
          actionRow(for: briefText)
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

        if presentation == .full {
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
    }
    .padding(DesignTokens.Figma.Metrics.cardPadding)
    .modifier(GrokBriefCardChrome(presentation: presentation))
    .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadius))
    .onTapGesture {
      guard presentation == .figma else { return }
      store.selectedTab = .grok
    }
    .task(id: cacheKey) {
      loadCachedBrief()
      if briefText == nil, store.xaiService.hasValidKey, !isLoading {
        await fetchBrief(force: false)
      }
    }
  }

  private var figmaHeader: some View {
    HStack(spacing: 6) {
      Image(systemName: "sparkles")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(DesignTokens.Palette.accent)
      Text("GROK'S TAKE")
        .font(DesignTokens.Figma.Typography.sectionLabel)
        .foregroundStyle(DesignTokens.Palette.accent)
      Spacer()
      if isLoading {
        ProgressView()
          .scaleEffect(0.75)
          .tint(DesignTokens.Palette.accent)
      }
    }
  }

  private var fullHeader: some View {
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
  }

  @ViewBuilder
  private func actionRow(for briefText: String) -> some View {
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

private struct GrokBriefCardChrome: ViewModifier {
  let presentation: GrokBriefPresentation

  func body(content: Content) -> some View {
    switch presentation {
    case .full:
      content.glassCardStyle(strokeTint: DesignTokens.Palette.accent.opacity(0.35))
    case .figma:
      content.cardStyle(cornerRadius: DesignTokens.Figma.Metrics.cardRadius)
    }
  }
}

#Preview("Figma") {
  GrokBriefCard(presentation: .figma)
    .environment(WeatherStore())
    .padding()
    .preferredColorScheme(.dark)
}

#Preview {
  GrokBriefCard()
    .environment(WeatherStore())
    .padding()
    .preferredColorScheme(.dark)
}
