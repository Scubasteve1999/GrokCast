import Foundation
import Security
import UserNotifications

/// Uploads this device's APNs token and notification preferences to the push agent
/// worker, so severe alerts and the morning brief can fire with the app closed.
///
/// The on-device services (`AlertNotificationService`, `MorningBriefNotificationService`)
/// only run when iOS wakes the app. This is strictly additive to them — the same
/// pattern as NWS in hard rule 6: when the worker is unconfigured or unreachable,
/// nothing is surfaced and the local path is unaffected.
///
/// Setup: `server/push-agent/README.md`.
@MainActor
final class PushRegistrationService {
  static let shared = PushRegistrationService()

  private init() {}

  /// Payload of the last successful register, so repeated syncs are free. Location
  /// and preferences are re-evaluated on nearly every refresh, and without this the
  /// app would POST on each one.
  private let fingerprintKey = "grokcast_push_registration_fingerprint"

  private var pendingSync: Task<Void, Never>?

  /// Coalescing window. Toggling several settings in a row should produce one POST,
  /// not one per switch.
  private static let debounceNanoseconds: UInt64 = 1_500_000_000

  // MARK: - Configuration

  /// True once both the worker URL and shared secret are compiled in.
  static var isConfigured: Bool {
    guard let base = GrokCastProConfig.pushAgentBaseURL, !base.isEmpty,
      let secret = GrokCastProConfig.pushAgentSharedSecret, !secret.isEmpty
    else {
      return false
    }
    return true
  }

  // MARK: - Sync

  /// Debounced entry point. Safe to call from anywhere a location or notification
  /// preference changes; unchanged payloads never hit the network.
  func scheduleSync() {
    guard Self.isConfigured else { return }

    pendingSync?.cancel()
    pendingSync = Task { [weak self] in
      try? await Task.sleep(nanoseconds: Self.debounceNanoseconds)
      guard !Task.isCancelled else { return }
      await self?.sync()
    }
  }

  /// Immediate sync. Used when the APNs token itself arrives — there is nothing to
  /// coalesce with at that point and the token is what the worker is waiting for.
  func sync() async {
    guard Self.isConfigured else { return }
    guard let token = PushNotificationService.shared.persistedAPNsToken else { return }

    let store = WeatherStore.shared

    // No permission means no deliverable push. Tear the registration down rather
    // than leaving the worker polling NWS for a device that cannot show anything.
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    let authorized =
      settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    guard authorized else {
      await unregister()
      return
    }

    guard let location = store.currentLocation else { return }

    let payload = RegistrationPayload(
      deviceId: Self.deviceID(),
      apnsToken: token,
      environment: Self.environment,
      latitude: location.latitude,
      longitude: location.longitude,
      locationName: location.name,
      timeZone: TimeZone.current.identifier,
      alertsEnabled: store.alertNotificationsEnabled,
      morningBriefEnabled: store.morningBriefEnabled,
      morningBriefHour: store.morningBriefHour,
      soundsEnabled: store.notificationSoundsEnabled,
      // `TemperatureUnit.rawValue` is already "fahrenheit"/"celsius", which is
      // exactly what the worker validates.
      temperatureUnit: store.temperatureUnit.rawValue
    )

    let encoder = JSONEncoder()
    // Stable key order, so an unchanged payload always encodes identically.
    encoder.outputFormatting = .sortedKeys
    guard let body = try? encoder.encode(payload),
      let fingerprint = String(data: body, encoding: .utf8)
    else {
      return
    }

    // The payload itself is the fingerprint. Swift's `hashValue` is seeded per
    // process, so it would miss every match across launches.
    guard fingerprint != UserDefaults.standard.string(forKey: fingerprintKey) else { return }

    if await post(path: "register", body: body) {
      UserDefaults.standard.set(fingerprint, forKey: fingerprintKey)
    }
  }

  /// Clears the server-side registration and cancels its schedules.
  func unregister() async {
    guard Self.isConfigured else { return }

    struct UnregisterPayload: Encodable { let deviceId: String }
    guard let body = try? JSONEncoder().encode(UnregisterPayload(deviceId: Self.deviceID())) else {
      return
    }

    if await post(path: "unregister", body: body) {
      UserDefaults.standard.removeObject(forKey: fingerprintKey)
    }
  }

  // MARK: - Networking

  private func post(path: String, body: Data) async -> Bool {
    guard let base = GrokCastProConfig.pushAgentBaseURL,
      let secret = GrokCastProConfig.pushAgentSharedSecret,
      let url = URL(string: "\(base)/\(path)")
    else {
      return false
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    request.timeoutInterval = 15

    do {
      let (_, response) = try await URLSession.shared.data(for: request)
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      #if DEBUG
        if status != 200 { print("[Push] \(path) failed: HTTP \(status)") }
      #endif
      return status == 200
    } catch {
      // Silent by design: a push-agent outage must never surface an error in a
      // weather app whose local notifications still work.
      #if DEBUG
        print("[Push] \(path) failed: \(error.localizedDescription)")
      #endif
      return false
    }
  }

  // MARK: - Device identity

  private struct RegistrationPayload: Encodable {
    let deviceId: String
    let apnsToken: String
    let environment: String
    let latitude: Double
    let longitude: Double
    let locationName: String
    let timeZone: String
    let alertsEnabled: Bool
    let morningBriefEnabled: Bool
    let morningBriefHour: Int
    let soundsEnabled: Bool
    let temperatureUnit: String
  }

  /// Debug builds get a sandbox APNs token; the entitlement is `production` for
  /// Release. Sending a sandbox token to the production APNs host is rejected as
  /// `BadDeviceToken`, which the worker reads as a dead token and drops.
  private static var environment: String {
    #if DEBUG
      return "sandbox"
    #else
      return "production"
    #endif
  }

  private static let keychainService = "com.grokcast.GrokCast.push"
  private static let keychainAccount = "push_device_id"

  /// Stable random id for this install, held in the Keychain.
  ///
  /// Deliberately not `identifierForVendor`: the shared secret ships in the binary
  /// and is therefore public, so this id is the only thing stopping one device from
  /// unregistering another. It has to be unguessable, not merely unique.
  static func deviceID() -> String {
    if let existing = loadDeviceID() { return existing }

    let generated = randomIdentifier()
    saveDeviceID(generated)
    return generated
  }

  private static func randomIdentifier() -> String {
    var bytes = [UInt8](repeating: 0, count: 24)
    if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
      // SecRandomCopyBytes effectively never fails, but a UUID pair is a far better
      // fallback than a fixed string if it ever does.
      return (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "")
    }
    // URL-safe base64 — the worker validates against [A-Za-z0-9_-]{16,128}.
    return Data(bytes).base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  private static func loadDeviceID() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data,
      let value = String(data: data, encoding: .utf8),
      !value.isEmpty
    else {
      return nil
    }
    return value
  }

  private static func saveDeviceID(_ value: String) {
    guard let data = value.data(using: .utf8) else { return }

    let deleteQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
    ]
    SecItemDelete(deleteQuery as CFDictionary)

    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
      kSecValueData as String: data,
      // Must survive a locked device: pushes are registered from background wakes.
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    SecItemAdd(query as CFDictionary, nil)
  }
}
