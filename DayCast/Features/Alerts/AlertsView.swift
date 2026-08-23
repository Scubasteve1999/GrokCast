import SwiftUI

private let bottomTabClearance = DesignTokens.Layout.tabBarScrollClearance
private let alertsContentTopPadding = DesignTokens.Spacing.space16

enum AlertRowLayout {
  case standard
  /// Figma Alerts screen: title, meta line, summary body in a card.
  case figma
}

struct AlertsView: View {
  @Environment(WeatherStore.self) private var store
  @Environment(SevereWeatherStore.self) private var severeStore
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

  private var severeContextForLocation: SevereWeatherContext? {
    guard let locID = store.currentLocation?.id.uuidString,
      severeStore.context.locationID == locID
    else { return nil }
    return severeStore.context
  }

  private var hasSevereProducts: Bool {
    severeContextForLocation?.hasSPCContent == true
  }

  /// Avoid flashing the empty state while SPC products are still loading.
  private var isWaitingOnSevereProducts: Bool {
    activeAlerts.isEmpty && historicalAlerts.isEmpty && !hasSevereProducts
      && severeStore.isRefreshing
  }

  private var hasNoAlertContent: Bool {
    activeAlerts.isEmpty && historicalAlerts.isEmpty && !hasSevereProducts
  }

  private var alertsFetchFailed: Bool {
    store.alertsLoadState == .failed
  }

  private var outlookSummary: String? {
    guard let ctx = severeContextForLocation, ctx.day1Outlook.isMeaningful else { return nil }
    return ctx.day1Outlook.summaryLine
  }

  private var honesty: AlertsHonesty.Chrome {
    AlertsHonesty.chrome(
      nwsAlertCount: activeAlerts.count,
      hasSevereProducts: hasSevereProducts,
      outlookSummary: outlookSummary
    )
  }

  var body: some View {
    NavigationStack {
      Group {
        if (store.isLoadingWeather || isWaitingOnSevereProducts
          || store.alertsLoadState == .pending)
          && hasNoAlertContent
        {
          alertsSkeleton
        } else if alertsFetchFailed && hasNoAlertContent {
          errorState
        } else if hasNoAlertContent {
          emptyState
        } else {
          alertsList
        }
      }
      .readableContentWidth(ReadableContentWidth.wide)
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
  }

  private var alertsSkeleton: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        FigmaScreenTitle(title: AlertsHonesty.tabTitle)

        ShimmerBlock(width: nil, height: 52, cornerRadius: DesignTokens.Radius.medium)
        ShimmerBlock(width: nil, height: 88, cornerRadius: DesignTokens.Radius.medium)
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.top, alertsContentTopPadding)
      .padding(.bottom, bottomTabClearance)
    }
    .scrollContentBackground(.hidden)
    .background(DesignTokens.Palette.bgPrimary)
  }

  private var alertsList: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        FigmaScreenTitle(title: honesty.screenTitle)
          .accessibilityIdentifier(DayCastAccessibility.Alerts.screenTitle)
          .accessibilityLabel(honesty.screenAccessibilityLabel)

        if alertsFetchFailed {
          alertsErrorBanner
        }

        if honesty.riskCaption != nil || honesty.noActiveAlertsCaption != nil {
          VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
            if let risk = honesty.riskCaption {
              Text(risk)
                .font(DesignTokens.Typography.callout())
                .foregroundStyle(DesignTokens.Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let caption = honesty.noActiveAlertsCaption {
              Text(caption)
                .font(DesignTokens.Typography.caption())
                .foregroundStyle(DesignTokens.Palette.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
          .accessibilityHidden(true)
          .accessibilityIdentifier(DayCastAccessibility.Alerts.noActiveCaption)
        }

        if honesty.showsActiveNow {
          VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
            FigmaAccentSectionLabel(
              title: AlertsHonesty.activeNow,
              icon: "bolt.fill",
              color: DesignTokens.Palette.danger
            )

            AlertsGrokSummaryCard(alerts: activeAlerts, presentation: .figma)

            VStack(spacing: DesignTokens.Spacing.space12) {
              ForEach(activeAlerts) { alert in
                alertRow(alert, isActive: true, layout: .figma)
              }
            }
          }
        }

        if let severe = severeContextForLocation, severe.hasSPCContent {
          SevereProductsSections(context: severe)
        }

        if !historicalAlerts.isEmpty {
          VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
            FigmaSectionLabel(title: "RECENT")

            VStack(spacing: DesignTokens.Spacing.space12) {
              ForEach(historicalAlerts) { alert in
                alertRow(alert, isActive: false, layout: .figma)
              }
            }

            Text("Showing alerts from the last \(AlertHistoryStore.retentionDays) days.")
              .font(DesignTokens.Typography.micro())
              .foregroundStyle(DesignTokens.Palette.textTertiary)
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
    .background(DesignTokens.Palette.bgPrimary)
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
    let tint = NWSAlertStyle.tint(for: alert)
    return HStack(alignment: .top, spacing: DesignTokens.Spacing.space12) {
      Image(systemName: NWSAlertStyle.iconName(for: alert))
        .font(DesignTokens.Typography.metric())
        .foregroundStyle(tint)
        .frame(width: 28)

      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.space8) {
          Text(alert.event)
            .font(
              isActive ? DesignTokens.Typography.headline() : DesignTokens.Typography.subsection()
            )
            .foregroundStyle(DesignTokens.Palette.textPrimary)
            .multilineTextAlignment(.leading)
          Spacer(minLength: 0)
          if isActive {
            Text("LIVE")
              .font(DesignTokens.Typography.micro())
              .tracking(1)
              .padding(.horizontal, DesignTokens.Spacing.space8)
              .padding(.vertical, DesignTokens.Spacing.space4)
              .background(tint.opacity(0.2), in: Capsule())
              .foregroundStyle(tint)
          }
        }

        Text(figmaMetaLine(for: alert, isActive: isActive))
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(
            isActive ? DesignTokens.Palette.textSecondary : DesignTokens.Palette.textTertiary
          )
          .lineLimit(2)
          .multilineTextAlignment(.leading)

        if isActive, let headline = alert.headline, !headline.isEmpty {
          Text(headline)
            .font(DesignTokens.Typography.callout())
            .foregroundStyle(DesignTokens.Palette.textPrimary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
        }
      }
    }
    .padding(DesignTokens.Spacing.space16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardStyle(
      background: DesignTokens.Palette.cardBackground,
      stroke: isActive ? tint.opacity(0.45) : DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Card.cornerRadiusMedium
    )
    .overlay(alignment: .leading) {
      if isActive {
        UnevenRoundedRectangle(
          topLeadingRadius: DesignTokens.Card.cornerRadiusMedium,
          bottomLeadingRadius: DesignTokens.Card.cornerRadiusMedium,
          bottomTrailingRadius: 0,
          topTrailingRadius: 0
        )
        .fill(tint)
        .frame(width: 3)
        .padding(.vertical, DesignTokens.Spacing.space8)
      }
    }
  }

  private func figmaMetaLine(for alert: NWSAlert, isActive: Bool) -> String {
    if isActive {
      let until =
        alert.expires.map {
          $0.formatted(date: .omitted, time: .shortened)
        } ?? "Active"
      let area =
        alert.areaDesc?.components(separatedBy: ";").first?.trimmingCharacters(in: .whitespaces)
        ?? ""
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
        .font(DesignTokens.Typography.metric())
        .foregroundStyle(NWSAlertStyle.tint(for: alert))
        .frame(width: 28)

      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
        Text(alert.event)
          .font(DesignTokens.Typography.subsection())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .multilineTextAlignment(.leading)

        if let headline = alert.headline, !headline.isEmpty {
          Text(headline)
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textPrimary.opacity(0.75))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
        }

        if let area = alert.areaDesc, !area.isEmpty {
          Text(area)
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
            .lineLimit(1)
        }

        Text(rowTimestamp(for: alert, isActive: isActive))
          .font(DesignTokens.Typography.micro().monospaced())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }

      Spacer(minLength: 0)

      if isActive {
        Text("LIVE")
          .font(DesignTokens.Typography.micro())
          .tracking(1)
          .padding(.horizontal, DesignTokens.Spacing.space8)
          .padding(.vertical, DesignTokens.Spacing.space4)
          .background(NWSAlertStyle.tint(for: alert).opacity(0.2), in: Capsule())
          .foregroundStyle(NWSAlertStyle.tint(for: alert))
      }

      Image(systemName: "chevron.right")
        .font(DesignTokens.Typography.caption())
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

  private var alertsErrorBanner: some View {
    HStack(spacing: 8) {
      Image(systemName: store.isOffline ? "wifi.slash" : "exclamationmark.triangle.fill")
        .foregroundStyle(DesignTokens.Palette.danger)
      Text("Couldn't refresh alerts. Showing last known warnings.")
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.danger)
        .lineLimit(2)
      Spacer(minLength: 8)
      Button("Retry") {
        Haptic.impact(.medium)
        Task { await store.refreshAlerts(force: true) }
      }
      .font(DesignTokens.Typography.caption())
      .buttonStyle(.bordered)
      .tint(DesignTokens.Palette.danger)
      .controlSize(.small)
      .accessibilityIdentifier(DayCastAccessibility.Alerts.retry)
    }
    .padding(DesignTokens.Spacing.space8)
    .background(DesignTokens.Palette.danger.opacity(0.15))
    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
  }

  private var errorState: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        FigmaScreenTitle(title: AlertsHonesty.tabTitle)

        ContentUnavailableView {
          Label(
            "Unable to Load Alerts",
            systemImage: store.isOffline ? "wifi.slash" : "exclamationmark.triangle"
          )
        } description: {
          Text(
            "Couldn't check NWS alerts for \(store.currentLocation?.name ?? "this location"). Try again."
          )
        } actions: {
          Button("Try Again") {
            Haptic.impact(.medium)
            Task { await store.refreshAlerts(force: true) }
          }
          .buttonStyle(.borderedProminent)
          .accessibilityIdentifier(DayCastAccessibility.Alerts.retry)
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
    .background(DesignTokens.Palette.bgPrimary)
  }

  private var emptyState: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        FigmaScreenTitle(title: AlertsHonesty.tabTitle)

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
    .background(DesignTokens.Palette.bgPrimary)
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
    .environment(SevereWeatherStore.shared)
}
