import SwiftUI

// MARK: - Figma screen chrome (DayCast Screens page)

struct FigmaScreenTitle: View {
  enum Style {
    case screen
    case studio
  }

  let title: String
  var style: Style = .screen

  var body: some View {
    Text(title)
      .font(style == .screen ? DesignTokens.Typography.title() : DesignTokens.Typography.studioTitle())
      .foregroundStyle(DesignTokens.Palette.textPrimary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct FigmaSectionLabel: View {
  let title: String

  var body: some View {
    Text(title)
      .font(DesignTokens.Typography.caption())
      .foregroundStyle(DesignTokens.Palette.textSecondary)
      // Calm weather UI: sentence case, no shouting caps / tracking.
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct FigmaSubsectionLabel: View {
  let title: String

  var body: some View {
    Text(title)
      .font(DesignTokens.Typography.subsection())
      .foregroundStyle(DesignTokens.Palette.textSecondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct FigmaAccentSectionLabel: View {
  let title: String
  let icon: String
  let color: Color

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(DesignTokens.Typography.symbol())
      Text(title)
        .font(DesignTokens.Typography.subsection())
    }
    .foregroundStyle(color)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

extension View {
  /// Standard Figma screen content padding (20pt sides, tab-bar bottom clearance).
  func figmaScreenPadding(top: CGFloat = DesignTokens.Layout.topPadding) -> some View {
    padding(.horizontal, DesignTokens.Layout.horizontalPadding)
      .padding(.top, top)
      .padding(.bottom, DesignTokens.Layout.bottomPadding)
  }
}

// MARK: - Section chrome (Settings, More hub, long forms)

struct SettingsSectionHeader: View {
  let title: String
  var footer: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      FigmaSectionLabel(title: title)

      if let footer {
        Text(footer)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct SettingsGroupCard<Content: View>: View {
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      content()
    }
    .cardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Layout.cardRadius
    )
  }
}

struct SettingsToggleRow: View {
  let title: String
  @Binding var isOn: Bool

  var body: some View {
    Toggle(isOn: $isOn) {
      Text(title)
        .font(DesignTokens.Typography.body())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
    }
    .tint(DesignTokens.Palette.accent)
    .padding(.horizontal, DesignTokens.Spacing.space16)
    .padding(.vertical, DesignTokens.Spacing.space12)
  }
}

struct SettingsLinkRow: View {
  let title: String
  let icon: String
  let url: URL

  var body: some View {
    Link(destination: url) {
      HStack(spacing: DesignTokens.Spacing.space12) {
        Image(systemName: icon)
          .font(DesignTokens.Typography.body())
          .foregroundStyle(DesignTokens.Palette.accent)
          .frame(width: 24)
        Text(title)
          .font(DesignTokens.Typography.body())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        Spacer()
        Image(systemName: "arrow.up.right")
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }
      .padding(.horizontal, DesignTokens.Spacing.space16)
      .padding(.vertical, DesignTokens.Spacing.space12)
      .contentShape(Rectangle())
    }
  }
}

struct SettingsNavigationRow: View {
  let title: String
  let subtitle: String?
  let icon: String
  var tint: Color = DesignTokens.Palette.accent
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: DesignTokens.Spacing.space12) {
        Image(systemName: icon)
          .font(DesignTokens.Typography.symbol(16))
          .foregroundStyle(tint)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
          Text(title)
            .font(DesignTokens.Typography.body())
            .foregroundStyle(DesignTokens.Palette.textPrimary)
          if let subtitle {
            Text(subtitle)
              .font(DesignTokens.Typography.caption())
              .foregroundStyle(DesignTokens.Palette.textSecondary)
          }
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }
      .padding(.horizontal, DesignTokens.Spacing.space16)
      .padding(.vertical, DesignTokens.Spacing.space12)
      // Without this the Spacer between the title and the chevron is dead to
      // taps, so only the text and icons themselves are hittable.
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

struct SettingsDivider: View {
  var body: some View {
    Divider()
      .overlay(DesignTokens.Palette.cardStroke)
      .padding(.leading, 52)
  }
}

// MARK: - More hub

struct MoreHubSheet: View {
  @Environment(WeatherStore.self) private var store
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
          hubHeader

          SettingsGroupCard {
            ForEach(Array(WeatherStore.Tab.moreHub.enumerated()), id: \.element.id) { index, tab in
              if index > 0 { SettingsDivider() }
              SettingsNavigationRow(
                title: moreTitle(for: tab),
                subtitle: moreSubtitle(for: tab),
                icon: tab.icon,
                tint: moreTint(for: tab)
              ) {
                Haptic.selection()
                store.selectedTab = tab
                dismiss()
              }
              .accessibilityIdentifier(DayCastAccessibility.MoreHub.row(tab))
            }
          }
        }
        .padding(.horizontal, DesignTokens.Spacing.space20)
        .padding(.vertical, DesignTokens.Spacing.space24)
      }
      .background(DesignTokens.Palette.bgPrimary.ignoresSafeArea())
      .navigationTitle("More")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .preferredColorScheme(.dark)
    .presentationDragIndicator(.visible)
    .presentationContentInteraction(.scrolls)
    .accessibilityIdentifier(DayCastAccessibility.MoreHub.root)
  }

  private var hubHeader: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Layout.cardInnerSpacing) {
      if let name = store.currentLocation?.name {
        Text(name)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      }
      if let w = store.displayedWeather {
        HStack(alignment: .bottom, spacing: DesignTokens.Spacing.space8) {
          Text(store.formatTemperatureShort(w.currentTemp))
            .font(DesignTokens.Typography.compactTemp())
            .foregroundStyle(DesignTokens.Palette.textPrimary)
          Text(w.conditionText)
            .font(DesignTokens.Typography.callout())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(DesignTokens.Layout.cardPadding)
    .dayCastCard()
  }

  private func moreTitle(for tab: WeatherStore.Tab) -> String {
    switch tab {
    case .grok: "Sky Check"
    default: tab.rawValue
    }
  }

  private func moreSubtitle(for tab: WeatherStore.Tab) -> String {
    switch tab {
    case .grok:
      GrokAccessRules.moreHubGrokSubtitle(
        canUseAI: EntitlementChecker.canUseGrokAI(
          subscription: SubscriptionManager.shared,
          hasDeveloperKey: store.grokConfig.hasValidDeveloperKey
        )
      )
    case .locations:
      "\(store.savedLocations.count) saved place\(store.savedLocations.count == 1 ? "" : "s")"
    case .settings: "Units, alerts, privacy"
    default: ""
    }
  }

  private func moreTint(for tab: WeatherStore.Tab) -> Color {
    switch tab {
    case .grok: DesignTokens.Palette.accent
    case .locations: DesignTokens.Palette.accentCool
    case .settings: DesignTokens.Palette.textSecondary
    default: DesignTokens.Palette.accent
    }
  }
}
