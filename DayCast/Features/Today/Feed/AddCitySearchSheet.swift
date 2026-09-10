import SwiftUI

/// Compact city search from Today's chip bar. Reuses `CitySearch` + `LocationSearchFlow`.
struct AddCitySearchSheet: View {
  @Environment(WeatherStore.self) private var store
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(\.dismiss) private var dismiss

  var onRequestPaywall: () -> Void

  @State private var searchText = ""
  @State private var searchResults: [CitySearchResult] = []
  @State private var isSearching = false
  @State private var searchError: String?
  @State private var searchTask: Task<Void, Never>?

  private var trimmedQuery: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var isShowingResults: Bool {
    !trimmedQuery.isEmpty
  }

  private var showsFreeLimitCaption: Bool {
    !subscription.isPro
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
          searchField
          if isShowingResults {
            resultsCard
          } else if showsFreeLimitCaption {
            Text(LocationsCopy.freeLimitChip)
              .font(DesignTokens.Typography.caption())
              .foregroundStyle(DesignTokens.Palette.textTertiary)
              .accessibilityIdentifier(DayCastAccessibility.Locations.freeLimitChip)
          }
        }
        .padding(.horizontal, DesignTokens.Spacing.space20)
        .padding(.top, DesignTokens.Spacing.space16)
        .padding(.bottom, DesignTokens.Spacing.space24)
      }
      .scrollContentBackground(.hidden)
      .background(DesignTokens.Palette.bgPrimary.ignoresSafeArea())
      .navigationTitle("Add city")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
      }
      .accessibilityIdentifier(DayCastAccessibility.Today.addCitySearch)
    }
    .preferredColorScheme(.dark)
    .onDisappear {
      searchTask?.cancel()
    }
  }

  private var searchField: some View {
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
        .accessibilityIdentifier(DayCastAccessibility.Today.addCitySearchField)
        .onChange(of: searchText) { _, newValue in
          scheduleSearch(newValue)
        }
        .onSubmit {
          commitSearch()
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
  private var resultsCard: some View {
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
          Text(searchError)
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

  private func selectSearchResult(_ item: CitySearchResult) {
    let selection = LocationSearchFlow.apply(
      result: item,
      store: store,
      isPro: subscription.isPro,
      presentPaywall: onRequestPaywall
    )
    if case .paywall = selection { return }
    dismiss()
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
