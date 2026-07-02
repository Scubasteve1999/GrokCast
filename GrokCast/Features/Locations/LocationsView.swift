import MapKit
import SwiftUI

struct LocationsView: View {
  @Environment(WeatherStore.self) private var store

  @State private var searchText = ""
  @State private var searchResults: [MKMapItem] = []

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

      }
      .readableContentWidth(ReadableContentWidth.wide)
      .navigationTitle("Locations")
      .searchable(text: $searchText, prompt: "Search cities...")
      .onChange(of: searchText) { _, newValue in
        Task { await searchLocations(newValue) }
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
      Task { @MainActor in
        searchResults = response.mapItems
      }
    } catch {
      // Search error (log removed for release)
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
        if location.isCurrent {
          Image(systemName: "mappin.circle.fill")
            .foregroundStyle(.tint)
        } else if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.tint)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  LocationsView()
    .environment(WeatherStore())
}
