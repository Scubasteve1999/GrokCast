import SwiftUI

private let locationsContentTopPadding = DesignTokens.Spacing.space16
private let bottomTabClearance = DesignTokens.Layout.tabBarScrollClearance

struct LocationsView: View {
  @Environment(WeatherStore.self) private var store
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @State private var searchText = ""
  @State private var searchResults: [CitySearchResult] = []
  @State private var isSearching = false
  @State private var searchError: String?
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
        FigmaScreenTitle(title: "Locations")

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
        .font(DesignTokens.Typography.callout())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .accessibilityHidden(true)
      TextField("Search cities...", text: $searchText)
        .font(DesignTokens.Typography.callout())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
        .textFieldStyle(.plain)
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .submitLabel(.search)
        .accessibilityLabel("Search cities")
        .accessibilityIdentifier(DayCastAccessibility.Locations.searchField)
        .onChange(of: searchText) { _, newValue in
          scheduleSearch(newValue)
        }
        .onSubmit {
          commitSearch()
        }
      if !searchText.isEmpty {
        Button {
          commitSearch()
        } label: {
          Text("Search")
            .font(DesignTokens.Typography.caption().weight(.semibold))
            .foregroundStyle(DesignTokens.Palette.accent)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(DayCastAccessibility.Locations.searchSubmit)
        .accessibilityLabel("Search cities")
      }
    }
    .padding(.horizontal, DesignTokens.Spacing.space12)
    .padding(.vertical, DesignTokens.Spacing.space12)
    .contentShape(Rectangle())
    .cardStyle(
      background: DesignTokens.Palette.cardElevated,
      stroke: DesignTokens.Palette.cardStroke,
      cornerRadius: DesignTokens.Layout.searchRadius
    )
  }

  @ViewBuilder
  private var figmaSearchResults: some View {
    Text("SEARCH RESULTS")
      .font(DesignTokens.Typography.caption())
      .foregroundStyle(DesignTokens.Palette.textTertiary)

    SettingsGroupCard {
      if isSearching {
        HStack(spacing: 8) {
          ProgressView()
          Text("Searching…")
            .font(DesignTokens.Typography.callout())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
        .padding(DesignTokens.Spacing.space16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Searching for cities")
      } else if let searchError {
        searchFailureRow(searchError)
      } else if searchResults.isEmpty {
        Text(CitySearch.emptyMessage(for: searchText))
          .font(DesignTokens.Typography.callout())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .padding(DesignTokens.Spacing.space16)
      } else {
        ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, item in
          if index > 0 { SettingsDivider() }
          Button {
            selectSearchResult(item)
          } label: {
            SearchResultRow(result: item)
              .padding(.horizontal, DesignTokens.Spacing.space16)
              .padding(.vertical, DesignTokens.Spacing.space12)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier(DayCastAccessibility.Locations.result(item.name))
        }
      }
    }
  }

  private var figmaCurrentSection: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      FigmaSectionLabel(title: "CURRENT LOCATION")

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
              .font(DesignTokens.Typography.symbol(16))
              .foregroundStyle(DesignTokens.Palette.accent)
              .frame(width: 24)
            Text("Use My Current Location")
              .font(DesignTokens.Typography.subsection())
              .foregroundStyle(DesignTokens.Palette.textPrimary)
            Spacer()
          }
          .padding(.horizontal, DesignTokens.Spacing.space16)
          .padding(.vertical, DesignTokens.Spacing.space12)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var figmaSavedSection: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      FigmaSectionLabel(title: "SAVED LOCATIONS")

      SettingsGroupCard {
        let saved = store.savedLocations.filter { !$0.isCurrent }
        if saved.isEmpty {
          Text("No saved cities yet. Search above to add one.")
            .font(DesignTokens.Typography.callout())
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
    .onSubmit(of: .search) {
      commitSearch()
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
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Searching for cities")
      } else if let searchError {
        searchFailureRow(searchError)
      } else if searchResults.isEmpty {
        ContentUnavailableView(
          "No cities found",
          systemImage: "magnifyingglass",
          description: Text(CitySearch.emptyMessage(for: searchText))
        )
        .listRowBackground(Color.clear)
      } else {
        ForEach(searchResults) { item in
          Button {
            selectSearchResult(item)
          } label: {
            SearchResultRow(result: item)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier(DayCastAccessibility.Locations.result(item.name))
        }
      }
    }
  }

  private func scheduleSearch(_ query: String) {
    searchTask?.cancel()
    searchError = nil
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      searchResults = []
      isSearching = false
      return
    }

    isSearching = true
    searchTask = Task {
      try? await Task.sleep(for: .milliseconds(350))
      guard !Task.isCancelled else { return }
      await searchLocations(trimmed)
    }
  }

  private func commitSearch() {
    searchTask?.cancel()
    searchError = nil
    let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      searchResults = []
      isSearching = false
      return
    }
    isSearching = true
    searchTask = Task {
      await searchLocations(trimmed)
    }
  }

  @ViewBuilder
  private func searchFailureRow(_ message: String) -> some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      Text(message)
        .font(DesignTokens.Typography.callout())
        .foregroundStyle(DesignTokens.Palette.textSecondary)
      Button("Try Again") {
        commitSearch()
      }
      .font(DesignTokens.Typography.caption().weight(.semibold))
      .foregroundStyle(DesignTokens.Palette.accent)
    }
    .padding(DesignTokens.Spacing.space16)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func deleteLocations(at offsets: IndexSet) {
    let saved = store.savedLocations.filter { !$0.isCurrent }
    for index in offsets {
      store.removeLocation(saved[index])
    }
  }

  private func selectSearchResult(_ item: CitySearchResult) {
    let candidate = SavedLocation(
      name: item.name,
      latitude: item.latitude,
      longitude: item.longitude
    )
    let decision = CitySearch.selection(
      candidate: candidate,
      saved: store.savedLocations,
      canAdd: EntitlementChecker.canAddLocation(
        currentCount: store.savedLocations.count,
        subscription: SubscriptionManager.shared
      )
    )
    switch decision {
    case .selectExisting(let existing):
      store.selectLocation(existing)
    case .add:
      guard store.addLocation(candidate) else {
        PaywallCoordinator.shared.present(.locations)
        return
      }
      store.selectLocation(candidate)
    case .replace(let current):
      store.removeLocation(current)
      guard store.addLocation(candidate) else {
        PaywallCoordinator.shared.present(.locations)
        return
      }
      store.selectLocation(candidate)
    case .paywall:
      PaywallCoordinator.shared.present(.locations)
      return
    }
    searchText = ""
    searchResults = []
    searchError = nil
    isSearching = false
  }

  @MainActor
  private func searchLocations(_ query: String) async {
    isSearching = true
    defer {
      let stillThisQuery =
        searchText.trimmingCharacters(in: .whitespacesAndNewlines) == query
      if stillThisQuery {
        isSearching = false
      }
    }

    do {
      let results = try await CitySearch.search(query: query)
      guard !Task.isCancelled else { return }
      searchResults = results
      searchError = nil
    } catch is CancellationError {
      return
    } catch {
      guard !Task.isCancelled else { return }
      searchResults = []
      searchError = CitySearch.errorMessage(for: error)
    }
  }
}

private struct SearchResultRow: View {
  let result: CitySearchResult

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(result.name)
          .font(DesignTokens.Typography.headline())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        if let subtitle = result.subtitle {
          Text(subtitle)
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
            .lineLimit(2)
        }
      }
      Spacer()
      Image(systemName: "plus.circle")
        .foregroundStyle(DesignTokens.Palette.accent)
        .accessibilityHidden(true)
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Add \(result.name)")
    .accessibilityAddTraits(.isButton)
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
        .font(DesignTokens.Typography.symbol(16))
        .foregroundStyle(DesignTokens.Palette.accent)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 2) {
        Text(location.name)
          .font(DesignTokens.Typography.subsection())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .multilineTextAlignment(.leading)

        if location.isCurrent {
          Text(isSelected ? "GPS · Selected" : "GPS")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
      }

      Spacer(minLength: 0)

      Image(systemName: "chevron.right")
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
    }
    .padding(.vertical, DesignTokens.Spacing.space12)
    .contentShape(Rectangle())
  }

  private var standardRow: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(location.name)
          .font(DesignTokens.Typography.headline())
        Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
          .font(DesignTokens.Typography.micro().monospaced())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      }
      Spacer()
      if location.isCurrent {
        Image(systemName: "mappin.circle.fill")
          .foregroundStyle(DesignTokens.Palette.accent)
      } else if isSelected {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(DesignTokens.Palette.accent)
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
