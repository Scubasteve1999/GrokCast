import SwiftUI

struct AlertsView: View {
  @Environment(WeatherStore.self) private var store
  @State private var selectedAlert: NWSAlert?

  private var activeAlerts: [NWSAlert] {
    store.displayableActiveAlerts
      .sorted { $0.severityLevel > $1.severityLevel }
  }

  private var historicalAlerts: [NWSAlert] {
    let activeIDs = Set(activeAlerts.map(\.id))
    return store.alertHistory
      .filter { !activeIDs.contains($0.id) }
      .sorted { $0.sortDate > $1.sortDate }
  }

  var body: some View {
    NavigationStack {
      Group {
        if store.isLoadingWeather && activeAlerts.isEmpty && historicalAlerts.isEmpty {
          // --skeletons: shimmer for NWS primary loading states (Today, Forecast, Alerts)
          VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in
              ShimmerBlock(width: nil, height: 52, cornerRadius: 10)
                .padding(.horizontal, 4)
            }
          }
          .padding(.top, 20)
        } else if activeAlerts.isEmpty && historicalAlerts.isEmpty {
          emptyState
        } else {
          alertsList
        }
      }
      .readableContentWidth(ReadableContentWidth.wide)
      .navigationTitle("Alerts")
      .navigationBarTitleDisplayMode(.large)
      .navigationDestination(item: $selectedAlert) { alert in
        AlertDetailView(alert: alert)
      }
      .refreshable {
        await store.refreshAlerts(force: true)
      }
      .task {
        // Initial load already triggers refreshAlerts via refreshWeather; skip duplicate launch fetch.
        guard store.hasCompletedInitialLoad else { return }
        await store.refreshAlerts()
      }
    }
  }

  private var alertsList: some View {
    List {
      Section {
        if activeAlerts.isEmpty {
          Text("No active alerts right now")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          ForEach(activeAlerts) { alert in
            alertRow(alert, isActive: true)
          }
        }
      } header: {
        Label("ACTIVE NOW", systemImage: "bolt.fill")
          .font(.caption.weight(.bold))
          .foregroundStyle(.red)
      }

      if !historicalAlerts.isEmpty {
        Section {
          ForEach(historicalAlerts) { alert in
            alertRow(alert, isActive: false)
          }
        } header: {
          Text("RECENT HISTORY")
            .font(.caption.weight(.bold))
        } footer: {
          Text("Showing alerts from the last \(AlertHistoryStore.retentionDays) days.")
            .font(.caption2)
        }
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(Color.black)
  }

  private func alertRow(_ alert: NWSAlert, isActive: Bool) -> some View {
    Button {
      Haptic.impact(.light)
      selectedAlert = alert
    } label: {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: NWSAlertStyle.iconName(for: alert))
          .font(.title3)
          .foregroundStyle(NWSAlertStyle.tint(for: alert))
          .frame(width: 28)

        VStack(alignment: .leading, spacing: 4) {
          Text(alert.event)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)

          if let headline = alert.headline, !headline.isEmpty {
            Text(headline)
              .font(.caption)
              .foregroundStyle(.white.opacity(0.75))
              .lineLimit(2)
              .multilineTextAlignment(.leading)
          }

          if let area = alert.areaDesc, !area.isEmpty {
            Text(area)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }

          Text(rowTimestamp(for: alert, isActive: isActive))
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
        }

        Spacer(minLength: 0)

        if isActive {
          Text("LIVE")
            .font(.caption2.weight(.heavy))
            .tracking(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(NWSAlertStyle.tint(for: alert).opacity(0.2), in: Capsule())
            .foregroundStyle(NWSAlertStyle.tint(for: alert))
        }

        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(.vertical, 4)
    }
    .buttonStyle(.plain)
  }

  private func rowTimestamp(for alert: NWSAlert, isActive: Bool) -> String {
    if isActive, let expires = alert.expires {
      return "Expires \(expires.formatted(date: .abbreviated, time: .shortened))"
    }
    return alert.sortDate.formatted(date: .abbreviated, time: .shortened)
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label("No Alerts", systemImage: "checkmark.shield")
    } description: {
      Text(
        "No active or recent NWS alerts for \(store.currentLocation?.name ?? "your location"). Severe weather Warnings and Watches will appear here."
      )
    } actions: {
      Button("REFRESH") {
        Haptic.impact(.medium)
        Task { await store.refreshAlerts(force: true) }
      }
      .buttonStyle(.borderedProminent)
    }
    .padding()
  }
}

#Preview {
  let store = WeatherStore()
  store.activeAlerts = [
    NWSAlert(
      id: "preview-active",
      event: "Severe Thunderstorm Warning",
      severity: "Severe",
      headline: "Take shelter immediately",
      description: "Damaging winds expected.",
      instruction: "Move to an interior room.",
      expires: Date().addingTimeInterval(3600),
      areaDesc: "DeSoto, MS",
      latitude: 34.96,
      longitude: -89.83
    )
  ]
  store.alertHistory = store.activeAlerts
  return AlertsView()
    .environment(store)
}
