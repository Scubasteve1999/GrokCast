import SwiftUI
import MapKit

struct LocationsView: View {
    @Environment(WeatherStore.self) private var store

    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var showingAPIKeySheet = false
    @State private var apiKeyInput = ""

    var body: some View {
        NavigationStack {
            List {
                // Current / Selected
                Section("Current Location") {
                    if let current = store.currentLocation {
                        LocationRow(location: current, isSelected: true) {
                            // already selected
                        }
                    }
                    Button {
                        Task { await store.useCurrentDeviceLocation() }
                    } label: {
                        Label("Use My Current Location", systemImage: "location.fill")
                    }
                }

                // Saved
                Section("Saved Locations") {
                    ForEach(store.savedLocations.filter { !$0.isCurrent }) { loc in
                        LocationRow(location: loc, isSelected: store.currentLocation?.id == loc.id) {
                            store.selectLocation(loc)
                        }
                    }
                    .onDelete(perform: deleteLocations)
                }

                // xAI Integration
                Section("xAI API (Grok)") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("API Key")
                                .font(.subheadline.weight(.medium))
                            Text(store.xaiService.hasAPIKey() ? "••••••••••••" + String(store.xaiService.apiKey.suffix(4)) : "Not set")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(store.xaiService.hasAPIKey() ? "Update" : "Add Key") {
                            apiKeyInput = store.xaiService.apiKey
                            showingAPIKeySheet = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)

                    Link("Get your free xAI API key →", destination: URL(string: "https://console.x.ai/")!)
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }
            .navigationTitle("Locations")
            .searchable(text: $searchText, prompt: "Search cities...")
            .onChange(of: searchText) { _, newValue in
                Task { await searchLocations(newValue) }
            }
            .sheet(isPresented: $showingAPIKeySheet) {
                APIKeySheet(apiKey: $apiKeyInput) { key in
                    store.saveXAIApiKey(key)
                    showingAPIKeySheet = false
                }
            }
            .toolbar {
                EditButton()
            }
        }
    }

    private func deleteLocations(at offsets: IndexSet) {
        let toDelete = offsets.map { store.savedLocations.filter { !$0.isCurrent }[$0] }
        for loc in toDelete {
            store.removeLocation(loc)
        }
    }

    private func searchLocations(_ query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest

        do {
            let response = try await MKLocalSearch(request: request).start()
            await MainActor.run {
                searchResults = response.mapItems
            }
        } catch {
            print("Search error: \(error)")
        }
    }
}

struct LocationRow: View {
    let location: SavedLocation
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(location.name)
                        .font(.body.weight(.medium))
                    Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct APIKeySheet: View {
    @Binding var apiKey: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("xai-...", text: $apiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("xAI API Key")
                } footer: {
                    Text("Your key is stored locally in UserDefaults for this demo. For production apps, use Keychain.")
                }

                Section {
                    Button("Save Key") {
                        onSave(apiKey)
                        dismiss()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("xAI API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    LocationsView()
        .environment(WeatherStore())
}