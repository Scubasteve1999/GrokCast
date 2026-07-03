import MapKit
import SwiftUI

private let locationsContentTopPadding = DesignTokens.Spacing.space16
private let bottomTabClearance = DesignTokens.Spacing.space32

struct LocationsView: View {
  @Environment(WeatherStore.self) private var store
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @State private var searchText = ""
  @State private var searchResults: [MKMapItem] = []
  @State private var isSearching = false
  @State private var searchTask: Task<Void, Never>?

  private var isShowingSearch: Bool {
    !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var prefersFigmaLayout: Bool {
    horizontalSizeClass == .compact
  }

  var body: some View {
    NavigationStack {
      Group {
        if prefersFigmaLayout {
          figmaLocationsScroll
        } else {
          standardLocationsList
        }
      }
      .readableContentWidth(ReadableContentWidth.wide)
      .navigationTitle(prefersFigmaLayout ? "" : "Locations")
      .navigationBarTitleDisplayMode(prefersFigmaLayout ? .inline : .large)
      .toolbar {
        if !prefersFigmaLayout {
          EditButton()
            .disabled(isShowingSearch)
        }
      }
    }
  }

  private var figmaLocationsScroll: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        Text("Locations")
          .font(.system(size: 34, weight: .bold))
          .foregroundStyle(DesignTokens.Palette.textPrimary)

        figmaSearchField

        if isShowingSearch {
          figmaSearchResults
        } else {
          figmaCurrentSection
          figmaSavedSection
        }
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.top, locationsContentTopPadding)
      .padding(.bottom, bottomTabClearance)
    }
    .scrollContentBackground(.hidden)
    .background(DesignTokens.Palette.bgPrimary)
  }

  private var figmaSearchField: some View {
    HStack(spacing: DesignTokens.Spacing.space8) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 15))
        .foregroundStyle(DesignTokens.Palette.textTertiary)
      TextField("Search cities...", text: $searchText)
        .font(.system(size: 15))
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .onChange(of: searchText) { _, newValue in
          scheduleSearch(newValue)
        }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .cardStyle(
      background: DesignTokens.Palette.cardElevated,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: 10
    )
  }

  @ViewBuilder
  private var figmaSearchResults: some View {
    Text("SEARCH RESULTS")
      .font(.system(size: 11, weight: .bold))
      .foregroundStyle(DesignTokens.Palette.textTertiary)

    SettingsGroupCard {
      if isSearching {
        HStack(spacing: 8) {
          ProgressView()
          Text("Searching…")
            .font(.subheadline)
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
        .padding(DesignTokens.Spacing.space16)
      } else if searchResults.isEmpty {
        Text("No locations found. Try Memphis or Nashville.")
          .font(.subheadline)
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .padding(DesignTokens.Spacing.space16)
      } else {
        ForEach(Array(searchResults.enumerated()), id: \.offset) { index, item in
          if index > 0 { SettingsDivider() }
          Button {
            selectSearchResult(item)
          } label: {
            SearchResultRow(item: item)
              .padding(.horizontal, DesignTokens.Spacing.space16)
              .padding(.vertical, DesignTokens.Spacing.space12)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var figmaCurrentSection: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      Text("CURRENT LOCATION")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(DesignTokens.Palette.textTertiary)

      SettingsGroupCard {
        if let current = store.currentLocation {
          LocationRow(location: current, isSelected: true, layout: .figma) {}
            .padding(.horizontal, DesignTokens.Spacing.space16)
        }

        SettingsDivider()

        Button {
          Task { await store.useCurrentDeviceLocation() }
        } label: {
          HStack(spacing: DesignTokens.Spacing.space12) {
            Image(systemName: "location.fill")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(DesignTokens.Palette.accent)
              .frame(width: 24)
            Text("Use My Current Location")
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(DesignTokens.Palette.textPrimary)
            Spacer()
          }
          .padding(.horizontal, DesignTokens.Spacing.space16)
          .padding(.vertical, DesignTokens.Spacing.space12)
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var figmaSavedSection: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      Text("SAVED LOCATIONS")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(DesignTokens.Palette.textTertiary)

      SettingsGroupCard {
        let saved = store.savedLocations.filter { !$0.isCurrent }
        if saved.isEmpty {
          Text("No saved cities yet. Search above to add one.")
            .font(.subheadline)
            .foregroundStyle(DesignTokens.Palette.textSecondary)
            .padding(DesignTokens.Spacing.space16)
        } else {
          ForEach(Array(saved.enumerated()), id: \.element.id) { index, loc in
            if index > 0 { SettingsDivider() }
            LocationRow(
              location: loc,
              isSelected: store.currentLocation?.id == loc.id,
              layout: .figma
            ) {
              store.selectLocation(loc)
            }
            .padding(.horizontal, DesignTokens.Spacing.space16)
            .contextMenu {
              Button("Delete", role: .destructive) {
                store.removeLocation(loc)
              }
            }
          }
        }
      }
    }
  }

  private var standardLocationsList: some View {
    List {
      if isShowingSearch {
        searchResultsSection
      } else {
        currentLocationSection
        savedLocationsSection
      }
    }
    .searchable(text: $searchText, prompt: "Search cities...")
    .onChange(of: searchText) { _, newValue in
      scheduleSearch(newValue)
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
  var layout: LocationRowLayout = .standard
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      switch layout {
      case .standard:
        standardRow
      case .figma:
        figmaRow
      }
    }
    .buttonStyle(.plain)
  }

  private var figmaRow: some View {
    HStack(spacing: DesignTokens.Spacing.space12) {
      Image(systemName: location.isCurrent ? "location.fill" : "mappin.and.ellipse")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(DesignTokens.Palette.accent)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 2) {
        Text(location.name)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .multilineTextAlignment(.leading)

        if location.isCurrent {
          Text(isSelected ? "GPS · Selected" : "GPS")
            .font(.system(size: 13))
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
      }

      Spacer(minLength: 0)

      Image(systemName: "chevron.right")
        .font(.caption.weight(.bold))
        .foregroundStyle(DesignTokens.Palette.textTertiary)
    }
    .padding(.vertical, DesignTokens.Spacing.space12)
    .contentShape(Rectangle())
  }

  private var standardRow: some View {
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
}

enum LocationRowLayout {
  case standard
  case figma
}

#Preview {
  LocationsView()
    .environment(WeatherStore())
}
