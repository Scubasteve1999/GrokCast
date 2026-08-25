import SwiftUI

private let alertsContentTopPadding = DesignTokens.Spacing.space16

enum AlertRowLayout {
  case standard
  /// Figma Alerts screen: title, meta line, summary body in a card.
  case figma
}

struct AlertsView: View {
  @Environment(WeatherStore.self) private var store
  @Environment(SevereWeatherStore.self) private var severeStore
  @Environment(LocalBriefingStore.self) private var briefingStore
  @State private var selectedAlert: NWSAlert?

  private var activeAlerts: [NWSAlert] {
    store.displayableGroupedAlerts
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

  private var hasVisibleOutlookOrMD: Bool {
    guard let ctx = severeContextForLocation else { return false }
    return ctx.day1Outlook.isMeaningful || !ctx.mesoscaleDiscussions.isEmpty
  }

  private var hasVisibleStormReports: Bool {
    guard let ctx = severeContextForLocation else { return false }
    return StormReportsVisibility.isSectionVisible(
      reportCount: ctx.localStormReports.count,
      preferenceEnabled: severeStore.showsStormReports
    )
  }

  private var hasBriefing: Bool {
    guard let locID = store.currentLocation?.id.uuidString else { return false }
    return briefingStore.locationID == locID && !briefingStore.items.isEmpty
  }

  /// Avoid flashing the empty state while SPC / briefing products are still loading.
  private var isWaitingOnSevereProducts: Bool {
    !hasVisibleAlertBody
      && (severeStore.isRefreshing || briefingStore.isRefreshing)
  }

  private var hasVisibleAlertBody: Bool {
    !activeAlerts.isEmpty || !historicalAlerts.isEmpty || hasVisibleOutlookOrMD
      || hasVisibleStormReports || hasBriefing
  }

  private var hasNoAlertContent: Bool {
    !hasVisibleAlertBody
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
      .weatherShowsThroughNavigationBar()
      .background {
        WeatherBackgroundLayer(
          conditionCode: store.displayedWeather?.conditionCode,
          isDay: store.displayedWeather.map {
            WeatherBackgroundView.isDay(from: $0.symbolName)
          }
            ?? WeatherBackgroundView.inferredIsDay(
              timeZone: store.displayedWeather?.locationTimeZone ?? .current
            )
        )
      }
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
      VStack(spacing: 0) {
        alertsHero(title: AlertsHonesty.tabTitle)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
          ShimmerBlock(width: nil, height: 52, cornerRadius: DesignTokens.Radius.medium)
          ShimmerBlock(width: nil, height: 88, cornerRadius: DesignTokens.Radius.medium)
        }
        .weatherStageSheet()
      }
    }
    .scrollContentBackground(.hidden)
    .background(Color.clear)
  }

  private var alertsList: some View {
    ScrollView {
      VStack(spacing: 0) {
        alertsHero(
          title: honesty.screenTitle,
          titleID: DayCastAccessibility.Alerts.screenTitle,
          titleA11y: honesty.screenAccessibilityLabel
        )

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
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
              Text("Active Now")
                .font(DesignTokens.Typography.studioTitle())
                .foregroundStyle(DesignTokens.Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

              VStack(spacing: DesignTokens.Spacing.space12) {
                ForEach(activeAlerts) { alert in
                  alertRow(alert, isActive: true, layout: .figma)
                }
              }

              AlertsGrokSummaryCard(alerts: activeAlerts, presentation: .figma)
            }
          }

          if let severe = severeContextForLocation, hasVisibleOutlookOrMD {
            SevereProductsSections(context: severe)
          }

          if hasBriefing {
            LocalBriefingSection(items: briefingStore.items, sitsInSheet: true)
          }

          if hasVisibleStormReports, let severe = severeContextForLocation {
            StormReportsSection(reports: severe.localStormReports)
          }

          if !historicalAlerts.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
              Text("Recent")
                .font(DesignTokens.Typography.studioTitle())
                .foregroundStyle(DesignTokens.Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

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
        .weatherStageSheet()
      }
    }
    .refreshable {
      await store.refreshAlerts(force: true)
    }
    .scrollContentBackground(.hidden)
    .background(Color.clear)
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
        .font(DesignTokens.Typography.symbol(16))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(tint)
        .frame(width: 22)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
        Text(alert.usesWarningEmphasis ? alert.event.uppercased() : alert.event)
          .font(
            alert.usesWarningEmphasis
              ? DesignTokens.Typography.studioTitle()
              : (isActive
                ? DesignTokens.Typography.headline() : DesignTokens.Typography.subsection())
          )
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)

        if isActive,
          let body = AlertsActiveCopy.cardBody(
            event: alert.event,
            headline: alert.headline,
            instruction: alert.instruction,
            description: alert.description
          )
        {
          Text(body)
            .font(DesignTokens.Typography.callout())
            .foregroundStyle(DesignTokens.Palette.textPrimary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
        }

        Text(figmaMetaLine(for: alert, isActive: isActive))
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(
            isActive ? DesignTokens.Palette.textSecondary : DesignTokens.Palette.textTertiary
          )
          .lineLimit(2)
          .multilineTextAlignment(.leading)
      }
    }
    .padding(DesignTokens.Spacing.space16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      RoundedRectangle(
        cornerRadius: DesignTokens.Card.cornerRadiusMedium,
        style: .continuous
      )
      .fill(
        isActive
          ? tint.opacity(alert.usesWarningEmphasis ? 0.28 : 0.12)
          : DesignTokens.Palette.cardBackground.opacity(0.45)
      )
    }
    .overlay(
      RoundedRectangle(
        cornerRadius: DesignTokens.Card.cornerRadiusMedium,
        style: .continuous
      )
      .stroke(DesignTokens.Palette.cardHairline, lineWidth: DesignTokens.Card.strokeWidth)
    )
  }

  private func figmaMetaLine(for alert: NWSAlert, isActive: Bool) -> String {
    if isActive {
      return AlertsActiveCopy.untilLine(
        expires: alert.expires,
        areaDesc: alert.areaDesc,
        calendar: store.displayedWeather?.locationCalendar ?? .current,
        timeZone: store.displayedWeather?.locationTimeZone ?? .current
      )
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

  private func alertsHero(
    title: String,
    titleID: String? = nil,
    titleA11y: String? = nil
  ) -> some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      FigmaScreenTitle(title: title)
        .accessibilityIdentifier(titleID ?? DayCastAccessibility.Alerts.screenTitle)
        .accessibilityLabel(titleA11y ?? title)
      alertsAuthorityLine
    }
    .padding(.horizontal, DesignTokens.Spacing.space20)
    .padding(.top, alertsContentTopPadding)
    .padding(.bottom, DesignTokens.Spacing.space16)
  }

  private var alertsAuthorityLine: some View {
    let line = AlertsActiveCopy.authorityLine(
      locationName: store.currentLocation?.name,
      nwsCount: activeAlerts.count,
      checkedAt: store.lastAlertsFetchAt,
      loadState: store.alertsLoadState,
      hasCachedAlerts: !store.displayableGroupedAlerts.isEmpty
    )
    return Text(line)
      .font(DesignTokens.Typography.caption())
      .foregroundStyle(DesignTokens.Palette.textSecondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityLabel(line)
      .accessibilityIdentifier(DayCastAccessibility.Alerts.authority)
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
      VStack(spacing: 0) {
        alertsHero(title: AlertsHonesty.tabTitle)
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
        .weatherStageSheet()
      }
    }
    .refreshable {
      await store.refreshAlerts(force: true)
    }
    .scrollContentBackground(.hidden)
    .background(Color.clear)
  }

  private var emptyState: some View {
    ScrollView {
      VStack(spacing: 0) {
        alertsHero(title: AlertsHonesty.tabTitle)
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
        .weatherStageSheet()
      }
    }
    .refreshable {
      await store.refreshAlerts(force: true)
    }
    .scrollContentBackground(.hidden)
    .background(Color.clear)
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
    .environment(LocalBriefingStore.shared)
}
