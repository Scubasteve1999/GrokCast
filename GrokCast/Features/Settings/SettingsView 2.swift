import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
  @Environment(WeatherStore.self) private var store
  @Environment(\.scenePhase) private var scenePhase

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

  var body: some View {
    NavigationStack {
      Form {
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
            // Future: clear local cache
            Haptic.impact(.light)
          } label: {
            Label("Clear Local Weather Cache", systemImage: "trash")
          }
          .foregroundStyle(.red)
        }

        // MARK: - About / Links
        Section {
          Link(destination: URL(string: "https://console.x.ai/")!) {
            Label("Get xAI API Key", systemImage: "link")
          }

          Link(destination: URL(string: "https://open-meteo.com/")!) {
            Label("Weather Data: Open-Meteo", systemImage: "link")
          }

          Text("GrokCast uses free Open-Meteo for forecasts and xAI Grok models for intelligence.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } header: {
          Text("DATA & CREDITS")
        }
      }
      .readableContentWidth(ReadableContentWidth.wide)
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.large)
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
