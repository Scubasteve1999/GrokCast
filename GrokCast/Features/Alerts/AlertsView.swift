import SwiftUI

private let bottomTabClearance = DesignTokens.Spacing.space32
private let alertsContentTopPadding = DesignTokens.Spacing.space16

enum AlertRowLayout {
  case standard
  /// Figma Alerts screen: title, meta line, summary body in a card.
  case figma
}

struct AlertsView: View {
  @Environment(WeatherStore.self) private var store
  @State private var selectedAlert: NWSAlert?

  private var activeAlerts: [NWSAlert] {
    store.displayableActiveAlerts
      .sorted { $0.severityLevel > $1.severityLevel }
  }

  private var historicalAlerts: [NWSAlert] {
    let activeIDs = Set(activeAlerts.map(\.id))
    return store.alertHistory
      .filter { !activeIDs.contains($0.id) }
      .sorted { $0.sortDate > $1.sortDate }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        TodaySkyBackground(
          conditionCode: store.currentWeather?.conditionCode ?? 1,
          isDay: store.currentWeather.map {
            WeatherBackgroundView.isDay(from: $0.symbolName)
          } ?? WeatherBackgroundView.inferredIsDay
        )
        .ignoresSafeArea()

        Group {
          if store.isLoadingWeather && activeAlerts.isEmpty && historicalAlerts.isEmpty {
            alertsSkeleton
          } else if activeAlerts.isEmpty && historicalAlerts.isEmpty {
            emptyState
          } else {
            alertsList
          }
        }
        .readableContentWidth(ReadableContentWidth.wide)
      }
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
      .navigationDestination(item: $selectedAlert) { alert in
        AlertDetailView(alert: alert)
      }
      .task {
        guard store.hasCompletedInitialLoad else { return }
        await store.refreshAlerts()
      }
    }
    .preferredColorScheme(.dark)
  }

  private var alertsSkeleton: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        Text("ALERTS")
          .font(DesignTokens.Figma.Typography.screenTitle)
          .foregroundStyle(TodayBright.textPrimary)
          .skyTextShadow()

        FigmaAccentSectionLabel(
          title: "ACTIVE NOW",
          icon: "bolt.fill",
          color: DesignTokens.Palette.danger
        )

        ShimmerBlock(width: nil, height: 52, cornerRadius: DesignTokens.Radius.medium)
        ShimmerBlock(width: nil, height: 88, cornerRadius: DesignTokens.Radius.medium)
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.top, alertsContentTopPadding)
      .padding(.bottom, bottomTabClearance)
    }
    .scrollContentBackground(.hidden)
  }

  private var alertsList: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        Text("ALERTS")
          .font(DesignTokens.Figma.Typography.screenTitle)
          .foregroundStyle(TodayBright.textPrimary)
          .skyTextShadow()

        VStack(alignment: .leading, spacing: DesignTokens.Figma.Metrics.sectionSpacing) {
          Label {
            Text("ACTIVE NOW")
              .font(.caption.weight(.semibold))
              .tracking(0.6)
          } icon: {
            Image(systemName: "bolt.fill")
              .font(.caption)
          }
          .foregroundStyle(DesignTokens.Palette.danger)
          .skyTextShadow()

          if activeAlerts.isEmpty {
            Text("No active alerts right now")
              .font(.subheadline)
              .foregroundStyle(TodayBright.textSecondary)
              .frame(maxWidth: .infinity, alignment: .leading)
          } else {
            AlertsGrokSummaryCard(alerts: activeAlerts, presentation: .figma)

            VStack(spacing: DesignTokens.Spacing.space12) {
              ForEach(activeAlerts) { alert in
                alertRow(alert, isActive: true, layout: .figma)
              }
            }
          }
        }

        if !historicalAlerts.isEmpty {
          VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
            TodaySectionHeader(title: "RECENT", systemImage: "clock.arrow.circlepath")
              .skyTextShadow()

            VStack(spacing: DesignTokens.Spacing.space12) {
              ForEach(historicalAlerts) { alert in
                alertRow(alert, isActive: false, layout: .figma)
              }
            }

            Text("Showing alerts from the last \(AlertHistoryStore.retentionDays) days.")
              .font(.caption2)
              .foregroundStyle(TodayBright.textTertiary)
          }
        }
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.top, alertsContentTopPadding)
      .padding(.bottom, bottomTabClearance)
    }
    .refreshable {
      await store.refreshAlerts(force: true)
    }
    .scrollContentBackground(.hidden)
  }

  private func alertRow(_ alert: NWSAlert, isActive: Bool, layout: AlertRowLayout) -> some View {
    Button {
      Haptic.impact(.light)
      selectedAlert = alert
    } label: {
      switch layout {
      case .standard:
        standardAlertRow(alert, isActive: isActive)
      case .figma:
        figmaAlertRow(alert, isActive: isActive)
      }
    }
    .buttonStyle(.plain)
  }

  private func figmaAlertRow(_ alert: NWSAlert, isActive: Bool) -> some View {
    HStack(alignment: .top, spacing: DesignTokens.Spacing.space12) {
      Image(systemName: NWSAlertStyle.iconName(for: alert))
        .font(.title3.weight(.semibold))
        .foregroundStyle(NWSAlertStyle.tint(for: alert))
        .padding(.top, 2)

      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
        Text(alert.event)
          .font(.system(size: isActive ? 17 : 15, weight: isActive ? .bold : .semibold))
          .foregroundStyle(TodayBright.textPrimary)
          .multilineTextAlignment(.leading)

        Text(figmaMetaLine(for: alert, isActive: isActive))
          .font(.system(size: 13))
          .foregroundStyle(isActive ? TodayBright.textSecondary : TodayBright.textTertiary)
          .lineLimit(2)
          .multilineTextAlignment(.leading)

        if isActive, let headline = alert.headline, !headline.isEmpty {
          Text(headline)
            .font(.system(size: 14))
            .foregroundStyle(TodayBright.textPrimary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
        }
      }

      Spacer(minLength: 0)

      Image(systemName: "chevron.right")
        .font(.caption.weight(.semibold))
        .foregroundStyle(TodayBright.textTertiary)
        .padding(.top, 4)
    }
    .padding(DesignTokens.Spacing.space16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .todayGlassCard(cornerRadius: DesignTokens.Card.cornerRadiusMedium)
  }

  private func figmaMetaLine(for alert: NWSAlert, isActive: Bool) -> String {
    if isActive {
      let until = alert.expires.map {
        $0.formatted(date: .omitted, time: .shortened)
      } ?? "Active"
      let area = alert.areaDesc?.components(separatedBy: ";").first?.trimmingCharacters(in: .whitespaces) ?? ""
      if area.isEmpty { return "Until \(until)" }
      return "Until \(until) · \(area)"
    }
    let detail = alert.headline ?? alert.event
    return "Expired \(relativeExpiry(for: alert)) · \(detail)"
  }

  private func relativeExpiry(for alert: NWSAlert) -> String {
    let interval = -alert.sortDate.timeIntervalSinceNow
    if interval < 86_400 { return "today" }
    if interval < 172_800 { return "yesterday" }
    return alert.sortDate.formatted(date: .abbreviated, time: .omitted)
  }

  private func standardAlertRow(_ alert: NWSAlert, isActive: Bool) -> some View {
    HStack(alignment: .top, spacing: DesignTokens.Spacing.space12) {
      Image(systemName: NWSAlertStyle.iconName(for: alert))
        .font(.title3)
        .foregroundStyle(NWSAlertStyle.tint(for: alert))
        .frame(width: 28)

      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
        Text(alert.event)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .multilineTextAlignment(.leading)

        if let headline = alert.headline, !headline.isEmpty {
          Text(headline)
            .font(.caption)
            .foregroundStyle(DesignTokens.Palette.textPrimary.opacity(0.75))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
        }

        if let area = alert.areaDesc, !area.isEmpty {
          Text(area)
            .font(.caption2)
            .foregroundStyle(DesignTokens.Palette.textTertiary)
            .lineLimit(1)
        }

        Text(rowTimestamp(for: alert, isActive: isActive))
          .font(.caption2.monospaced())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }

      Spacer(minLength: 0)

      if isActive {
        Text("LIVE")
          .font(.caption2.weight(.heavy))
          .tracking(1)
          .padding(.horizontal, DesignTokens.Spacing.space8)
          .padding(.vertical, DesignTokens.Spacing.space4)
          .background(NWSAlertStyle.tint(for: alert).opacity(0.2), in: Capsule())
          .foregroundStyle(NWSAlertStyle.tint(for: alert))
      }

      Image(systemName: "chevron.right")
        .font(.caption.weight(.semibold))
        .foregroundStyle(DesignTokens.Palette.textTertiary)
    }
    .padding(DesignTokens.Spacing.space16)
    .cardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadiusMedium
    )
    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
  }

  private func rowTimestamp(for alert: NWSAlert, isActive: Bool) -> String {
    if isActive, let expires = alert.expires {
      return "Expires \(expires.formatted(date: .abbreviated, time: .shortened))"
    }
    return alert.sortDate.formatted(date: .abbreviated, time: .shortened)
  }

  private var emptyState: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        Text("ALERTS")
          .font(DesignTokens.Figma.Typography.screenTitle)
          .foregroundStyle(TodayBright.textPrimary)
          .skyTextShadow()

        ContentUnavailableView {
          Label("No Alerts", systemImage: "checkmark.shield")
        } description: {
          Text(
            "No active or recent NWS alerts for \(store.currentLocation?.name ?? "your location"). Severe weather Warnings and Watches will appear here."
          )
        } actions: {
          Button("Refresh") {
            Haptic.impact(.medium)
            Task { await store.refreshAlerts(force: true) }
          }
          .buttonStyle(.borderedProminent)
        }
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.top, alertsContentTopPadding)
      .padding(.bottom, bottomTabClearance)
    }
    .refreshable {
      await store.refreshAlerts(force: true)
    }
    .scrollContentBackground(.hidden)
  }
}

#Preview {
  let store = WeatherStore()
  store.activeAlerts = [
    NWSAlert(
      id: "preview-active",
      event: "Severe Thunderstorm Warning",
      severity: "Severe",
      headline: "Take shelter immediately",
      description: "Damaging winds expected.",
      instruction: "Move to an interior room.",
      expires: Date().addingTimeInterval(3600),
      areaDesc: "DeSoto, MS",
      latitude: 34.96,
      longitude: -89.83
    )
  ]
  store.alertHistory = store.activeAlerts
  return AlertsView()
    .environment(store)
}
