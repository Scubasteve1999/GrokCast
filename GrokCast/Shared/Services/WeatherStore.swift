import Foundation
import CoreLocation
import SwiftUI
import SwiftData

@Observable
final class WeatherStore {
    var currentLocation: SavedLocation?
    var currentWeather: GrokCastWeather?
    var savedLocations: [SavedLocation] = []
    var isLoadingWeather = false
    var weatherError: String?

    var selectedTab: Tab = .today

    enum Tab: String, CaseIterable, Identifiable {
        case today = "Today"
        case forecast = "Forecast"
        case grok = "Grok AI"
        case locations = "Locations"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .today: "sun.max"
            case .forecast: "calendar"
            case .grok: "sparkles"
            case .locations: "mappin.and.ellipse"
            }
        }
    }

    private let locationService = LocationService()
    private let openMeteo = OpenMeteoService()
    let xaiService = XAIService()
    private let keychain = KeychainService.shared

    private let savedLocationsKey = "grokcast_saved_locations"

    init() {
        loadSavedLocations()
        // Default to Olive Branch, MS (tactical Mississippi location)
        if savedLocations.isEmpty {
            let oliveBranch = SavedLocation(
                name: "Olive Branch, MS",
                latitude: 34.9618,
                longitude: -89.8295
            )
            savedLocations = [oliveBranch]
        }
        currentLocation = savedLocations.first

        // Load API key from secure Keychain
        if let key = try? keychain.load() {
            xaiService.apiKey = key
        }
    }

    func loadSavedLocations() {
        if let data = UserDefaults.standard.data(forKey: savedLocationsKey),
           let decoded = try? JSONDecoder().decode([SavedLocation].self, from: data) {
            savedLocations = decoded
        }
    }

    func saveLocations() {
        if let data = try? JSONEncoder().encode(savedLocations) {
            UserDefaults.standard.set(data, forKey: savedLocationsKey)
        }
    }

    func selectLocation(_ location: SavedLocation) {
        currentLocation = location
        Task { await refreshWeather() }
    }

    @MainActor
    func refreshWeather() async {
        guard let loc = currentLocation else { return }
        isLoadingWeather = true
        weatherError = nil

        do {
            let data = try await openMeteo.fetchForecast(for: loc)
            currentWeather = data
            // TODO: Cache to SwiftData here
        } catch {
            weatherError = error.localizedDescription
        }
        isLoadingWeather = false
    }

    @MainActor
    func useCurrentDeviceLocation() async {
        locationService.requestAuthorization()

        do {
            let clLoc = try await locationService.requestLocation()
            let name = await locationService.reverseGeocode(clLoc) ?? "Current Location"

            let newLoc = SavedLocation(
                name: name,
                latitude: clLoc.coordinate.latitude,
                longitude: clLoc.coordinate.longitude,
                isCurrent: true
            )

            // Replace or add as current
            if let idx = savedLocations.firstIndex(where: { $0.isCurrent }) {
                savedLocations[idx] = newLoc
            } else {
                savedLocations.insert(newLoc, at: 0)
            }
            saveLocations()
            currentLocation = newLoc
            await refreshWeather()
        } catch {
            weatherError = "Could not get your location: \(error.localizedDescription)"
        }
    }

    func addLocation(_ location: SavedLocation) {
        guard !savedLocations.contains(where: { abs($0.latitude - location.latitude) < 0.01 && abs($0.longitude - location.longitude) < 0.01 }) else { return }
        savedLocations.append(location)
        saveLocations()
    }

    func removeLocation(_ location: SavedLocation) {
        savedLocations.removeAll { $0.id == location.id }
        if currentLocation?.id == location.id {
            currentLocation = savedLocations.first
        }
        saveLocations()
    }

    // Securely save xAI key via Keychain
    func saveXAIApiKey(_ key: String) {
        do {
            try keychain.save(key)
            xaiService.apiKey = key
        } catch {
            // Fallback for development
            xaiService.saveAPIKey(key)
        }
    }

    // For demo / preview
    func loadPreviewData() {
        // Olive Branch preview
        let olive = SavedLocation(name: "Olive Branch, MS", latitude: 34.9618, longitude: -89.8295)
        currentLocation = olive
    }
}