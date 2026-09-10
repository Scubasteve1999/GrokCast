import SwiftUI

private let locationsContentTopPadding = DesignTokens.Spacing.space16
private let bottomTabClearance = DesignTokens.Layout.tabBarScrollClearance

/// Locations chrome. Free is Near Me + one named city; GPS is not a saved slot.
enum LocationsCopy {
  static let freeLimitChip = "Free includes Near Me + 1 saved city"
  static let saveUnlimitedCTA = "Save unlimited places"
  static let emptySaved = "No saved cities yet. Search above to add one."
}

struct LocationsView: View {
  @Environment(WeatherStore.self) private var store
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var editMode: EditMode = .inactive

  @State private var searchText = ""
  @State private var searchResults: [CitySearchResult] = []
  @State private var isSearching = false
  @State private var searchError: String?
  @State private var searchTask: Task<Void, Never>?

  private var isShowingSearch: Bool {
    !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// Observed on this view so Saved empty/list is not stuck on first paint.
  private var listedSaved: [SavedLocation] {
    CitySearch.listedSavedLocations(
      from: store.savedLocations, current: store.currentLocation)
  }

  private var prefersFigmaLayout: Bool {
    horizontalSizeClass == .compact
  }

  private var showsFreeLimitChrome: Bool {
    !subscription.isPro
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
      .weatherShowsThroughNavigationBar()
      .toolbar {
        if !isShowingSearch {
          EditButton()
            .disabled(listedSaved.isEmpty)
        }
      }
      .environment(\.editMode, $editMode)
      .onChange(of: isShowingSearch) { _, showing in
        if showing { editMode = .inactive }
      }
      .onChange(of: listedSaved.isEmpty) { _, empty in
        if empty { editMode = .inactive }
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
    .background {
      WeatherBackgroundLayer(
        conditionCode: store.displayedWeather?.conditionCode,
        isDay: store.displayedWeather.map {
          WeatherBackgroundView.isDay(from: $0.symbolName)
        }
          ?? WeatherBackgroundView.inferredIsDay(
            timeZone: store.displayedWeather?.locationTimeZone ?? .current
          )
      )
    }
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
    Text("Search results")
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
            CitySearchResultRow(result: item)
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
      FigmaSectionLabel(title: "Current location")

      SettingsGroupCard {
        if let current = store.currentLocation {
          LocationRow(
            location: current,
            isSelected: true,
            layout: .figma,
            weather: weatherSnapshot(for: current)
          )
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
      FigmaSectionLabel(title: "Saved locations")

      SettingsGroupCard {
        if listedSaved.isEmpty {
          Text(LocationsCopy.emptySaved)
            .font(DesignTokens.Typography.callout())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
            .padding(DesignTokens.Spacing.space16)
        } else {
          ForEach(Array(listedSaved.enumerated()), id: \.element.id) { index, loc in
            if index > 0 { SettingsDivider() }
            LocationsSwipeDeleteRow(
              deleteAccessibilityID: DayCastAccessibility.Locations.deleteSaved(loc.name),
              isEditing: editMode.isEditing,
              onDelete: { store.removeLocation(loc) }
            ) {
              LocationRow(
                location: loc,
                isSelected: store.currentLocation?.id == loc.id,
                layout: .figma,
                weather: weatherSnapshot(for: loc)
              ) {
                store.selectLocation(loc)
              }
              .padding(.horizontal, DesignTokens.Spacing.space16)
              .accessibilityIdentifier(DayCastAccessibility.Locations.savedRow(loc.name))
              .contextMenu {
                Button("Delete", role: .destructive) {
                  store.removeLocation(loc)
                }
              }
            }
          }
        }

        if showsFreeLimitChrome {
          SettingsDivider()
          freeLimitFooter
            .padding(.horizontal, DesignTokens.Spacing.space16)
            .padding(.vertical, DesignTokens.Spacing.space12)
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
        LocationRow(
          location: current,
          isSelected: true,
          weather: weatherSnapshot(for: current)
        )
      }
      Button {
        Task { await store.useCurrentDeviceLocation() }
      } label: {
        Label("Use My Current Location", systemImage: "location.fill")
      }
    }
  }

  private var savedLocationsSection: some View {
    Section {
      ForEach(listedSaved) { loc in
        LocationRow(
          location: loc,
          isSelected: store.currentLocation?.id == loc.id,
          weather: weatherSnapshot(for: loc)
        ) {
          store.selectLocation(loc)
        }
        .accessibilityIdentifier(DayCastAccessibility.Locations.savedRow(loc.name))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
          Button("Delete", role: .destructive) {
            store.removeLocation(loc)
          }
          .accessibilityIdentifier(DayCastAccessibility.Locations.deleteSaved(loc.name))
        }
      }
      .onDelete(perform: deleteLocations)
    } header: {
      Text("Saved Locations")
    } footer: {
      if showsFreeLimitChrome {
        freeLimitFooter
      }
    }
  }

  private var freeLimitFooter: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      Text(LocationsCopy.freeLimitChip)
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
        .accessibilityIdentifier(DayCastAccessibility.Locations.freeLimitChip)
      Button(LocationsCopy.saveUnlimitedCTA) {
        PaywallCoordinator.shared.present(.locations, source: .locations)
      }
      .font(DesignTokens.Typography.caption().weight(.semibold))
      .foregroundStyle(DesignTokens.Palette.accent)
      .accessibilityIdentifier(DayCastAccessibility.Locations.saveUnlimitedCTA)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .contain)
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
            CitySearchResultRow(result: item)
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
    let saved = CitySearch.listedSavedLocations(
      from: store.savedLocations, current: store.currentLocation)
    for index in offsets {
      store.removeLocation(saved[index])
    }
  }

  private func selectSearchResult(_ item: CitySearchResult) {
    let selection = LocationSearchFlow.apply(
      result: item,
      store: store,
      isPro: subscription.isPro,
      presentPaywall: {
        PaywallCoordinator.shared.present(.locations, source: .locations)
      }
    )
    if case .paywall = selection { return }
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

  private func weatherSnapshot(for location: SavedLocation) -> LocationRowWeather.Snapshot {
    if location.id == store.currentLocation?.id, let weather = store.displayedWeather {
      let active = store.displayableGroupedAlerts.filter { !$0.isExpired }
      return LocationRowWeather.make(
        temperature: weather.currentTemp,
        symbolName: weather.symbolName,
        hasAlert: !active.isEmpty,
        alertIsWarning: active.contains(where: \.usesWarningEmphasis),
        unit: store.temperatureUnit
      )
    }
    return LocationRowWeather.make(
      weather: WidgetDataStore.loadSnapshot(for: location.id),
      alert: WidgetDataStore.loadAlertSummary(for: location.id),
      unit: store.temperatureUnit
    )
  }
}

enum LocationRowWeather {
  struct Snapshot: Equatable {
    var temperatureText: String?
    var symbolName: String?
    var hasAlert: Bool
    var alertIsWarning: Bool
  }

  static func make(
    weather: WidgetWeatherSnapshot?,
    alert: WidgetAlertSummary?,
    unit: TemperatureUnit,
    now: Date = Date()
  ) -> Snapshot {
    let active = alert?.isActive(relativeTo: now) == true
    return make(
      temperature: weather?.currentTemp,
      symbolName: weather?.symbolName,
      hasAlert: active,
      alertIsWarning: active && (alert?.topIsWarning == true),
      unit: unit
    )
  }

  static func make(
    temperature: Double?,
    symbolName: String?,
    hasAlert: Bool,
    alertIsWarning: Bool = false,
    unit: TemperatureUnit
  ) -> Snapshot {
    Snapshot(
      temperatureText: temperature.map { unit.formatShort($0) },
      symbolName: symbolName,
      hasAlert: hasAlert,
      alertIsWarning: hasAlert && alertIsWarning
    )
  }

  static func accessibilityLabel(
    locationName: String,
    snapshot: Snapshot?
  ) -> String {
    var parts = [locationName]
    if let temp = snapshot?.temperatureText, !temp.isEmpty {
      parts.append(temp)
    }
    if snapshot?.hasAlert == true {
      parts.append("Active alert")
    }
    return parts.joined(separator: ", ")
  }
}

struct LocationRow: View {
  let location: SavedLocation
  let isSelected: Bool
  var layout: LocationRowLayout = .standard
  var weather: LocationRowWeather.Snapshot? = nil
  var onTap: (() -> Void)? = nil

  var body: some View {
    Group {
      if let onTap {
        Button(action: onTap) { rowContent }
          .buttonStyle(.plain)
      } else {
        rowContent
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.accessibilityLabel(for: location, weather: weather))
    .accessibilityAddTraits(onTap == nil ? [] : .isButton)
    .accessibilityHint(onTap == nil ? "" : "Shows weather for this city")
  }

  static func accessibilityLabel(
    for location: SavedLocation,
    isSelected: Bool = false,
    weather: LocationRowWeather.Snapshot? = nil
  ) -> String {
    _ = isSelected
    return LocationRowWeather.accessibilityLabel(
      locationName: location.name, snapshot: weather)
  }

  @ViewBuilder
  private var rowContent: some View {
    switch layout {
    case .standard:
      standardRow
    case .figma:
      figmaRow
    }
  }

  @ViewBuilder
  private var weatherTrailing: some View {
    if weather?.hasAlert == true {
      Circle()
        .fill(
          weather?.alertIsWarning == true
            ? DesignTokens.Palette.danger
            : DesignTokens.Palette.warning
        )
        .frame(width: 8, height: 8)
        .accessibilityHidden(true)
    }
    if let symbol = weather?.symbolName, !symbol.isEmpty {
      Image(systemName: symbol)
        .font(DesignTokens.Typography.symbol(16))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(DesignTokens.Palette.textSecondary)
        .frame(width: 22)
        .accessibilityHidden(true)
    }
    if let temp = weather?.temperatureText {
      Text(temp)
        .font(DesignTokens.Typography.subsection().monospacedDigit())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
    }
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

      weatherTrailing

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
      weatherTrailing
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

/// Compact Locations is a ScrollView, not a List — `swipeActions` does not apply.
/// Reveal a Delete control on swipe or when Edit is on.
private struct LocationsSwipeDeleteRow<Content: View>: View {
  let deleteAccessibilityID: String
  let isEditing: Bool
  let onDelete: () -> Void
  @ViewBuilder var content: () -> Content

  @State private var offset: CGFloat = 0
  private let revealWidth: CGFloat = 80

  var body: some View {
    ZStack(alignment: .trailing) {
      Button(role: .destructive, action: onDelete) {
        Image(systemName: "trash")
          .font(DesignTokens.Typography.subsection())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .frame(width: revealWidth)
          .frame(maxHeight: .infinity)
          .background(DesignTokens.Palette.danger)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Delete")
      .accessibilityIdentifier(deleteAccessibilityID)

      content()
        .background(DesignTokens.Palette.cardBackground)
        .offset(x: revealedOffset)
        .animation(.easeOut(duration: 0.2), value: revealedOffset)
        .simultaneousGesture(
          DragGesture(minimumDistance: 24)
            .onChanged { value in
              let x = min(0, value.translation.width)
              offset = max(-revealWidth, x)
            }
            .onEnded { value in
              withAnimation(.easeOut(duration: 0.2)) {
                offset = value.translation.width < -(revealWidth / 2) ? -revealWidth : 0
              }
            }
        )
    }
    .clipped()
    .onChange(of: isEditing) { _, editing in
      if !editing { offset = 0 }
    }
  }

  private var revealedOffset: CGFloat {
    isEditing ? -revealWidth : offset
  }
}

#Preview {
  LocationsView()
    .environment(WeatherStore())
    .environment(SubscriptionManager.shared)
}
