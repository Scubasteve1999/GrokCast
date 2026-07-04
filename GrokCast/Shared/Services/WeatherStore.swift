import CoreLocation
import Foundation
import Network
import SwiftUI
import UserNotifications
import WidgetKit

/// Lightweight connectivity monitor (NWPathMonitor) for proactive offline detection.
/// Exposed via WeatherStore.isOffline so views can show wifi.slash + specific messaging
/// without duplicating monitor code. Started on store init (app lifetime).
@Observable
final class NetworkMonitor {
  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "com.grokcast.networkmonitor")
  var isConnected = true

  init() {
    monitor.pathUpdateHandler = { [weak self] path in
      // Adopt Swift Concurrency for the UI-visible isConnected update (removes manual Dispatch).
      Task { @MainActor [weak self] in
        self?.isConnected = (path.status == .satisfied)
      }
    }
    monitor.start(queue: queue)
  }

  deinit {
    monitor.cancel()
  }
}

@MainActor
@Observable
final class WeatherStore {
  public static let shared = WeatherStore()

  var currentLocation: SavedLocation?
  var currentWeather: GrokCastWeather?
  var savedLocations: [SavedLocation] = []
  var isLoadingWeather = false
  var weatherError: String?

  var selectedTab: Tab = .today

  // Connectivity for offline-aware error UI (banner uses wifi.slash icon + specific copy).
  private let networkMonitor = NetworkMonitor()
  var isOffline: Bool { !networkMonitor.isConnected }

  /// Persisted flag tracking whether the first-launch permission explanation flow has been seen.
  /// Set (and persisted) when the user taps Get Started (or any explicit "use my position" / ENABLE path).
  /// Auto-set in init for prior users (status != .notDetermined) so they never re-see the explanation.
  /// When false on a true first launch (with .notDetermined), Today shows the welcome + explanation sheet.
  var hasRequestedLocationPermission: Bool = false

  private let significantLocationUpdatesEnabledKey = "grokcast_significant_location_updates_enabled"
  private var _significantLocationUpdatesEnabled = true

  /// User-controlled preference for Significant Location Changes (background low-power updates).
  /// Default true so the feature activates for users who have granted Always authorization.
  /// Controlled by toggle in Settings; when true + Always auth, monitoring is active.
  var significantLocationUpdatesEnabled: Bool {
    get { _significantLocationUpdatesEnabled }
    set {
      guard newValue != _significantLocationUpdatesEnabled else { return }
      _significantLocationUpdatesEnabled = newValue
      UserDefaults.standard.set(newValue, forKey: significantLocationUpdatesEnabledKey)
      applySignificantLocationPreference()
    }
  }

  private let temperatureUnitKey = "grokcast_temperature_unit"
  private var _temperatureUnit: TemperatureUnit = .fahrenheit

  /// Display and Open-Meteo fetch units (°F/mph vs °C/km/h).
  var temperatureUnit: TemperatureUnit {
    get { _temperatureUnit }
    set {
      guard newValue != _temperatureUnit else { return }
      _temperatureUnit = newValue
      UserDefaults.standard.set(newValue.rawValue, forKey: temperatureUnitKey)
      Task { await refreshWeather() }
    }
  }

  private let liveActivityEnabledKey = "grokcast_live_activity_enabled"
  private var _liveActivityEnabled = false

  /// Live Activity on Lock Screen / Dynamic Island (score + minutecast).
  var liveActivityEnabled: Bool {
    get { _liveActivityEnabled }
    set {
      guard newValue != _liveActivityEnabled else { return }
      _liveActivityEnabled = newValue
      UserDefaults.standard.set(newValue, forKey: liveActivityEnabledKey)
      if newValue {
        syncScoreSurfacesFromCurrentWeather()
      } else {
        WeatherLiveActivityManager.end()
      }
    }
  }

  private var _morningBriefEnabled = MorningBriefNotificationService.persistedEnabled
  private var _morningBriefHour = MorningBriefNotificationService.persistedHour

  var morningBriefEnabled: Bool {
    get { _morningBriefEnabled }
    set {
      guard newValue != _morningBriefEnabled else { return }
      _morningBriefEnabled = newValue
      UserDefaults.standard.set(newValue, forKey: MorningBriefNotificationService.enabledKey)
      if newValue {
        Task {
          await MorningBriefGenerator.generateIfStale(weatherStore: self)
        }
      } else {
        MorningBriefNotificationService.cancel()
      }
    }
  }

  /// Local notification hour (7–11) for the cached Grok morning brief.
  var morningBriefHour: Int {
    get { _morningBriefHour }
    set {
      let clamped = min(11, max(7, newValue))
      guard clamped != _morningBriefHour else { return }
      _morningBriefHour = clamped
      UserDefaults.standard.set(clamped, forKey: MorningBriefNotificationService.hourKey)
      Task { await syncMorningBriefNotification(briefBody: cachedGrokBriefOneLiner()) }
    }
  }

  private var _notificationSoundsEnabled = GrokCastNotificationSounds.isEnabled

  var notificationSoundsEnabled: Bool {
    get { _notificationSoundsEnabled }
    set {
      guard newValue != _notificationSoundsEnabled else { return }
      _notificationSoundsEnabled = newValue
      UserDefaults.standard.set(newValue, forKey: GrokCastNotificationSounds.enabledKey)
      Task { await syncMorningBriefNotification(briefBody: cachedGrokBriefOneLiner()) }
    }
  }

  func formatTemperature(_ value: Double) -> String {
    temperatureUnit.format(value)
  }

  func formatTemperatureShort(_ value: Double) -> String {
    temperatureUnit.formatShort(value)
  }

  func formatWindSpeed(_ value: Double) -> String {
    temperatureUnit.formatWind(value)
  }

  enum Tab: String, CaseIterable, Identifiable {
    case today = "Today"
    case forecast = "Forecast"
    case radar = "Radar"
    case alerts = "Alerts"
    case grok = "Grok AI"
    case locations = "Locations"
    case settings = "Settings"

    var id: String { rawValue }
    var icon: String {
      switch self {
      case .today: "sun.max"
      case .forecast: "calendar"
      case .radar: "map.fill"
      case .alerts: "bell.badge.fill"
      case .grok: "sparkles"
      case .locations: "mappin.and.ellipse"
      case .settings: "gearshape"
      }
    }
  }

  let locationService = LocationService()
  private let openMeteo = OpenMeteoService()
  private let nwsService = NWSService()

  /// Secure Grok/xAI API configuration (developer key mode)
  let grokConfig = GrokAPIConfiguration(mode: .developerKey)
  let xaiService: XAIService
  /// Grok Build service (powers Grok AI chat via grok-3-mini + key fallback; named for historical multi-key support).
  /// Uses its own Keychain slot (.grokBuild) via the multi-key support added in KeychainService.
  /// It creates its own dedicated URLSession (not .shared) tuned for long-lived SSE streaming;
  /// this reduces certain low-level nw_connection diagnostic logs and avoids affecting the
  /// shared session used by weather/radar/NWS fetches.
  let grokBuildService = GrokBuildService()
  let openWeatherMapService = OpenWeatherMapService()
  private let keychain = KeychainService.shared

  private let savedLocationsKey = "grokcast_saved_locations"
  private let hasRequestedLocationPermissionKey = "grokcast_has_requested_location_permission"

  // NWS: primary for GrokCastWeather via grid (--primary-source --grid-system); alerts/obs remain additive hybrid US-only non-fatal
  var activeAlerts: [NWSAlert] = []
  var alertHistory: [NWSAlert] = []
  private var lastAlertsFetch: Date?
  private var alertsForLocation: UUID?
  /// True when the most recent alerts fetch for the current location succeeded authoritatively.
  private var lastAlertsFetchSucceeded = false

  nonisolated static let alertNotificationsEnabledKey = "grokcast_alert_notifications_enabled"

  /// Synchronous read of persisted alert notification preference (scheduling from any thread).
  nonisolated static var persistedAlertNotificationsEnabled: Bool {
    if UserDefaults.standard.object(forKey: alertNotificationsEnabledKey) == nil {
      return true
    }
    return UserDefaults.standard.bool(forKey: alertNotificationsEnabledKey)
  }

  private var _alertNotificationsEnabled = true

  /// User-controlled preference for local severe weather alert notifications.
  var alertNotificationsEnabled: Bool {
    get { _alertNotificationsEnabled }
    set {
      guard newValue != _alertNotificationsEnabled else { return }
      _alertNotificationsEnabled = newValue
      UserDefaults.standard.set(newValue, forKey: Self.alertNotificationsEnabledKey)
      if newValue {
        Task { await scheduleBackgroundAlertRefreshIfEnabled() }
      } else {
        BackgroundAlertRefreshService.cancelAlertRefreshTask()
      }
    }
  }

  /// Mirrors UNUserNotificationCenter authorization (refreshed on appear / toggle).
  var alertNotificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined

  var currentNWSObservation: NWSObservation?
  private var lastObservationFetch: Date?
  private var observationForLocation: UUID?

  /// Additive hybrid layer from OpenWeatherMap (current + 3-hour forecast). Open-Meteo remains primary.
  var currentOpenWeatherMapWeather: OpenWeatherMapCurrentWeather?
  var openWeatherMapForecast: OpenWeatherMapForecast?
  private var lastOpenWeatherMapFetch: Date?
  private var openWeatherMapForLocation: UUID?

  /// Used to debounce full refreshes triggered by significant location updates
  /// (the system often delivers an initial update shortly after starting monitoring,
  /// which can race with the MainTabView .task initial load).
  private var lastSignificantRefreshDate: Date?

  /// True once the cold-launch initial weather/NWS load has finished (MainTabView .task).
  /// Significant location updates still update the saved location entry before this,
  /// but skip the weather/NWS refresh trio until initial load completes.
  private(set) var hasCompletedInitialLoad = false

  /// Coalesces concurrent cold-launch initial load callers (e.g. racing .task vs sig delivery).
  private var initialLoadTask: Task<Void, Never>?

  /// Shared Grok AI view model — survives tab switches so in-flight streams and history persist.
  private var _grokAIViewModel: GrokAIViewModel?
  var grokAIViewModel: GrokAIViewModel {
    if let _grokAIViewModel { return _grokAIViewModel }
    let vm = GrokAIViewModel(weatherStore: self)
    _grokAIViewModel = vm
    return vm
  }

  /// Performs the one-time cold-launch initial load (weather + NWS observation if missing).
  /// Safe to call from multiple concurrent contexts — only the first caller runs fetches.
  func performInitialLoadIfNeeded() async {
    if hasCompletedInitialLoad { return }

    // Coalescing: assign initialLoadTask before awaiting so a second concurrent caller
    // sees the in-flight task and awaits .value instead of starting duplicate fetches.
    if let existing = initialLoadTask {
      await existing.value
      return
    }

    let task = Task<Void, Never> { @MainActor in
      if self.currentWeather == nil {
        await self.refreshWeather()
      } else {
        // Stale-while-revalidate: cached snapshot already on screen; refresh quietly.
        Task { await self.refreshWeather() }
      }

      // Intentional: mark complete even on fetch failure so sig-handler refreshes are not
      // blocked forever on launch; user can tap RETRY for manual recovery.
      self.hasCompletedInitialLoad = true
      self.lastSignificantRefreshDate = Date()
      self.initialLoadTask = nil
    }

    initialLoadTask = task
    await task.value
  }

  init() {
    // Initialize XAIService with the secure developer-key configuration
    self.xaiService = XAIService(configuration: grokConfig)

    WidgetDataStore.migrateLegacySavedLocationsIfNeeded()
    WidgetDataStore.migrateLegacySnapshotIfNeeded()
    loadSavedLocations()
    // Default to Olive Branch, MS (tactical Mississippi location)
    if savedLocations.isEmpty {
      savedLocations = [SavedLocation.oliveBranch]
    }
    currentLocation = savedLocations.first
    hydrateCachedWeatherIfNeeded()

    // Load + auto-complete first-launch flag for prior users (any non-.notDetermined status means
    // they have seen a permission prompt before). Only pure new installs (never prompted) see the
    // polished welcome + pre-explanation sheet on first launch.
    hasRequestedLocationPermission = UserDefaults.standard.bool(
      forKey: hasRequestedLocationPermissionKey)
    if locationService.authorizationStatus != .notDetermined {
      if !hasRequestedLocationPermission {
        hasRequestedLocationPermission = true
        UserDefaults.standard.set(true, forKey: hasRequestedLocationPermissionKey)
      }
    }

    // Load significant location updates pref. Default true so the feature is active for users
    // who have granted Always (the toggle in Settings gives explicit control to turn it off).
    if UserDefaults.standard.object(forKey: significantLocationUpdatesEnabledKey) == nil {
      _significantLocationUpdatesEnabled = true
      UserDefaults.standard.set(true, forKey: significantLocationUpdatesEnabledKey)
    } else {
      _significantLocationUpdatesEnabled = UserDefaults.standard.bool(
        forKey: significantLocationUpdatesEnabledKey)
    }

    // Wire handler so significant updates (background) can keep the Current Location entry
    // and weather reasonably fresh.
    locationService.significantLocationHandler = { [weak self] clLoc in
      Task { @MainActor [weak self] in
        await self?.handleSignificantLocationUpdate(clLoc)
      }
    }

    applySignificantLocationPreference()

    alertHistory = AlertHistoryStore.loadHistory()
    if UserDefaults.standard.object(forKey: Self.alertNotificationsEnabledKey) == nil {
      _alertNotificationsEnabled = true
      UserDefaults.standard.set(true, forKey: Self.alertNotificationsEnabledKey)
    } else {
      _alertNotificationsEnabled = UserDefaults.standard.bool(
        forKey: Self.alertNotificationsEnabledKey)
    }

    Task { @MainActor in
      await refreshAlertNotificationAuthorizationStatus()
    }

    if let rawUnit = UserDefaults.standard.string(forKey: temperatureUnitKey),
      let unit = TemperatureUnit(rawValue: rawUnit)
    {
      _temperatureUnit = unit
    }

    if UserDefaults.standard.object(forKey: liveActivityEnabledKey) != nil {
      _liveActivityEnabled = UserDefaults.standard.bool(forKey: liveActivityEnabledKey)
    }

    _morningBriefEnabled = MorningBriefNotificationService.persistedEnabled
    _morningBriefHour = MorningBriefNotificationService.persistedHour
    _notificationSoundsEnabled = GrokCastNotificationSounds.isEnabled

    // Do NOT auto-request device location on every cold launch.
    // This avoids immediate location permission prompts and reduces work
    // that contributes to ExtendedLaunchMetrics noise.
    //
    // "My location" is updated only on explicit user action via the
    // "Use my position" buttons (in TodayView, LocationsView, etc.).
    // Those paths call useCurrentDeviceLocation(), which updates the
    // isCurrent entry, sets it as current, and refreshes weather + NWS alerts.
    //
    // The starting location is whatever was last saved (defaults to
    // Olive Branch, MS). The MainTabView .task will lazily refresh
    // weather for it if needed.
  }

  func loadSavedLocations() {
    let decoded: [SavedLocation]?
    let groupLocations = WidgetDataStore.loadLocations()
    if !groupLocations.isEmpty {
      decoded = groupLocations
    } else if let legacyData = UserDefaults.standard.data(forKey: savedLocationsKey),
      let legacyLocations = try? JSONDecoder().decode([SavedLocation].self, from: legacyData)
    {
      decoded = legacyLocations
      WidgetDataStore.saveLocations(legacyLocations)
    } else {
      decoded = nil
    }

    if let decoded {
      savedLocations = decoded

      // One-time deduplication for historical duplicates (e.g. same coords appearing
      // as both isCurrent and non-isCurrent from previous "always on launch" behavior).
      // Keeps at most one entry per ~0.01° coordinate cluster, preferring the isCurrent one.
      var deduped: [SavedLocation] = []
      var keyToIndex: [String: Int] = [:]

      for loc in savedLocations {
        let key = "\(Int(loc.latitude * 100))_\(Int(loc.longitude * 100))"
        if let existingIdx = keyToIndex[key] {
          // Duplicate coords: keep the isCurrent version if this one is current
          if loc.isCurrent && !deduped[existingIdx].isCurrent {
            deduped[existingIdx] = loc
          }
        } else {
          keyToIndex[key] = deduped.count
          deduped.append(loc)
        }
      }

      // Ensure only one isCurrent flag is set (in case of older data)
      var foundCurrent = false
      for i in deduped.indices {
        if deduped[i].isCurrent {
          if foundCurrent {
            var copy = deduped[i]
            copy.isCurrent = false
            deduped[i] = copy
          } else {
            foundCurrent = true
          }
        }
      }

      savedLocations = deduped
      if !savedLocations.isEmpty {
        saveLocations()  // persist the cleaned list
      }
    }
  }

  func saveLocations() {
    if let data = try? JSONEncoder().encode(savedLocations) {
      UserDefaults.standard.set(data, forKey: savedLocationsKey)
      WidgetDataStore.saveLocations(savedLocations)
    }
  }

  /// Persists a widget-readable weather snapshot after a successful refresh.
  private func persistWidgetSnapshot(
    from weather: GrokCastWeather,
    score: GrokCastScore? = nil,
    minutecast: MinutecastSummary? = nil,
    grokBriefOneLiner: String? = nil
  ) {
    let computedScore =
      score
      ?? GrokCastScoreCalculator.score(
        for: weather, alerts: activeAlerts, units: temperatureUnit)
    let computedMinutecast =
      minutecast
      ?? MinutecastEngine.summary(from: weather.minutely15, units: temperatureUnit)
    let brief: String?
    if EntitlementChecker.canUseWidgetGrokBrief(subscription: SubscriptionManager.shared) {
      brief =
        grokBriefOneLiner
        ?? WidgetDataStore.loadSnapshot(for: weather.location.id)?.grokBriefOneLiner
    } else {
      brief = nil
    }

    WidgetDataStore.saveSnapshot(
      WidgetWeatherSnapshot(
        weather: weather,
        grokCastScore: computedScore.value,
        grokCastScoreLabel: computedScore.label,
        minutecastMessage: computedMinutecast.message,
        grokBriefOneLiner: brief
      ))
    WidgetTimelineReloader.requestReload()
  }

  /// Keeps widget score/minutecast, Live Activity, and optional Grok one-liner in sync.
  func syncScoreSurfacesFromCurrentWeather(grokBriefOneLiner: String? = nil) {
    guard let weather = currentWeather else { return }
    let score = GrokCastScoreCalculator.score(
      for: weather, alerts: activeAlerts, units: temperatureUnit)
    let minutecast = MinutecastEngine.summary(
      from: weather.minutely15, units: temperatureUnit)
    persistWidgetSnapshot(
      from: weather,
      score: score,
      minutecast: minutecast,
      grokBriefOneLiner: grokBriefOneLiner
    )

    guard liveActivityEnabled, EntitlementChecker.canUseLiveActivity(subscription: SubscriptionManager.shared),
      let name = currentLocation?.name
    else {
      if !liveActivityEnabled || !EntitlementChecker.canUseLiveActivity(subscription: SubscriptionManager.shared) {
        WeatherLiveActivityManager.end()
      }
      return
    }

    WeatherLiveActivityManager.sync(
      weather: weather,
      score: score,
      minutecast: minutecast,
      locationName: name,
      temperatureText: formatTemperatureShort(weather.currentTemp),
      enabled: liveActivityEnabled
    )
  }

  /// Updates the widget Grok one-liner after the Today brief is fetched.
  func refreshWidgetSnapshotGrokBrief() {
    syncScoreSurfacesFromCurrentWeather(grokBriefOneLiner: cachedGrokBriefOneLiner())
  }

  func syncMorningBriefNotification(briefBody: String?) async {
    await MorningBriefNotificationService.scheduleIfEnabled(briefBody: briefBody)
  }

  private func cachedGrokBriefOneLiner() -> String? {
    guard let loc = currentLocation else { return nil }
    let day = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
    let key = "grok_brief_\(loc.id.uuidString)_\(Int(day))"
    return UserDefaults.standard.string(forKey: key).map { String($0.prefix(120)) }
  }

  /// Hydrates `currentWeather` from the App Group widget snapshot so cold launch can show
  /// last-known data immediately (stale-while-revalidate) instead of skeleton shimmer.
  private func hydrateCachedWeatherIfNeeded() {
    guard currentWeather == nil, let loc = currentLocation else { return }
    guard let snapshot = WidgetDataStore.loadSnapshot(for: loc.id) else { return }
    currentWeather = GrokCastWeather(snapshot: snapshot)
  }

  /// Persists a lightweight alert summary for widgets after a successful NWS fetch.
  private func persistWidgetAlertSummary(for location: SavedLocation, alerts: [NWSAlert]) {
    let active = alerts.filter { !$0.isExpired }
    let summary: WidgetAlertSummary?
    if active.isEmpty {
      summary = nil
    } else {
      let top = active.max(by: { $0.severityLevel < $1.severityLevel }) ?? active[0]
      let latestExpiry = active.compactMap(\.expires).max()
      summary = WidgetAlertSummary(
        locationID: location.id,
        topEvent: top.event,
        topSeverityLevel: top.severityLevel,
        topIsWarning: top.isWarning,
        topIsWatch: top.isWatch,
        activeCount: active.count,
        topExpires: top.expires,
        anyActiveUntil: latestExpiry
      )
    }
    WidgetDataStore.saveAlertSummary(summary, for: location.id)
    WidgetTimelineReloader.requestReload()
  }

  /// Marks that the first-launch permission explanation flow has been completed (persisted).
  /// Called from the welcome "Get Started", explanation "Continue", useCurrentDeviceLocation, and ENABLE button.
  /// Subsequent launches (or any explicit location request) will skip the explanation and go straight to weather (or the appropriate auth UI).
  func markLocationPermissionRequested() {
    hasRequestedLocationPermission = true
    UserDefaults.standard.set(true, forKey: hasRequestedLocationPermissionKey)
  }

  /// Back-compat forwarding helper (used by existing call sites during the rename transition).
  /// Prefer markLocationPermissionRequested going forward.
  func markFirstLaunchCompleted() {
    markLocationPermissionRequested()
  }

  private func applySignificantLocationPreference() {
    if significantLocationUpdatesEnabled {
      let status = locationService.authorizationStatus
      if status == .authorizedAlways || status == .authorizedWhenInUse {
        MainActor.assumeIsolated {
          locationService.startSignificantLocationChanges()
        }
      }
    } else {
      MainActor.assumeIsolated {
        locationService.stopSignificantLocationChanges()
      }
    }
  }

  @MainActor
  private func handleSignificantLocationUpdate(_ clLoc: CLLocation) async {
    guard significantLocationUpdatesEnabled else { return }

    // significant location update received (diag removed for release)

    let name = await locationService.reverseGeocode(clLoc) ?? "Current Location"
    updateCurrentDeviceLocationEntry(using: clLoc, name: name)

    // Keep the viewed weather on the user's selected location. Only update/refresh
    // if they are currently looking at their "Current Location" (do not hijack a
    // manually selected fixed saved city).
    if currentLocation?.isCurrent == true {
      currentLocation = savedLocations.first(where: { $0.isCurrent }) ?? currentLocation

      // Cold launch: iOS often delivers an initial sig update before MainTabView .task runs.
      // Location entry is updated above; defer weather/NWS until performInitialLoadIfNeeded finishes.
      guard hasCompletedInitialLoad else {
        return
      }

      // Debounce to avoid redundant full refreshes on rapid successive deliveries.
      // Subsequent real movements will still trigger because enough time will have passed.
      let now = Date()
      if let last = lastSignificantRefreshDate, now.timeIntervalSince(last) < 45 {
        lastSignificantRefreshDate = now
        return
      }
      lastSignificantRefreshDate = now

      async let w = refreshWeather()
      async let a = refreshAlerts()
      async let o = refreshNWSObservation()
      async let owm = refreshOpenWeatherMap()
      _ = await (w, a, o, owm)
    }
  }

  @MainActor
  private func updateCurrentDeviceLocationEntry(using clLoc: CLLocation, name: String) {
    // Clear isCurrent flags (exact logic extracted from useCurrentDeviceLocation success path)
    for i in savedLocations.indices {
      if savedLocations[i].isCurrent {
        var copy = savedLocations[i]
        copy.isCurrent = false
        savedLocations[i] = copy
      }
    }

    let targetLat = clLoc.coordinate.latitude
    let targetLon = clLoc.coordinate.longitude

    if let idx = savedLocations.firstIndex(where: {
      abs($0.latitude - targetLat) < 0.01 && abs($0.longitude - targetLon) < 0.01
    }) {
      var existing = savedLocations[idx]
      existing.name = name
      existing.latitude = targetLat
      existing.longitude = targetLon
      existing.isCurrent = true
      savedLocations[idx] = existing
    } else {
      let newCurrent = SavedLocation(
        name: name, latitude: targetLat, longitude: targetLon, isCurrent: true)
      savedLocations.insert(newCurrent, at: 0)
    }
    saveLocations()
  }

  func selectLocation(_ location: SavedLocation) {
    currentLocation = location
    // Structured concurrency: independent NWS fetches (alerts + obs) now overlap with weather.
    Task {
      async let _ = refreshWeather()
      async let _ = refreshAlerts()
      async let _ = refreshNWSObservation()
      async let _ = refreshOpenWeatherMap()
    }
  }

  private enum WeatherFetchResult {
    case success(GrokCastWeather)
    case failure(Error)
    case timedOut
  }

  /// Caps slow Open-Meteo responses so cold launch doesn't sit on skeleton shimmer indefinitely.
  private func fetchPrimaryWeather(for location: SavedLocation) async -> WeatherFetchResult {
    await withTaskGroup(of: WeatherFetchResult.self) { group in
      group.addTask {
        do {
          let data = try await self.openMeteo.fetchForecast(
            for: location, units: self.temperatureUnit)
          return .success(data)
        } catch {
          return .failure(error)
        }
      }
      group.addTask {
        try? await Task.sleep(nanoseconds: 8_000_000_000)
        return .timedOut
      }
      let first = await group.next() ?? .timedOut
      group.cancelAll()
      return first
    }
  }

  /// NWS fallback with the same 8s cap so a slow grid lookup can't block launch.
  private func fetchNWSFallback(for location: SavedLocation) async -> WeatherFetchResult {
    await withTaskGroup(of: WeatherFetchResult.self) { group in
      group.addTask {
        do {
          let data = try await self.nwsService.fetchForecast(for: location)
          return .success(data)
        } catch {
          return .failure(error)
        }
      }
      group.addTask {
        try? await Task.sleep(nanoseconds: 8_000_000_000)
        return .timedOut
      }
      let first = await group.next() ?? .timedOut
      group.cancelAll()
      return first
    }
  }

  @MainActor
  func refreshWeather() async {
    guard let loc = currentLocation else { return }
    let showLoadingIndicator = currentWeather == nil
    if showLoadingIndicator {
      isLoadingWeather = true
    }
    weatherError = nil

    do {
      // Primary: OpenMeteo for accurate numeric weather_code + real precipitation_probability (no fake 40% or text heuristics).
      // NWS fallback only (for non-US or rare OpenMeteo outage). NWS is still used for alerts + station observations.
      let data: GrokCastWeather
      switch await fetchPrimaryWeather(for: loc) {
      case .success(let forecast):
        data = forecast
      case .timedOut, .failure:
        switch await fetchNWSFallback(for: loc) {
        case .success(let forecast):
          data = forecast
        case .timedOut:
          throw URLError(.timedOut)
        case .failure(let error):
          throw error
        }
      }
      currentWeather = data
      syncScoreSurfacesFromCurrentWeather()
      // TODO: Cache to SwiftData here

      // Fire-and-forget NWS + OpenWeatherMap hybrid refresh (additive, non-fatal).
      Task {
        async let alerts = refreshAlerts()
        async let nws = refreshNWSObservation()
        async let owm = refreshOpenWeatherMap()
        async let brief: () = MorningBriefGenerator.generateIfStale(weatherStore: self)
        _ = await (alerts, nws, owm, brief)
      }
    } catch {
      // Keep showing cached weather on refresh failure; only surface errors when nothing to display.
      if currentWeather == nil {
        weatherError =
          isOffline
          ? "No internet connection. Check your Wi-Fi or cellular and tap RETRY."
          : OpenMeteoService.userFriendlyMessage(for: error)
      }
    }
    if showLoadingIndicator {
      isLoadingWeather = false
    }
  }

  /// Convenience to force refresh for a specific location (used by Storm Spotter for reliable "my location" data).
  /// Also refreshes NWS alerts + nearest station observation so analyses get full hybrid context.
  @MainActor
  func refreshWeather(for location: SavedLocation) async {
    currentLocation = location
    // Parallel refreshes for the three independent data sources.
    async let w = refreshWeather()
    async let a = refreshAlerts()
    async let o = refreshNWSObservation()
    async let owm = refreshOpenWeatherMap()
    _ = await (w, a, o, owm)
  }

  /// Explicitly updates (or creates) the "Current Location" entry using the device's
  /// GPS, marks it isCurrent=true, makes it the active currentLocation, and
  /// refreshes Open-Meteo weather + NWS alerts + nearest station observation for it.
  ///
  /// This is the only path that triggers a fresh device location request.
  /// Called from UI buttons ("Use my position") and from Storm Spotter flows
  /// when they want the most accurate "my location" data.
  @MainActor
  func useCurrentDeviceLocation() async {
    markLocationPermissionRequested()
    let status = locationService.authorizationStatus
    if status == .denied || status == .restricted {
      weatherError =
        isOffline
        ? "No internet connection. Check your Wi-Fi or cellular and tap RETRY."
        : "Location access was denied. Enable it in Settings to use your current position for weather and insights."
      return
    }

    locationService.requestLocationPermission()

    do {
      let clLoc = try await locationService.requestLocation()
      let name = await locationService.reverseGeocode(clLoc) ?? "Current Location"

      updateCurrentDeviceLocationEntry(using: clLoc, name: name)

      // Set currentLocation to the (now unique) isCurrent entry, or fall back
      currentLocation = savedLocations.first(where: { $0.isCurrent }) ?? savedLocations.first
      // Parallel refreshes (structured concurrency for independent calls).
      async let w = refreshWeather()
      async let a = refreshAlerts()
      async let o = refreshNWSObservation()
      async let owm = refreshOpenWeatherMap()
      _ = await (w, a, o, owm)

      lastSignificantRefreshDate = Date()  // mark fresh so a near-term sig delivery doesn't re-fetch
    } catch {
      let locError =
        isOffline
        ? "No internet connection. Check your Wi-Fi or cellular and tap RETRY."
        : "Could not get your location: \(OpenMeteoService.userFriendlyMessage(for: error))"
      weatherError = locError
      // Fallback to default (Olive Branch, MS) so we don't stay stuck on NO SIGNAL.
      // This ensures the user sees usable weather data even if GPS fails (common on sim).
      await fallbackToDefaultLocationWeather()
      // If the default load also failed (transient), prefer keeping the original location context
      // rather than overwriting with a generic service error. RETRY will re-attempt everything.
      if currentWeather == nil {
        weatherError = locError
      }
    }
  }

  /// Ensures we have a usable default location (Olive Branch, MS) set as currentLocation
  /// and loads its weather forecast. Used as recovery when GPS "use my position" fails
  /// (e.g. simulator without location fix) so the user isn't left stuck in NO SIGNAL.
  @MainActor
  func fallbackToDefaultLocationWeather() async {
    // Find existing default by coords (stable even if persisted with different id)
    if let existingDefault = savedLocations.first(where: {
      abs($0.latitude - 34.9618) < 0.01 && abs($0.longitude + 89.8295) < 0.01
    }) {
      currentLocation = existingDefault
    } else {
      // Add the canonical default (has stable id)
      let def = SavedLocation.oliveBranch
      savedLocations.append(def)
      saveLocations()
      currentLocation = def
    }

    // Falling back to default location (log removed for release)

    // Always (re)load the weather for it. This is what transitions out of NO SIGNAL
    // once currentWeather becomes non-nil.
    await refreshWeather()

    // Retry once on transient server/timeout errors for default (common in simulator; 502s, timeouts etc.)
    if let err = weatherError,
      err.contains("timed out") || err.contains("timeout") || err.contains("timedOut")
        || err.contains("unavailable") || err.contains("server error")
        || err.contains("Bad Gateway")
        || err.contains("502")
    {
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      weatherError = nil
      isLoadingWeather = true  // ensure loading state for UI
      await refreshWeather()
    }

    // Parallel for additive hybrid calls (recovery path).
    async let a = refreshAlerts()
    async let o = refreshNWSObservation()
    async let owm = refreshOpenWeatherMap()
    _ = await (a, o, owm)
  }

  // MARK: - NWS Alerts + Observations (hybrid, additive to Open-Meteo)

  @MainActor
  func refreshAlerts(force: Bool = false) async {
    guard let loc = currentLocation else { return }

    // 5-minute (300s) in-memory cache per location (per spec: 5-10 min)
    if !force,
      let last = lastAlertsFetch,
      let cachedLocId = alertsForLocation,
      cachedLocId == loc.id,
      Date().timeIntervalSince(last) < 300
    {
      return
    }

    do {
      let alerts = try await nwsService.fetchActiveAlerts(for: loc)
      activeAlerts = alerts
      alertHistory = AlertHistoryStore.merge(fetched: alerts, into: alertHistory)
      AlertHistoryStore.saveHistory(alertHistory)
      lastAlertsFetch = Date()
      alertsForLocation = loc.id
      lastAlertsFetchSucceeded = true
      persistWidgetAlertSummary(for: loc, alerts: alerts)
      syncScoreSurfacesFromCurrentWeather()
      await AlertNotificationService.shared.notifyIfNeeded(
        for: alerts,
        enabled: alertNotificationsEnabled
      )
    } catch is CancellationError {
      // foreground-alerts fetch cancelled (log removed)
    } catch {
      // Non-fatal: retain last-known active alerts so offline UI stays accurate.
      // Only a successful fetch with an empty list authoritatively clears activeAlerts.
      lastAlertsFetchSucceeded = false
      // foreground-alerts fetch failed (log removed for release)
    }
  }

  /// Non-expired alerts for UI display. Falls back to persisted history only when the last
  /// fetch failed (offline); returns [] after a successful fetch that found no active alerts.
  var displayableActiveAlerts: [NWSAlert] {
    let fromActive = activeAlerts.filter { !$0.isExpired }
    if !fromActive.isEmpty { return fromActive }
    guard !lastAlertsFetchSucceeded else { return [] }
    return alertHistory.filter { !$0.isExpired }
  }

  /// Background entry point for BGAppRefreshTask — uses persisted saved locations.
  ///
  /// v1 limitation: only the current/preferred location is checked (isCurrent preferred, else first
  /// saved). This keeps background work lightweight and within BGTask time budgets. Multi-location
  /// background polling can be added later if user demand warrants it.
  @MainActor
  @discardableResult
  func performBackgroundAlertCheck(taskStart: CFAbsoluteTime? = nil) async -> Bool {
    guard alertNotificationsEnabled else {
      return true
    }

    let locations = loadLocationsForBackgroundCheck()
    guard let loc = locations.first else {
      // Stable empty state: no saved locations means nothing to poll; success avoids penalizing BG retries.
      return true
    }

    do {
      let alerts = try await nwsService.fetchActiveAlerts(for: loc, timeout: 8)
      if loc.id == currentLocation?.id {
        activeAlerts = alerts
        lastAlertsFetch = Date()
        alertsForLocation = loc.id
        lastAlertsFetchSucceeded = true
      }
      alertHistory = AlertHistoryStore.merge(fetched: alerts, into: alertHistory)
      AlertHistoryStore.saveHistory(alertHistory)
      persistWidgetAlertSummary(for: loc, alerts: alerts)
      if loc.id == currentLocation?.id {
        syncScoreSurfacesFromCurrentWeather()
      }

      await AlertNotificationService.shared.notifyIfNeeded(
        for: alerts,
        enabled: alertNotificationsEnabled,
        taskStart: taskStart
      )

      await MorningBriefGenerator.generateIfStale(weatherStore: self)

      return true
    } catch is CancellationError {
      return false
    } catch {
      if loc.id == currentLocation?.id {
        lastAlertsFetchSucceeded = false
      }
      return false
    }
  }

  /// Requests notification permission (if needed) then schedules the next BG alert refresh when enabled.
  @MainActor
  func scheduleBackgroundAlertRefreshIfEnabled() async {
    guard alertNotificationsEnabled else { return }
    await requestAlertNotificationPermissionIfNeeded()
    BackgroundAlertRefreshService.scheduleAlertRefreshTask()
  }

  @MainActor
  func requestAlertNotificationPermissionIfNeeded() async {
    await refreshAlertNotificationAuthorizationStatus()
    if alertNotificationAuthorizationStatus == .notDetermined {
      _ = await AlertNotificationService.shared.requestAuthorization()
      alertNotificationAuthorizationStatus = AlertNotificationService.shared.authorizationStatus
    }
  }

  @MainActor
  func refreshAlertNotificationAuthorizationStatus() async {
    await AlertNotificationService.shared.refreshAuthorizationStatus()
    alertNotificationAuthorizationStatus = AlertNotificationService.shared.authorizationStatus
  }

  private func loadLocationsForBackgroundCheck() -> [SavedLocation] {
    let persisted = WidgetDataStore.loadLocationsPreferringAppGroup() ?? savedLocations
    guard !persisted.isEmpty else { return [] }
    if let current = persisted.first(where: { $0.isCurrent }) {
      return [current]
    }
    return [persisted[0]]
  }

  @MainActor
  func refreshNWSObservation() async {
    guard let loc = currentLocation else { return }

    // 5-minute (300s) in-memory cache per location (same as alerts)
    if let last = lastObservationFetch,
      let cachedLocId = observationForLocation,
      cachedLocId == loc.id,
      Date().timeIntervalSince(last) < 300
    {
      return
    }

    do {
      let obs = try await nwsService.fetchLatestObservation(for: loc)
      currentNWSObservation = obs
      lastObservationFetch = Date()
      observationForLocation = loc.id
    } catch {
      // Non-fatal: NWS is secondary data. Silently nil so UI/prompts see no observation.
      // NWS observation fetch failed (non-fatal, log removed for release)
      currentNWSObservation = nil
    }
  }

  @MainActor
  func refreshOpenWeatherMap() async {
    guard let loc = currentLocation else { return }
    guard OpenWeatherMapRadarService.apiKeyConfigured else { return }

    if let last = lastOpenWeatherMapFetch,
      let cachedLocId = openWeatherMapForLocation,
      cachedLocId == loc.id,
      Date().timeIntervalSince(last) < 300
    {
      return
    }

    do {
      let (current, forecast) = try await openWeatherMapService.fetchHybrid(for: loc)
      currentOpenWeatherMapWeather = current
      openWeatherMapForecast = forecast
      lastOpenWeatherMapFetch = Date()
      openWeatherMapForLocation = loc.id
    } catch {
      // Non-fatal: preserve last-known-good hybrid data on failure.
    }
  }

  /// Nearest OpenWeatherMap 3-hour forecast entry within `toleranceMinutes` of `date`.
  func openWeatherMapEntry(closestTo date: Date, toleranceMinutes: Int = 60)
    -> OpenWeatherMapForecastEntry?
  {
    guard let forecast = openWeatherMapForecast else { return nil }
    let tolerance = TimeInterval(toleranceMinutes * 60)
    var best: OpenWeatherMapForecastEntry?
    var bestDelta = TimeInterval.greatestFiniteMagnitude
    for entry in forecast.entries {
      let delta = abs(entry.time.timeIntervalSince(date))
      guard delta <= tolerance, delta < bestDelta else { continue }
      bestDelta = delta
      best = entry
    }
    return best
  }

  func addLocation(_ location: SavedLocation) -> Bool {
    guard EntitlementChecker.canAddLocation(currentCount: savedLocations.count, subscription: SubscriptionManager.shared) else {
      return false
    }
    guard
      !savedLocations.contains(where: {
        abs($0.latitude - location.latitude) < 0.01 && abs($0.longitude - location.longitude) < 0.01
      })
    else { return true }
    savedLocations.append(location)
    saveLocations()
    return true
  }

  func removeLocation(_ location: SavedLocation) {
    savedLocations.removeAll { $0.id == location.id }
    if currentLocation?.id == location.id {
      currentLocation = savedLocations.first
    }
    WidgetDataStore.removeData(for: location.id)
    saveLocations()
    WidgetTimelineReloader.requestReload()
  }

  /// Saves the developer API key using the secure GrokAPIConfiguration (Keychain-backed).
  func saveXAIApiKey(_ key: String) {
    do {
      try grokConfig.saveDeveloperKey(key)
    } catch {
      // During development only — log for debugging
      // Failed to save Grok key securely (log removed)
      // For embedded developer key builds, we don't fall back to the old path
    }
  }

  // For demo / preview
  func loadPreviewData() {
    // Olive Branch preview
    let olive = SavedLocation(name: "Olive Branch, MS", latitude: 34.9618, longitude: -89.8295)
    currentLocation = olive
  }

  /// Clears in-memory weather and App Group widget cache for the active location.
  @MainActor
  func clearLocalWeatherCache() {
    weatherError = nil
    if let loc = currentLocation {
      WidgetDataStore.removeData(for: loc.id)
    }
    currentWeather = nil
    lastAlertsFetch = nil
    lastAlertsFetchSucceeded = false
    WeatherLiveActivityManager.end()
    WidgetTimelineReloader.requestReload()
  }

}
