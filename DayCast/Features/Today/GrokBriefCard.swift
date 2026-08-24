import SwiftUI

/// One-line (expandable) Grok insight on the Today tab — daily habit + screenshot moment.
enum GrokBriefPresentation {
  case full
  /// Figma Today screen: card chrome + body only (actions on tap-through to Grok tab).
  case figma
}

struct GrokBriefCard: View {
  static let optionsAccessibilityLabel = "Today's Take options"

  @Environment(WeatherStore.self) private var store
  @Environment(GrokBriefSafety.self) private var safety
  var presentation: GrokBriefPresentation = .full

  @State private var briefText: String?
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var isExpanded = false
  @State private var showingReport = false
  @State private var showingReportThanks = false
  @State private var showingOptions = false
  @State private var hiddenThisBrief = false

  private var cacheKey: String {
    GrokBriefCache.key(for: store) ?? "grok_brief_none"
  }

  /// Re-run load/fetch only when cache validity would change (same rules as GrokBriefCache).
  private var weatherTaskID: String {
    "\(cacheKey)_\(GrokBriefCache.refreshToken(for: store))_\(safety.isFeatureHidden)"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      header

      if safety.isFeatureHidden {
        hiddenFeatureBody
      } else if hiddenThisBrief {
        hiddenBriefBody
      } else if let briefText {
        Text(GrokBriefText.visible(briefText))
          .font(DesignTokens.Typography.headline())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .lineLimit(isExpanded ? nil : (presentation == .figma ? 6 : 3))
          .fixedSize(horizontal: false, vertical: true)
          .animation(.easeInOut(duration: 0.2), value: isExpanded)

        if presentation == .full {
          actionRow(for: briefText)
        }
      } else if let errorMessage {
        Text(errorMessage)
          .font(DesignTokens.Typography.callout())
          .foregroundStyle(DesignTokens.Palette.textSecondary)

        if !store.canUseGrok {
          Button(
            PaywallCoordinator.shared.canUnlockGrokViaPro
              ? "Upgrade to DayCast Pro" : "Add Key in Settings"
          ) {
            if PaywallCoordinator.shared.canUnlockGrokViaPro {
              PaywallCoordinator.shared.present(.grokAI)
            } else {
              store.selectedTab = .settings
            }
          }
          .font(DesignTokens.Typography.caption())
          .buttonStyle(.borderedProminent)
          .tint(DesignTokens.Palette.accent)
          .controlSize(.small)
        } else {
          Button("Try Again") {
            Task { await fetchBrief(force: true) }
          }
          .font(DesignTokens.Typography.caption())
          .buttonStyle(.bordered)
          .controlSize(.small)
        }
      } else {
        Text("A quick, practical read on today's weather — outfit tips, outdoor windows, and anything worth watching.")
          .font(DesignTokens.Typography.callout())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .fixedSize(horizontal: false, vertical: true)

        if presentation == .full {
          Button {
            Task { await fetchBrief(force: false) }
          } label: {
            Label("Get Today's Take", systemImage: "sparkles")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .tint(DesignTokens.Palette.accent)
          .disabled(!store.canUseGrok || isLoading)
        }
      }
    }
    .padding(DesignTokens.Spacing.space16)
    .modifier(GrokBriefCardChrome(presentation: presentation))
    .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadius))
    .onTapGesture {
      guard presentation == .figma, !safety.isFeatureHidden else { return }
      SkyCheckLanding.openReadyToType(on: store)
    }
    .sheet(isPresented: $showingReport) {
      if let briefText {
        GrokBriefReportSheet(
          brief: briefText,
          locationName: store.currentLocation?.name ?? "My location"
        ) {
          showingReportThanks = true
        }
      }
    }
    .alert("Report sent", isPresented: $showingReportThanks) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(GrokBriefReport.responsePromise)
    }
    .task(id: weatherTaskID) {
      hiddenThisBrief = false
      guard !safety.isFeatureHidden else {
        briefText = nil
        return
      }
      briefText = acceptedCachedBrief()
      if briefText == nil, store.canUseGrok, !isLoading {
        await fetchBrief(force: false)
      }
    }
  }

  private var header: some View {
    HStack {
      Label("TODAY'S TAKE", systemImage: "sparkles")
        .font(DesignTokens.Typography.caption())
        .tracking(DesignTokens.Typography.cardLabelTracking)
        .foregroundStyle(DesignTokens.Palette.accent)
      Spacer()
      if isLoading {
        ProgressView()
          .scaleEffect(0.75)
          .tint(DesignTokens.Palette.accent)
      }
      if !safety.isFeatureHidden {
        safetyMenu
      }
    }
  }

  private var safetyMenu: some View {
    Button {
      showingOptions = true
    } label: {
      Label(Self.optionsAccessibilityLabel, systemImage: "ellipsis.circle")
        .labelStyle(.iconOnly)
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .frame(minWidth: 32, minHeight: 32)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Self.optionsAccessibilityLabel)
    .accessibilityIdentifier(DayCastAccessibility.Today.takeOptions)
    .confirmationDialog(
      Self.optionsAccessibilityLabel,
      isPresented: $showingOptions,
      titleVisibility: .visible
    ) {
      if let briefText {
        Button("Report…") { showingReport = true }
        Button("Hide this take") { hideThisBrief(briefText) }
      }
      Button("Turn off Today's Take") { turnOffFeature() }
      Button("Cancel", role: .cancel) {}
    }
  }

  private var hiddenBriefBody: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      Text("This take was hidden.")
        .font(DesignTokens.Typography.callout())
        .foregroundStyle(DesignTokens.Palette.textSecondary)
      Button("Get another take") {
        hiddenThisBrief = false
        Task { await fetchBrief(force: true) }
      }
      .font(DesignTokens.Typography.caption())
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
  }

  private var hiddenFeatureBody: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      Text("Today's Take is off. You can turn it back on anytime.")
        .font(DesignTokens.Typography.callout())
        .foregroundStyle(DesignTokens.Palette.textSecondary)
      Button("Turn back on") {
        safety.isFeatureHidden = false
        store.refreshGrokBriefSurfaces()
        Task { await fetchBrief(force: false) }
      }
      .font(DesignTokens.Typography.caption())
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
  }

  @ViewBuilder
  private func actionRow(for briefText: String) -> some View {
    HStack(spacing: DesignTokens.Spacing.space16) {
      if briefText.count > 120 {
        Button(isExpanded ? "Show less" : "Show more") {
          withAnimation { isExpanded.toggle() }
        }
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.accent)
      }

      Button("Refresh") {
        Task { await fetchBrief(force: true) }
      }
      .font(DesignTokens.Typography.caption())
      .foregroundStyle(DesignTokens.Palette.textTertiary)

      Spacer()

      ShareLink(
        item: shareText(for: briefText),
        subject: Text("DayCast Weather Brief"),
        message: Text(shareText(for: briefText))
      ) {
        Image(systemName: "square.and.arrow.up")
          .font(DesignTokens.Typography.caption())
      }
      .foregroundStyle(DesignTokens.Palette.accent)

      Button {
        SkyCheckLanding.openReadyToType(on: store)
      } label: {
        Text(SkyCheckDeskCopy.landingActionTitle)
          .font(DesignTokens.Typography.caption())
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .tint(DesignTokens.Palette.accent)
    }
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

  private func acceptedCachedBrief() -> String? {
    guard let text = GrokBriefCache.loadValidBrief(for: store) else { return nil }
    guard GrokContentFilter.acceptedText(text) != nil else {
      GrokBriefCache.clear(for: store)
      return nil
    }
    if safety.isBriefHidden(text) {
      hiddenThisBrief = true
      return nil
    }
    return text
  }

  private func hideThisBrief(_ text: String) {
    Haptic.impact(.light)
    safety.hideBrief(text)
    GrokBriefCache.clear(for: store)
    briefText = nil
    hiddenThisBrief = true
    store.refreshGrokBriefSurfaces()
  }

  private func turnOffFeature() {
    Haptic.impact(.light)
    safety.isFeatureHidden = true
    briefText = nil
    hiddenThisBrief = false
    store.refreshGrokBriefSurfaces()
  }

  @MainActor
  private func fetchBrief(force: Bool) async {
    guard !safety.isFeatureHidden else { return }
    guard store.canUseGrok else {
      errorMessage = "Add your xAI developer key in Settings to unlock Today's Take."
      return
    }
    if !force, briefText != nil { return }

    isLoading = true
    errorMessage = nil

    do {
      let response = try await store.grokAIViewModel.fetchWeatherBrief()
      if safety.isBriefHidden(response) {
        hiddenThisBrief = true
        briefText = nil
      } else {
        GrokBriefCache.save(response, for: store)
        briefText = response
        hiddenThisBrief = false
        store.refreshWidgetSnapshotGrokBrief()
        Task { await store.syncMorningBriefNotification(briefBody: response) }
      }
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
      content.cardStyle()
    }
  }
}

#Preview("Figma") {
  GrokBriefCard(presentation: .figma)
    .environment(WeatherStore())
    .environment(GrokBriefSafety())
    .padding()
    .preferredColorScheme(.dark)
}

#Preview {
  GrokBriefCard()
    .environment(WeatherStore())
    .environment(GrokBriefSafety())
    .padding()
    .preferredColorScheme(.dark)
}
