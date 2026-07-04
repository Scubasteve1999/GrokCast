import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
  @Environment(WeatherStore.self) private var store
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @State private var apiKeyInput: String = ""
  @State private var isEditingKey = false
  @State private var showSaveConfirmation = false
  @State private var isTestingConnection = false
  @State private var connectionTestResult: String?
  @State private var connectionTestSuccess = false

  private var hasKey: Bool {
    store.xaiService.hasValidKey
  }

  private var maskedKey: String {
    store.xaiService.maskedAPIKey
  }

  private var prefersFigmaLayout: Bool {
    horizontalSizeClass == .compact
  }

  var body: some View {
    NavigationStack {
      Group {
        if prefersFigmaLayout {
          figmaSettingsScroll
        } else {
          settingsForm
        }
      }
      .readableContentWidth(ReadableContentWidth.wide)
      .navigationTitle(prefersFigmaLayout ? "" : "Settings")
      .navigationBarTitleDisplayMode(prefersFigmaLayout ? .inline : .large)
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

  private var settingsForm: some View {
    Form {
        // MARK: - GrokCast Pro
        Section {
          if subscription.isPro {
            Label("GrokCast Pro is active", systemImage: "checkmark.seal.fill")
              .foregroundStyle(.green)
            Button("Manage Subscription") {
              if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                UIApplication.shared.open(url)
              }
            }
          } else {
            VStack(alignment: .leading, spacing: 8) {
              Text("Unlock Grok AI, forecast radar, Live Activity, and more.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
              Button("View GrokCast Pro") {
                PaywallCoordinator.shared.present(.grokAI)
              }
              .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 4)
          }

          Button("Restore Purchases") {
            Task { await subscription.restorePurchases() }
          }
          .disabled(subscription.purchaseInFlight)

          if let error = subscription.lastErrorMessage {
            Text(error)
              .font(.caption)
              .foregroundStyle(.red)
          }
        } header: {
          Text("GROKCAST PRO")
        } footer: {
          Text("Pro includes hosted Grok AI — no xAI developer key required.")
        }

        // MARK: - Grok API Configuration (Developer Key Mode)
        Section {
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Image(systemName: "key.fill")
                .foregroundStyle(.tint)
              Text("xAI Developer Key")
                .font(.headline)
              Spacer()
              Text("SECURE")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.green.opacity(0.2), in: Capsule())
                .foregroundStyle(.green)
            }

            if !isEditingKey {
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  if store.xaiService.isUsingEmbeddedDeveloperKey {
                    Text("Using embedded developer key")
                      .font(.system(.body, design: .monospaced))
                    Text("This build includes a developer key for TestFlight")
                      .font(.caption)
                      .foregroundStyle(.green)
                  } else if hasKey {
                    Text(maskedKey)
                      .font(.system(.body, design: .monospaced))
                    Text("Stored in iOS Keychain • Developer Mode")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  } else {
                    Text("No developer key configured")
                      .foregroundStyle(.secondary)
                    Text("Required for all Grok AI features (chat, vision, image generation)")
                      .font(.caption)
                      .foregroundStyle(.orange)
                  }
                }
                Spacer()
                Button(hasKey ? "Change Key" : "Add Developer Key") {
                  apiKeyInput = ""
                  isEditingKey = true
                  connectionTestResult = nil
                }
                .buttonStyle(.bordered)
              }
            } else {
              // Developer key input
              VStack(alignment: .leading, spacing: 8) {
                SecureField("xai-XXXXXXXXXXXXXXXXXXXXXXXX", text: $apiKeyInput)
                  .textInputAutocapitalization(.never)
                  .autocorrectionDisabled()
                  .font(.system(.body, design: .monospaced))
                  .padding(10)
                  .background(
                    Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

                Text("Paste your key from console.x.ai. It will be saved directly to the Keychain.")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }

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

            // Test Connection (only when we have a key)
            if hasKey && !isEditingKey {
              Divider()
              Button {
                testGrokConnection()
              } label: {
                HStack {
                  if isTestingConnection {
                    ProgressView()
                      .scaleEffect(0.8)
                    Text("Testing Grok API...")
                  } else {
                    Label("Test Grok Connection", systemImage: "network")
                  }
                }
              }
              .disabled(isTestingConnection)

              if let result = connectionTestResult {
                HStack {
                  Image(
                    systemName: connectionTestSuccess
                      ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                  )
                  .foregroundStyle(connectionTestSuccess ? .green : .red)
                  Text(result)
                    .font(.caption)
                }
                .padding(.top, 4)
              }
            }
          }
          .padding(.vertical, 4)
        } header: {
          Text("GROK API — DEVELOPER KEY")
        } footer: {
          Text(
            "Keys are stored exclusively in the iOS Keychain with the highest protection level. Never transmitted except to api.x.ai."
          )
        }

        // MARK: - Severe Weather Alert Notifications
        Section {
          Toggle(
            "Severe Weather Alerts",
            isOn: Binding(
              get: { store.alertNotificationsEnabled },
              set: { store.alertNotificationsEnabled = $0 }
            )
          )
          .onChange(of: store.alertNotificationsEnabled) { _, _ in
            Haptic.impact(.light)
          }

          if store.alertNotificationsEnabled {
            alertNotificationStatusRow
          }
        } header: {
          Text("WEATHER ALERTS")
        } footer: {
          Text(
            "Receive local notifications when new NWS Warnings or Watches are issued for your location. Alerts are also saved in the Alerts tab for offline viewing."
          )
        }

        Section {
          Toggle(
            "Hyper-Local Rain Alerts",
            isOn: Binding(
              get: { store.rainAlertsEnabled },
              set: { store.rainAlertsEnabled = $0 }
            )
          )
          .onChange(of: store.rainAlertsEnabled) { _, _ in
            Haptic.impact(.light)
          }
        } header: {
          Text("RAIN ALERTS")
        } footer: {
          Text(
            "Get notified when rain is about to start or stop at your exact location using 15-minute precipitation data."
          )
        }

        Section {
          Picker(
            "Temperature",
            selection: Binding(
              get: { store.temperatureUnit },
              set: { store.temperatureUnit = $0 }
            )
          ) {
            ForEach(TemperatureUnit.allCases) { unit in
              Text(unit.displayName).tag(unit)
            }
          }

          Toggle(
            "Live Activity",
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

          if !subscription.isPro {
            Text("Live Activity requires GrokCast Pro.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Toggle(
            "Morning Grok Brief",
            isOn: Binding(
              get: { store.morningBriefEnabled },
              set: { store.morningBriefEnabled = $0 }
            )
          )

          if store.morningBriefEnabled {
            Picker(
              "Brief time",
              selection: Binding(
                get: { store.morningBriefHour },
                set: { store.morningBriefHour = $0 }
              )
            ) {
              ForEach(7...11, id: \.self) { hour in
                Text("\(hour):00 AM").tag(hour)
              }
            }
          }

          Toggle(
            "Notification Sounds",
            isOn: Binding(
              get: { store.notificationSoundsEnabled },
              set: { store.notificationSoundsEnabled = $0 }
            )
          )
        } header: {
          Text("DISPLAY & NOTIFICATIONS")
        } footer: {
          Text(
            "Live Activity shows your GrokCast Score and Minutecast on the Lock Screen. Morning brief uses your cached Grok take when scheduled."
          )
        }

        // MARK: - Background Location (Significant Location Changes)
        Section {
          Toggle(
            "Background Weather Updates",
            isOn: Binding(
              get: { store.significantLocationUpdatesEnabled },
              set: { store.significantLocationUpdatesEnabled = $0 }
            )
          )
          .onChange(of: store.significantLocationUpdatesEnabled) { _, _ in
            Haptic.impact(.light)
          }
        } header: {
          Text("BACKGROUND UPDATES")
        } footer: {
          Text(
            "When enabled and Always location access is granted, GrokCast uses low-power Significant Location Changes to automatically refresh weather when you travel significant distances — even while the app is in the background or suspended. This is much more battery-efficient than continuous tracking. Turn off anytime to disable."
          )
        }

        // MARK: - Tools
        Section("TOOLS") {
          NavigationLink {
            TripPlannerView()
          } label: {
            Label("Trip Weather Planner", systemImage: "airplane.departure")
          }
        }

        // MARK: - App Information
        Section("APP") {
          LabeledContent("Version") {
            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
              .foregroundStyle(.secondary)
          }

          LabeledContent("Build") {
            Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
              .foregroundStyle(.secondary)
          }

          Button {
            Haptic.impact(.light)
            store.clearLocalWeatherCache()
          } label: {
            Label("Clear Local Weather Cache", systemImage: "trash")
          }
          .foregroundStyle(.red)
        }

        Section {
          Link(destination: AppLinks.privacyPolicy) {
            Label("Privacy Policy", systemImage: "hand.raised")
          }
          Link(destination: AppLinks.support) {
            Label("Support", systemImage: "questionmark.circle")
          }
          Link(destination: AppLinks.supportEmail) {
            Label("Contact", systemImage: "envelope")
          }
        } header: {
          Text("LEGAL & SUPPORT")
        }

        // MARK: - About / Links
        Section {
          Link(destination: AppLinks.xAIConsole) {
            Label("Get xAI API Key", systemImage: "link")
          }

          Link(destination: AppLinks.openMeteo) {
            Label("Weather Data: Open-Meteo", systemImage: "link")
          }

          Text("GrokCast uses free Open-Meteo for forecasts and xAI Grok models for intelligence.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } header: {
          Text("DATA & CREDITS")
        }
    }
  }

  private var figmaSettingsScroll: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        FigmaScreenTitle(title: "Settings")

        FigmaSectionLabel(title: "GROKCAST PRO")
        figmaProCard

        FigmaSectionLabel(title: "NOTIFICATIONS")
        SettingsGroupCard {
          figmaToggleRow(
            title: "Morning Brief",
            subtitle: store.morningBriefEnabled
              ? "Daily at \(store.morningBriefHour):00 AM" : "Off",
            icon: "bell.fill",
            isOn: Binding(
              get: { store.morningBriefEnabled },
              set: { store.morningBriefEnabled = $0 }
            )
          )
          SettingsDivider()
          figmaToggleRow(
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
        }

        FigmaSectionLabel(title: "DISPLAY")
        SettingsGroupCard {
          figmaPickerRow(title: "Temperature", value: store.temperatureUnit.displayName)
          SettingsDivider()
          figmaToggleRow(
            title: "Live Activity",
            subtitle: subscription.isPro ? "Lock Screen score + Minutecast" : "Requires GrokCast Pro",
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
          figmaToggleRow(
            title: "Notification Sounds",
            subtitle: store.notificationSoundsEnabled ? "On" : "Off",
            icon: "speaker.wave.2.fill",
            isOn: Binding(
              get: { store.notificationSoundsEnabled },
              set: { store.notificationSoundsEnabled = $0 }
            )
          )
        }

        FigmaSectionLabel(title: "DEVELOPER")
        SettingsGroupCard {
          figmaDeveloperKeySection
        }

        FigmaSectionLabel(title: "BACKGROUND")
        SettingsGroupCard {
          figmaToggleRow(
            title: "Background Weather Updates",
            subtitle: store.significantLocationUpdatesEnabled ? "Significant location changes" : "Off",
            icon: "location.circle.fill",
            isOn: Binding(
              get: { store.significantLocationUpdatesEnabled },
              set: { store.significantLocationUpdatesEnabled = $0 }
            )
          )
        }

        FigmaSectionLabel(title: "APP")
        SettingsGroupCard {
          figmaInfoRow(title: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
          SettingsDivider()
          figmaInfoRow(title: "Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
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
          }
          .buttonStyle(.plain)
        }

        FigmaSectionLabel(title: "LEGAL & SUPPORT")
        SettingsGroupCard {
          SettingsLinkRow(title: "Privacy Policy", icon: "hand.raised", url: AppLinks.privacyPolicy)
          SettingsDivider()
          SettingsLinkRow(title: "Support", icon: "questionmark.circle", url: AppLinks.support)
          SettingsDivider()
          SettingsLinkRow(title: "Contact", icon: "envelope", url: AppLinks.supportEmail)
        }
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.top, DesignTokens.Spacing.space16)
      .padding(.bottom, DesignTokens.Spacing.space32)
    }
    .scrollContentBackground(.hidden)
    .background(DesignTokens.Palette.bgPrimary)
  }

  private var figmaProCard: some View {
    SettingsGroupCard {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
        if subscription.isPro {
          Label("GrokCast Pro is active", systemImage: "checkmark.seal.fill")
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
          Text("Unlock Grok AI, forecast radar, Live Activity, and more.")
            .font(.system(size: 14))
            .foregroundStyle(DesignTokens.Palette.textSecondary)
            .padding(.horizontal, DesignTokens.Spacing.space16)
            .padding(.top, DesignTokens.Spacing.space16)

          Button("View GrokCast Pro") {
            PaywallCoordinator.shared.present(.grokAI)
          }
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .background(DesignTokens.Palette.accent, in: RoundedRectangle(cornerRadius: 10))
          .padding(.horizontal, DesignTokens.Spacing.space16)
        }

        Button("Restore Purchases") {
          Task { await subscription.restorePurchases() }
        }
        .font(.footnote)
        .padding(.horizontal, DesignTokens.Spacing.space16)
        .padding(.bottom, DesignTokens.Spacing.space16)
        .disabled(subscription.purchaseInFlight)

        if let error = subscription.lastErrorMessage {
          Text(error)
            .font(.caption)
            .foregroundStyle(DesignTokens.Palette.danger)
            .padding(.horizontal, DesignTokens.Spacing.space16)
            .padding(.bottom, DesignTokens.Spacing.space8)
        }
      }
    }
  }

  @ViewBuilder
  private var figmaDeveloperKeySection: some View {
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
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(DesignTokens.Palette.accent)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 2) {
            Text("xAI Developer Key")
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(DesignTokens.Palette.textPrimary)
            Text(figmaDeveloperKeySubtitle)
              .font(.system(size: 13))
              .foregroundStyle(DesignTokens.Palette.textSecondary)
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

      if isEditingKey {
        SettingsDivider()
        VStack(alignment: .leading, spacing: 8) {
          SecureField("xai-XXXXXXXXXXXXXXXXXXXXXXXX", text: $apiKeyInput)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(.body, design: .monospaced))
            .padding(10)
            .background(
              DesignTokens.Palette.cardElevated,
              in: RoundedRectangle(cornerRadius: 8)
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
      } else if hasKey && !store.xaiService.isUsingEmbeddedDeveloperKey {
        SettingsDivider()
        Button {
          testGrokConnection()
        } label: {
          HStack {
            if isTestingConnection {
              ProgressView().scaleEffect(0.8)
              Text("Testing Grok API…")
            } else {
              Label("Test Grok Connection", systemImage: "network")
            }
            Spacer()
          }
          .padding(.horizontal, DesignTokens.Spacing.space16)
          .padding(.vertical, DesignTokens.Spacing.space12)
        }
        .buttonStyle(.plain)
        .disabled(isTestingConnection)

        if let result = connectionTestResult {
          Text(result)
            .font(.caption)
            .foregroundStyle(connectionTestSuccess ? DesignTokens.Palette.success : DesignTokens.Palette.danger)
            .padding(.horizontal, DesignTokens.Spacing.space16)
            .padding(.bottom, DesignTokens.Spacing.space8)
        }
      }
    }
  }

  private var figmaDeveloperKeySubtitle: String {
    if store.xaiService.isUsingEmbeddedDeveloperKey {
      return "Embedded · TestFlight"
    }
    if hasKey {
      return "Configured · Secure"
    }
    return "Not configured"
  }

  private func figmaToggleRow(
    title: String,
    subtitle: String,
    icon: String,
    isOn: Binding<Bool>
  ) -> some View {
    HStack(spacing: DesignTokens.Spacing.space12) {
      Image(systemName: icon)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(DesignTokens.Palette.accent)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        Text(subtitle)
          .font(.system(size: 13))
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

  private func figmaPickerRow(title: String, value: String) -> some View {
    Menu {
      ForEach(TemperatureUnit.allCases) { unit in
        Button(unit.displayName) {
          store.temperatureUnit = unit
        }
      }
    } label: {
      HStack(spacing: DesignTokens.Spacing.space12) {
        Image(systemName: "thermometer.medium")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(DesignTokens.Palette.accent)
          .frame(width: 24)
        Text(title)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        Spacer()
        Text(value)
          .font(.system(size: 13))
          .foregroundStyle(DesignTokens.Palette.textSecondary)
        Image(systemName: "chevron.right")
          .font(.caption.weight(.bold))
          .foregroundStyle(DesignTokens.Palette.textTertiary)
      }
      .padding(.horizontal, DesignTokens.Spacing.space16)
      .padding(.vertical, DesignTokens.Spacing.space12)
    }
  }

  private func figmaInfoRow(title: String, value: String) -> some View {
    HStack {
      Text(title)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(DesignTokens.Palette.textPrimary)
      Spacer()
      Text(value)
        .font(.system(size: 13))
        .foregroundStyle(DesignTokens.Palette.textSecondary)
    }
    .padding(.horizontal, DesignTokens.Spacing.space16)
    .padding(.vertical, DesignTokens.Spacing.space12)
  }

  @ViewBuilder
  private var alertNotificationStatusRow: some View {
    let status = store.alertNotificationAuthorizationStatus
    HStack(spacing: 8) {
      Image(systemName: notificationStatusIcon(for: status))
        .foregroundStyle(notificationStatusColor(for: status))
      VStack(alignment: .leading, spacing: 2) {
        Text(notificationStatusTitle(for: status))
          .font(.caption.weight(.semibold))
        Text(notificationStatusDetail(for: status))
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if status == .denied {
        Button("Open Settings") {
          if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
          }
        }
        .font(.caption)
        .buttonStyle(.bordered)
      }
    }
    .padding(.vertical, 4)
  }

  private func notificationStatusIcon(for status: UNAuthorizationStatus) -> String {
    switch status {
    case .authorized, .provisional, .ephemeral:
      return "checkmark.circle.fill"
    case .denied:
      return "bell.slash.fill"
    case .notDetermined:
      return "bell.badge"
    @unknown default:
      return "bell"
    }
  }

  private func notificationStatusColor(for status: UNAuthorizationStatus) -> Color {
    switch status {
    case .authorized, .provisional, .ephemeral:
      return .green
    case .denied:
      return .red
    case .notDetermined:
      return .orange
    @unknown default:
      return .secondary
    }
  }

  private func notificationStatusTitle(for status: UNAuthorizationStatus) -> String {
    switch status {
    case .authorized, .provisional, .ephemeral:
      return "Notifications enabled"
    case .denied:
      return "Notifications disabled in Settings"
    case .notDetermined:
      return "Permission not requested yet"
    @unknown default:
      return "Notification status unknown"
    }
  }

  private func notificationStatusDetail(for status: UNAuthorizationStatus) -> String {
    switch status {
    case .authorized, .provisional, .ephemeral:
      return "You will receive alerts for new Warnings and Watches."
    case .denied:
      return "Enable notifications in iOS Settings to receive severe weather alerts."
    case .notDetermined:
      return "GrokCast will ask for permission when you enable alerts."
    @unknown default:
      return ""
    }
  }

  // MARK: - Actions

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
        // Lightweight test: ask Grok for a very short response
        let testMessages = [ChatMessage.user("Reply with exactly: 'GrokCast connection OK'")]
        let response = try await store.xaiService.sendMessage(messages: testMessages, context: nil)

        Task { @MainActor in
          isTestingConnection = false
          connectionTestSuccess = response.lowercased().contains("ok") || response.contains("OK")
          connectionTestResult =
            connectionTestSuccess
            ? "Connection successful • Grok responded correctly"
            : "Unexpected response: \(response)"
        }
      } catch {
        Task { @MainActor in
          isTestingConnection = false
          connectionTestSuccess = false
          connectionTestResult = "Connection failed: \(error.localizedDescription)"
        }
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
}
