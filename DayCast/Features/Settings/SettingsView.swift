import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
  @Environment(WeatherStore.self) private var store
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(GrokBriefSafety.self) private var briefSafety
  @Environment(\.scenePhase) private var scenePhase

  @State private var apiKeyInput = ""
  @State private var isEditingKey = false
  @State private var showSaveConfirmation = false
  @State private var isTestingConnection = false
  @State private var connectionTestResult: String?
  @State private var connectionTestSuccess = false

  private var hasKey: Bool {
    store.xaiService.hasDeveloperAPIKey
  }

  var body: some View {
    NavigationStack {
      settingsScroll
        .readableContentWidth(ReadableContentWidth.wide)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Key Saved", isPresented: $showSaveConfirmation) {
          Button("OK") {}
        } message: {
          Text("xAI API key securely stored in the iOS Keychain.")
        }
        .task {
          await store.refreshAlertNotificationAuthorizationStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
          if newPhase == .active {
            Task { await store.refreshAlertNotificationAuthorizationStatus() }
          }
        }
    }
  }

  private var settingsScroll: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        FigmaScreenTitle(title: "Settings")

        FigmaSectionLabel(title: "DAYCAST PRO")
        proCard

        FigmaSectionLabel(title: "NOTIFICATIONS")
        notificationsCard

        FigmaSectionLabel(title: "DISPLAY")
        displayCard

        FigmaSectionLabel(title: "DEVELOPER")
        SettingsGroupCard { developerKeySection }

        FigmaSectionLabel(title: "LOCATION UPDATES")
        SettingsGroupCard {
          toggleRow(
            title: "Travel Weather Refresh",
            subtitle: store.significantLocationUpdatesEnabled
              ? "Significant location changes" : "Off",
            icon: "location.circle.fill",
            isOn: Binding(
              get: { store.significantLocationUpdatesEnabled },
              set: { store.significantLocationUpdatesEnabled = $0 }
            )
          )
        }

        FigmaSectionLabel(title: "TOOLS")
        SettingsGroupCard {
          NavigationLink {
            TripPlannerView()
          } label: {
            settingsChevronRow(title: "Trip Weather Planner", icon: "airplane.departure")
          }
          .buttonStyle(.plain)
        }

        FigmaSectionLabel(title: "APP")
        appCard

        FigmaSectionLabel(title: "PRIVACY")
        SettingsGroupCard {
          toggleRow(
            title: "Share analytics",
            subtitle: PostHogAnalytics.isConfigured
              ? "Anonymous usage · no session replay"
              : "Off until POSTHOG_API_KEY is set",
            icon: "chart.bar.fill",
            isOn: Binding(
              get: { !PostHogAnalytics.isOptedOut },
              set: { PostHogAnalytics.setOptedOut(!$0) }
            )
          )
          .disabled(!PostHogAnalytics.isConfigured)
        }

        FigmaSectionLabel(title: "LEGAL & SUPPORT")
        SettingsGroupCard {
          SettingsLinkRow(title: "Privacy Policy", icon: "hand.raised", url: AppLinks.privacyPolicy)
          SettingsDivider()
          SettingsLinkRow(title: "Terms of Use", icon: "doc.text", url: AppLinks.termsOfUse)
          SettingsDivider()
          SettingsLinkRow(title: "Support", icon: "questionmark.circle", url: AppLinks.support)
          SettingsDivider()
          SettingsLinkRow(title: "Contact", icon: "envelope", url: AppLinks.supportEmail)
        }

        FigmaSectionLabel(title: "DATA & CREDITS")
        SettingsGroupCard {
          SettingsLinkRow(title: "Get xAI API Key", icon: "link", url: AppLinks.xAIConsole)
          SettingsDivider()
          SettingsLinkRow(title: "Weather Data: Open-Meteo", icon: "link", url: AppLinks.openMeteo)
        }
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.top, DesignTokens.Spacing.space16)
      .padding(.bottom, DesignTokens.Layout.tabBarScrollClearance)
    }
    .scrollContentBackground(.hidden)
    .background(DesignTokens.Palette.bgPrimary)
  }

  private var proCard: some View {
    SettingsGroupCard {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
        if subscription.isPro {
          Label("DayCast Pro is active", systemImage: "checkmark.seal.fill")
            .foregroundStyle(DesignTokens.Palette.success)
            .padding(.horizontal, DesignTokens.Spacing.space16)
            .padding(.top, DesignTokens.Spacing.space16)
          Button("Manage Subscription") {
            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
              UIApplication.shared.open(url)
            }
          }
          .padding(.horizontal, DesignTokens.Spacing.space16)
        } else {
          Text("Unlock AI features, forecast radar, Live Activity, and unlimited locations.")
            .font(DesignTokens.Typography.callout())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
            .padding(.horizontal, DesignTokens.Spacing.space16)
            .padding(.top, DesignTokens.Spacing.space16)

          Button("View DayCast Pro") {
            PaywallCoordinator.shared.present(.locations)
          }
          .font(DesignTokens.Typography.subsection())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, DesignTokens.Spacing.space12)
          .background(
            DesignTokens.Palette.accent, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
          )
          .padding(.horizontal, DesignTokens.Spacing.space16)
          .accessibilityIdentifier(DayCastAccessibility.Settings.proEntry)
        }

        Button("Restore Purchases") {
          Task { await subscription.restorePurchases() }
        }
        .font(DesignTokens.Typography.caption())
        .padding(.horizontal, DesignTokens.Spacing.space16)
        .padding(.bottom, DesignTokens.Spacing.space16)
        .disabled(subscription.purchaseInFlight)

        if let error = subscription.lastErrorMessage {
          Text(error)
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.danger)
            .padding(.horizontal, DesignTokens.Spacing.space16)
            .padding(.bottom, DesignTokens.Spacing.space8)
        }
      }
    }
  }

  private var notificationsCard: some View {
    SettingsGroupCard {
      toggleRow(
        title: "Morning Brief",
        subtitle: store.morningBriefEnabled
          ? "Daily at \(store.morningBriefHour):00 AM" : "Off",
        icon: "bell.fill",
        isOn: Binding(
          get: { store.morningBriefEnabled },
          set: { newValue in
            if newValue,
              !EntitlementChecker.canUseMorningBrief(
                subscription: subscription, hasDeveloperKey: hasKey)
            {
              PaywallCoordinator.shared.present(.grokAI)
              return
            }
            store.morningBriefEnabled = newValue
          }
        )
      )
      if store.morningBriefEnabled {
        SettingsDivider()
        hourPickerRow
      }
      SettingsDivider()
      toggleRow(
        title: "Severe Weather Alerts",
        subtitle: store.alertNotificationsEnabled ? "Push when active" : "Off",
        icon: "exclamationmark.triangle.fill",
        isOn: Binding(
          get: { store.alertNotificationsEnabled },
          set: { store.alertNotificationsEnabled = $0 }
        )
      )
      if store.alertNotificationsEnabled {
        SettingsDivider()
        alertNotificationStatusRow
          .padding(.horizontal, DesignTokens.Spacing.space16)
          .padding(.vertical, DesignTokens.Spacing.space8)
      }
      SettingsDivider()
      toggleRow(
        title: "Hyper-Local Rain Alerts",
        subtitle: store.rainAlertsEnabled ? "Minutecast start/stop" : "Off",
        icon: "cloud.rain.fill",
        isOn: Binding(
          get: { store.rainAlertsEnabled },
          set: { enabled in
            store.rainAlertsEnabled = enabled
            if enabled {
              Task { await store.requestAlertNotificationPermissionIfNeeded() }
            }
          }
        )
      )
      SettingsDivider()
      toggleRow(
        title: "Nearby Fire Alerts",
        subtitle: store.fireProximityNotificationsEnabled
          ? "Within \(Int(store.fireProximityRadiusMiles)) mi" : "Off",
        icon: "flame.fill",
        isOn: Binding(
          get: { store.fireProximityNotificationsEnabled },
          set: { enabled in
            store.fireProximityNotificationsEnabled = enabled
            if enabled {
              Task { await store.requestAlertNotificationPermissionIfNeeded() }
            }
          }
        )
      )
      if store.fireProximityNotificationsEnabled {
        SettingsDivider()
        fireRadiusRow
      }
    }
  }

  private var displayCard: some View {
    SettingsGroupCard {
      temperatureRow
      SettingsDivider()
      toggleRow(
        title: "Live Activity",
        subtitle: subscription.isPro ? "Lock Screen score + Minutecast" : "Requires DayCast Pro",
        icon: "lock.rectangle.stack.fill",
        isOn: Binding(
          get: { store.liveActivityEnabled },
          set: { newValue in
            if newValue, !EntitlementChecker.canUseLiveActivity(subscription: subscription) {
              PaywallCoordinator.shared.present(.liveActivity)
              return
            }
            store.liveActivityEnabled = newValue
          }
        )
      )
      SettingsDivider()
      toggleRow(
        title: "Notification Sounds",
        subtitle: store.notificationSoundsEnabled ? "On" : "Off",
        icon: "speaker.wave.2.fill",
        isOn: Binding(
          get: { store.notificationSoundsEnabled },
          set: { store.notificationSoundsEnabled = $0 }
        )
      )
      SettingsDivider()
      toggleRow(
        title: "Today's Take",
        subtitle: briefSafety.isFeatureHidden ? "Hidden — tap to restore" : "AI brief on Today",
        icon: "sparkles",
        isOn: Binding(
          get: { !briefSafety.isFeatureHidden },
          set: { isOn in
            briefSafety.isFeatureHidden = !isOn
            store.refreshGrokBriefSurfaces()
          }
        )
      )
    }
  }

  private var appCard: some View {
    SettingsGroupCard {
      infoRow(
        title: "Version",
        value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
      SettingsDivider()
      infoRow(
        title: "Build",
        value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
      SettingsDivider()
      Button {
        Haptic.impact(.light)
        AppReviewPrompt.openWriteReview()
      } label: {
        settingsChevronRow(title: "Rate DayCast", icon: "star.fill", trailing: "arrow.up.right")
      }
      .buttonStyle(.plain)
      SettingsDivider()
      Button {
        Haptic.impact(.light)
        store.clearLocalWeatherCache()
      } label: {
        HStack {
          Label("Clear Local Weather Cache", systemImage: "trash")
            .foregroundStyle(DesignTokens.Palette.danger)
          Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.space16)
        .padding(.vertical, DesignTokens.Spacing.space12)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
  }

  @ViewBuilder
  private var developerKeySection: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      Button {
        if !isEditingKey {
          apiKeyInput = ""
          isEditingKey = true
          connectionTestResult = nil
        }
      } label: {
        HStack(spacing: DesignTokens.Spacing.space12) {
          Image(systemName: "key.fill")
            .font(DesignTokens.Typography.symbol(16))
            .foregroundStyle(DesignTokens.Palette.accent)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 2) {
            Text("xAI Developer Key")
              .font(DesignTokens.Typography.subsection())
              .foregroundStyle(DesignTokens.Palette.textPrimary)
            Text(developerKeySubtitle)
              .font(DesignTokens.Typography.caption())
              .foregroundStyle(DesignTokens.Palette.textSecondary)
          }
          Spacer()
          Image(systemName: "chevron.right")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
        .padding(.horizontal, DesignTokens.Spacing.space16)
        .padding(.vertical, DesignTokens.Spacing.space12)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      if isEditingKey {
        SettingsDivider()
        VStack(alignment: .leading, spacing: 8) {
          SecureField("xai-XXXXXXXXXXXXXXXXXXXXXXXX", text: $apiKeyInput)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(DesignTokens.Typography.monoBody())
            .padding(10)
            .background(
              DesignTokens.Palette.cardElevated,
              in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
            )
          HStack {
            Button("Cancel") {
              isEditingKey = false
              apiKeyInput = ""
            }
            .buttonStyle(.bordered)
            Spacer()
            Button("Save Securely") {
              saveDeveloperKey()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValidDeveloperKeyFormat(apiKeyInput))
          }
        }
        .padding(.horizontal, DesignTokens.Spacing.space16)
        .padding(.bottom, DesignTokens.Spacing.space12)
      } else if hasKey {
        SettingsDivider()
        Button {
          testGrokConnection()
        } label: {
          HStack {
            if isTestingConnection {
              ProgressView().scaleEffect(0.8)
              Text("Testing API connection…")
            } else {
              Label("Test API Connection", systemImage: "network")
            }
            Spacer()
          }
          .padding(.horizontal, DesignTokens.Spacing.space16)
          .padding(.vertical, DesignTokens.Spacing.space12)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isTestingConnection)

        if let result = connectionTestResult {
          Text(result)
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(
              connectionTestSuccess ? DesignTokens.Palette.success : DesignTokens.Palette.danger)
            .padding(.horizontal, DesignTokens.Spacing.space16)
            .padding(.bottom, DesignTokens.Spacing.space8)
        }

        if !store.xaiService.isUsingEmbeddedDeveloperKey {
          Button("Clear Key") {
            store.clearXAIApiKey()
            connectionTestResult = nil
            Haptic.notification(.success)
          }
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.danger)
          .padding(.horizontal, DesignTokens.Spacing.space16)
          .padding(.bottom, DesignTokens.Spacing.space12)
        }
      }
    }
  }

  private var developerKeySubtitle: String {
    if store.xaiService.isUsingEmbeddedDeveloperKey {
      return "Embedded · Debug"
    }
    if hasKey {
      return "Configured · Secure"
    }
    return "Not configured"
  }

  private var hourPickerRow: some View {
    Menu {
      ForEach(7...11, id: \.self) { hour in
        Button("\(hour):00 AM") { store.morningBriefHour = hour }
      }
    } label: {
      settingsChevronRow(
        title: "Brief time",
        icon: "clock",
        value: "\(store.morningBriefHour):00 AM"
      )
    }
  }

  private var fireRadiusRow: some View {
    Menu {
      ForEach([10, 25, 50], id: \.self) { miles in
        Button("\(miles) miles") { store.fireProximityRadiusMiles = Double(miles) }
      }
    } label: {
      settingsChevronRow(
        title: "Notify within",
        icon: "circle.dashed",
        value: "\(Int(store.fireProximityRadiusMiles)) mi"
      )
    }
  }

  private var temperatureRow: some View {
    Menu {
      ForEach(TemperatureUnit.allCases) { unit in
        Button(unit.displayName) { store.temperatureUnit = unit }
      }
    } label: {
      settingsChevronRow(
        title: "Temperature",
        icon: "thermometer.medium",
        value: store.temperatureUnit.displayName
      )
    }
  }

  private func toggleRow(
    title: String,
    subtitle: String,
    icon: String,
    isOn: Binding<Bool>
  ) -> some View {
    HStack(spacing: DesignTokens.Spacing.space12) {
      Image(systemName: icon)
        .font(DesignTokens.Typography.symbol(16))
        .foregroundStyle(DesignTokens.Palette.accent)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(DesignTokens.Typography.subsection())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        Text(subtitle)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      }
      Spacer()
      Toggle("", isOn: isOn)
        .labelsHidden()
        .tint(DesignTokens.Palette.accent)
    }
    .padding(.horizontal, DesignTokens.Spacing.space16)
    .padding(.vertical, DesignTokens.Spacing.space12)
  }

  private func infoRow(title: String, value: String) -> some View {
    HStack {
      Text(title)
        .font(DesignTokens.Typography.subsection())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
      Spacer()
      Text(value)
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textSecondary)
    }
    .padding(.horizontal, DesignTokens.Spacing.space16)
    .padding(.vertical, DesignTokens.Spacing.space12)
  }

  private func settingsChevronRow(
    title: String,
    icon: String,
    value: String? = nil,
    trailing: String = "chevron.right"
  ) -> some View {
    HStack(spacing: DesignTokens.Spacing.space12) {
      Image(systemName: icon)
        .font(DesignTokens.Typography.symbol(16))
        .foregroundStyle(DesignTokens.Palette.accent)
        .frame(width: 24)
      Text(title)
        .font(DesignTokens.Typography.subsection())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
      Spacer()
      if let value {
        Text(value)
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      }
      Image(systemName: trailing)
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
    }
    .padding(.horizontal, DesignTokens.Spacing.space16)
    .padding(.vertical, DesignTokens.Spacing.space12)
    .contentShape(Rectangle())
  }

  @ViewBuilder
  private var alertNotificationStatusRow: some View {
    let status = store.alertNotificationAuthorizationStatus
    HStack(spacing: 8) {
      Image(systemName: notificationStatusIcon(for: status))
        .foregroundStyle(notificationStatusColor(for: status))
      VStack(alignment: .leading, spacing: 2) {
        Text(notificationStatusTitle(for: status))
          .font(DesignTokens.Typography.caption())
        Text(notificationStatusDetail(for: status))
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      }
      Spacer()
      if status == .denied {
        Button("Open Settings") {
          if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
          }
        }
        .font(DesignTokens.Typography.caption())
        .buttonStyle(.bordered)
      }
    }
    .padding(.vertical, 4)
  }

  private func notificationStatusIcon(for status: UNAuthorizationStatus) -> String {
    switch status {
    case .authorized, .provisional, .ephemeral: "checkmark.circle.fill"
    case .denied: "bell.slash.fill"
    case .notDetermined: "bell.badge"
    @unknown default: "bell"
    }
  }

  private func notificationStatusColor(for status: UNAuthorizationStatus) -> Color {
    switch status {
    case .authorized, .provisional, .ephemeral: DesignTokens.Palette.success
    case .denied: DesignTokens.Palette.danger
    case .notDetermined: DesignTokens.Palette.warning
    @unknown default: DesignTokens.Palette.textSecondary
    }
  }

  private func notificationStatusTitle(for status: UNAuthorizationStatus) -> String {
    switch status {
    case .authorized, .provisional, .ephemeral: "Notifications enabled"
    case .denied: "Notifications disabled in Settings"
    case .notDetermined: "Permission not requested yet"
    @unknown default: "Notification status unknown"
    }
  }

  private func notificationStatusDetail(for status: UNAuthorizationStatus) -> String {
    switch status {
    case .authorized, .provisional, .ephemeral:
      "You will receive alerts for new Warnings and Watches."
    case .denied:
      "Enable notifications in iOS Settings to receive severe weather alerts."
    case .notDetermined:
      "DayCast will ask for permission when you enable alerts."
    @unknown default:
      ""
    }
  }

  private func saveDeveloperKey() {
    let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard isValidDeveloperKeyFormat(trimmed) else { return }
    store.saveXAIApiKey(trimmed)
    isEditingKey = false
    apiKeyInput = ""
    connectionTestResult = nil
    Haptic.notification(.success)
    showSaveConfirmation = true
  }

  private func testGrokConnection() {
    guard hasKey else { return }
    isTestingConnection = true
    connectionTestResult = nil

    Task {
      do {
        let testMessages = [ChatMessage.user("Reply with exactly: 'DayCast connection OK'")]
        let response = try await store.xaiService.sendMessage(
          messages: testMessages, context: nil, feature: .connectionTest)
        isTestingConnection = false
        connectionTestSuccess = response.lowercased().contains("ok")
        connectionTestResult =
          connectionTestSuccess
          ? "Connection successful • API responded correctly"
          : "Unexpected response: \(response)"
      } catch {
        isTestingConnection = false
        connectionTestSuccess = false
        connectionTestResult = "Connection failed: \(error.localizedDescription)"
      }
    }
  }

  private func isValidDeveloperKeyFormat(_ key: String) -> Bool {
    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.hasPrefix("xai-") && trimmed.count > 25
  }
}

#Preview {
  SettingsView()
    .environment(WeatherStore())
    .environment(SubscriptionManager.shared)
    .environment(GrokBriefSafety())
}
