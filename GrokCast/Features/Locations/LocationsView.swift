import MapKit
import SwiftUI

struct LocationsView: View {
  @Environment(WeatherStore.self) private var store

  @State private var searchText = ""
  @State private var searchResults: [MKMapItem] = []
  @State private var isSearching = false
  @State private var searchTask: Task<Void, Never>?

  private var isShowingSearch: Bool {
    !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    NavigationStack {
      List {
        if isShowingSearch {
          searchResultsSection
        } else {
          currentLocationSection
          savedLocationsSection
        }
      }
      .readableContentWidth(ReadableContentWidth.wide)
      .navigationTitle("Locations")
      .searchable(text: $searchText, prompt: "Search cities...")
      .onChange(of: searchText) { _, newValue in
        scheduleSearch(newValue)
      }
      .toolbar {
        EditButton()
          .disabled(isShowingSearch)
      }
    }
  }

  private var currentLocationSection: some View {
    Section("Current Location") {
      if let current = store.currentLocation {
        LocationRow(location: current, isSelected: true) {}
      }
      Button {
        Task { await store.useCurrentDeviceLocation() }
      } label: {
        Label("Use My Current Location", systemImage: "location.fill")
      }
    }
  }

  private var savedLocationsSection: some View {
    Section("Saved Locations") {
      ForEach(store.savedLocations.filter { !$0.isCurrent }) { loc in
        LocationRow(location: loc, isSelected: store.currentLocation?.id == loc.id) {
          store.selectLocation(loc)
        }
      }
      .onDelete(perform: deleteLocations)
    }
  }

  @ViewBuilder
  private var searchResultsSection: some View {
    Section("Search Results") {
      if isSearching {
        HStack {
          ProgressView()
          Text("Searching…")
            .foregroundStyle(.secondary)
        }
      } else if searchResults.isEmpty {
        ContentUnavailableView(
          "No locations found",
          systemImage: "magnifyingglass",
          description: Text("Try a city name like Memphis or Nashville.")
        )
        .listRowBackground(Color.clear)
      } else {
        ForEach(searchResults, id: \.self) { item in
          Button {
            selectSearchResult(item)
          } label: {
            SearchResultRow(item: item)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func scheduleSearch(_ query: String) {
    searchTask?.cancel()
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      searchResults = []
      isSearching = false
      return
    }

    searchTask = Task {
      try? await Task.sleep(for: .milliseconds(300))
      guard !Task.isCancelled else { return }
      await searchLocations(trimmed)
    }
  }

  private func deleteLocations(at offsets: IndexSet) {
    let saved = store.savedLocations.filter { !$0.isCurrent }
    for index in offsets {
      store.removeLocation(saved[index])
    }
  }

  private func selectSearchResult(_ item: MKMapItem) {
    let candidate = savedLocation(from: item)
    if let existing = store.savedLocations.first(where: { isNear($0, candidate) }) {
      store.selectLocation(existing)
    } else {
      if !store.addLocation(candidate) {
        PaywallCoordinator.shared.present(.locations)
        return
      }
      store.selectLocation(candidate)
    }
    searchText = ""
    searchResults = []
    isSearching = false
  }

  private func isNear(_ lhs: SavedLocation, _ rhs: SavedLocation) -> Bool {
    abs(lhs.latitude - rhs.latitude) < 0.01 && abs(lhs.longitude - rhs.longitude) < 0.01
  }

  private func savedLocation(from item: MKMapItem) -> SavedLocation {
    let coordinate = item.placemark.coordinate
    return SavedLocation(
      name: locationName(from: item),
      latitude: coordinate.latitude,
      longitude: coordinate.longitude
    )
  }

  private func locationName(from item: MKMapItem) -> String {
    let placemark = item.placemark
    if let city = placemark.locality {
      if let state = placemark.administrativeArea {
        return "\(city), \(state)"
      }
      if let country = placemark.country {
        return "\(city), \(country)"
      }
      return city
    }
    return item.name ?? placemark.name ?? placemark.title ?? "Unknown Location"
  }

  @MainActor
  private func searchLocations(_ query: String) async {
    isSearching = true
    defer { isSearching = false }

    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    request.resultTypes = [.address, .pointOfInterest]

    if let current = store.currentLocation {
      request.region = MKCoordinateRegion(
        center: current.coordinate,
        latitudinalMeters: 800_000,
        longitudinalMeters: 800_000
      )
    }

    do {
      let response = try await MKLocalSearch(request: request).start()
      guard !Task.isCancelled else { return }
      searchResults = response.mapItems
    } catch {
      guard !Task.isCancelled else { return }
      searchResults = []
    }
  }
}

private struct SearchResultRow: View {
  let item: MKMapItem

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(primaryTitle)
          .font(.body.weight(.medium))
          .foregroundStyle(.primary)
        if let subtitle {
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }
      Spacer()
      Image(systemName: "plus.circle")
        .foregroundStyle(.tint)
    }
    .contentShape(Rectangle())
  }

  private var primaryTitle: String {
    if let city = item.placemark.locality, let state = item.placemark.administrativeArea {
      return "\(city), \(state)"
    }
    return item.name ?? item.placemark.name ?? item.placemark.title ?? "Unknown Location"
  }

  private var subtitle: String? {
    if item.placemark.locality != nil {
      return item.placemark.title
    }
    let coordinate = item.placemark.coordinate
    return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
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
