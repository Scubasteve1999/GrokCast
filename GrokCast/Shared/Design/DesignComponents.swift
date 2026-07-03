import SwiftUI

// MARK: - Section chrome (Settings, More hub, long forms)

struct SettingsSectionHeader: View {
  let title: String
  var footer: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      Text(title)
        .font(.caption.weight(.heavy))
        .tracking(DesignTokens.Typography.cardLabelTracking)
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .textCase(.uppercase)

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
    .glassCardStyle()
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
          .font(.title3)
          .foregroundStyle(tint)
          .frame(width: 28)
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.body.weight(.semibold))
            .foregroundStyle(DesignTokens.Palette.textPrimary)
          if let subtitle {
            Text(subtitle)
              .font(.caption)
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space24) {
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
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      if let name = store.currentLocation?.name {
        Text(name.uppercased())
          .font(.caption.weight(.heavy))
          .tracking(DesignTokens.Typography.headerTracking)
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }
      if let w = store.currentWeather {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.space8) {
          Text(store.formatTemperatureShort(w.currentTemp))
            .font(.system(size: 44, weight: .black, design: .rounded))
            .foregroundStyle(DesignTokens.Palette.textPrimary)
          Text(w.conditionText)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(DesignTokens.Spacing.space20)
    .glassCardStyle()
  }

  private func moreSubtitle(for tab: WeatherStore.Tab) -> String {
    switch tab {
    case .grok: store.xaiService.hasValidKey ? "Chat, Imagine, Storm Spotter" : "Add xAI key to unlock"
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
