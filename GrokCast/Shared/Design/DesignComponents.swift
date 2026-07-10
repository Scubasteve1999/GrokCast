import SwiftUI

// MARK: - Figma screen chrome (GrokCast Screens page)

struct FigmaScreenTitle: View {
  enum Style {
    case screen
    case studio
  }

  let title: String
  var style: Style = .screen

  var body: some View {
    Text(title)
      .font(style == .screen ? DesignTokens.Figma.Typography.screenTitle : DesignTokens.Figma.Typography.studioTitle)
      .foregroundStyle(DesignTokens.Palette.textPrimary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct FigmaSectionLabel: View {
  let title: String

  var body: some View {
    Text(title)
      .font(DesignTokens.Figma.Typography.sectionLabel)
      .foregroundStyle(DesignTokens.Palette.textTertiary)
      .textCase(.uppercase)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct FigmaSubsectionLabel: View {
  let title: String

  var body: some View {
    Text(title)
      .font(DesignTokens.Figma.Typography.subsectionLabel)
      .foregroundStyle(DesignTokens.Palette.textTertiary)
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
        .font(.system(size: 12, weight: .bold))
      Text(title)
        .font(DesignTokens.Figma.Typography.sectionLabel)
    }
    .foregroundStyle(color)
    .textCase(.uppercase)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

extension View {
  /// Standard Figma screen content padding (20pt sides, tab-bar bottom clearance).
  func figmaScreenPadding(top: CGFloat = DesignTokens.Figma.Metrics.topPadding) -> some View {
    padding(.horizontal, DesignTokens.Figma.Metrics.horizontalPadding)
      .padding(.top, top)
      .padding(.bottom, DesignTokens.Figma.Metrics.bottomPadding)
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
          .font(.caption)
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
      cornerRadius: DesignTokens.Figma.Metrics.cardRadius
    )
  }
}

struct SettingsToggleRow: View {
  let title: String
  @Binding var isOn: Bool

  var body: some View {
    Toggle(isOn: $isOn) {
      Text(title)
        .font(.body)
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
          .font(.body)
          .foregroundStyle(DesignTokens.Palette.accent)
          .frame(width: 24)
        Text(title)
          .font(.body)
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        Spacer()
        Image(systemName: "arrow.up.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }
      .padding(.horizontal, DesignTokens.Spacing.space16)
      .padding(.vertical, DesignTokens.Spacing.space12)
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
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(tint)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(DesignTokens.Figma.Typography.rowTitle)
            .foregroundStyle(DesignTokens.Palette.textPrimary)
          if let subtitle {
            Text(subtitle)
              .font(DesignTokens.Figma.Typography.rowSubtitle)
              .foregroundStyle(DesignTokens.Palette.textSecondary)
          }
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption.weight(.bold))
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }
      .padding(.horizontal, DesignTokens.Spacing.space16)
      .padding(.vertical, DesignTokens.Spacing.space12)
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
        VStack(alignment: .leading, spacing: DesignTokens.Figma.Metrics.sectionSpacing) {
          hubHeader

          SettingsGroupCard {
            ForEach(Array(WeatherStore.Tab.moreHub.enumerated()), id: \.element.id) { index, tab in
              if index > 0 { SettingsDivider() }
              SettingsNavigationRow(
                title: tab.rawValue,
                subtitle: moreSubtitle(for: tab),
                icon: tab.icon,
                tint: moreTint(for: tab)
              ) {
                Haptic.selection()
                store.selectedTab = tab
                dismiss()
              }
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
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }

  private var hubHeader: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Figma.Metrics.cardInnerSpacing) {
      if let name = store.currentLocation?.name {
        Text(name.uppercased())
          .font(DesignTokens.Figma.Typography.locationLabel)
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      }
      if let w = store.currentWeather {
        HStack(alignment: .bottom, spacing: DesignTokens.Spacing.space8) {
          Text(store.formatTemperatureShort(w.currentTemp))
            .font(.system(size: 44, weight: .black, design: .rounded))
            .foregroundStyle(DesignTokens.Palette.textPrimary)
          Text(w.conditionText)
            .font(DesignTokens.Figma.Typography.body)
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(DesignTokens.Figma.Metrics.cardPadding)
    .cardStyle(cornerRadius: DesignTokens.Figma.Metrics.cardRadius)
  }

  private func moreSubtitle(for tab: WeatherStore.Tab) -> String {
    switch tab {
    case .grok:
      store.xaiService.hasValidKey ? "Chat, Imagine, Storm Spotter" : "Add key in Settings"
    case .locations: "\(store.savedLocations.count) saved places"
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
