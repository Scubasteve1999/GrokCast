import CoreLocation
import SwiftUI

struct FireFeedCard: View {
  let summary: FireFeedSummary
  var onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
        HStack {
          Label("Fire", systemImage: "flame.fill")
            .font(DesignTokens.Typography.subsection())
            .foregroundStyle(DesignTokens.Palette.accentWarm)
                .tracking(DesignTokens.Typography.cardLabelTracking)
            .labelStyle(.titleAndIcon)
          Spacer()
          Image(systemName: "chevron.right")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }

        Text(summary.title)
          .font(DesignTokens.Typography.metric())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .lineLimit(2)

        Text(summary.subtitle)
          .font(DesignTokens.Typography.callout())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .lineLimit(2)

        if summary.hotspotCount > 0 || summary.incidentCount > 0 {
          HStack(spacing: DesignTokens.Spacing.space12) {
            if summary.incidentCount > 0 {
              metricChip(
                icon: "mappin.and.ellipse",
                text: "\(summary.incidentCount) incident\(summary.incidentCount == 1 ? "" : "s")"
              )
            }
            if summary.hotspotCount > 0 {
              metricChip(
                icon: "circle.fill",
                text: "\(summary.hotspotCount) heat point\(summary.hotspotCount == 1 ? "" : "s")"
              )
            }
          }
        }
      }
      .padding(DesignTokens.Spacing.space16)
      .cardStyle()
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "Fire. \(summary.title). \(summary.subtitle) Opens details."
    )
    .accessibilityAddTraits(.isButton)
  }

  private func metricChip(icon: String, text: String) -> some View {
    Label(text, systemImage: icon)
      .font(DesignTokens.Typography.caption())
      .foregroundStyle(DesignTokens.Palette.accentWarm.opacity(0.95))
      .labelStyle(.titleAndIcon)
  }
}

struct FireDetailView: View {
  let snapshot: FireSnapshot
  let origin: CLLocationCoordinate2D?
  let fireWeatherAlerts: [NWSAlert]
  var radiusMiles: Double = FireNotifyConfig.default.radiusMiles

  @State private var smokeObservation: AirNowService.Observation?
  @State private var didLoadSmoke = false

  /// Same 25 mi (or Settings radius) set as the Today card. Not the FIRMS fetch box.
  private var local: (hotspots: [(FireHotspot, Double)], incidents: [(FireIncident, Double)]) {
    guard let origin else { return ([], []) }
    return FireFeedVisibility.localDetections(
      in: snapshot,
      origin: origin,
      radiusMiles: radiusMiles
    )
  }

  private var rankedIncidents: [(FireIncident, Double?)] {
    if origin != nil {
      return local.incidents.map { ($0.0, Optional($0.1)) }
    }
    return snapshot.incidents.map { ($0, nil) }
  }

  private var rankedHotspots: [(FireHotspot, Double)] {
    local.hotspots
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
        if !fireWeatherAlerts.isEmpty {
          alertSection
        }

        if let smokeObservation {
          smokeCard(smokeObservation)
        }

        if !rankedIncidents.isEmpty {
          sectionHeader(
            origin == nil
              ? "Incidents"
              : FireFeedVisibility.nearbyIncidentsHeader(count: rankedIncidents.count)
          )
          ForEach(rankedIncidents, id: \.0.id) { item in
            incidentRow(item.0, miles: item.1)
          }
        }

        if !rankedHotspots.isEmpty {
          sectionHeader(
            FireFeedVisibility.nearbyDetectionsHeader(count: rankedHotspots.count)
          )
          ForEach(rankedHotspots, id: \.0.id) { item in
            hotspotRow(item.0, miles: item.1)
          }
        }

        if rankedIncidents.isEmpty && rankedHotspots.isEmpty && fireWeatherAlerts.isEmpty {
          Text("No active fire data for this location right now.")
            .font(DesignTokens.Typography.body())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }

        Text(
          "Hotspots from NASA FIRMS; incidents from NIFC. Red Flag warnings come from NWS."
        )
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
      }
      .padding(DesignTokens.Spacing.space20)
      .padding(.bottom, DesignTokens.Layout.tabBarScrollClearance)
    }
    .background(DesignTokens.Palette.bgPrimary.ignoresSafeArea())
    .navigationTitle("Fire")
    .navigationBarTitleDisplayMode(.inline)
    .preferredColorScheme(.dark)
    .task {
      guard !didLoadSmoke, let origin else { return }
      didLoadSmoke = true
      smokeObservation = await AirNowService.currentAQI(
        near: origin,
        apiKey: DeveloperAPIKey.airNow
      )
    }
  }

  private var alertSection: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      sectionHeader("Fire weather")
      ForEach(fireWeatherAlerts) { alert in
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
          Text(alert.event)
            .font(DesignTokens.Typography.subsection())
            .foregroundStyle(DesignTokens.Palette.accentWarm)
          if let headline = alert.headline, !headline.isEmpty {
            Text(headline)
              .font(DesignTokens.Typography.caption())
              .foregroundStyle(DesignTokens.Palette.textSecondary)
          }
        }
        .padding(DesignTokens.Spacing.space12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
      }
    }
  }

  private func smokeCard(_ observation: AirNowService.Observation) -> some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      sectionHeader("Air quality near fires")
      HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.space12) {
        Text("\(observation.aqi)")
          .font(DesignTokens.Typography.widgetTemp(40))
          .foregroundStyle(AirQualityCategory(usAQI: observation.aqi).color)
          .monospacedDigit()
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
          Text(observation.category)
            .font(DesignTokens.Typography.subsection())
            .foregroundStyle(DesignTokens.Palette.textPrimary)
          Text(observation.parameter.map { "AirNow \($0)" } ?? "AirNow")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
      }
      .padding(DesignTokens.Spacing.space16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .cardStyle()
    }
  }

  private func incidentRow(_ incident: FireIncident, miles: Double?) -> some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
      Text(incident.displayName)
        .font(DesignTokens.Typography.subsection())
        .foregroundStyle(DesignTokens.Palette.textPrimary)
      HStack(spacing: DesignTokens.Spacing.space8) {
        if let miles {
          Text(String(format: "%.0f mi", miles))
            .foregroundStyle(DesignTokens.Palette.accentWarm)
        }
        if let acres = incident.acres {
          Text(String(format: "%.0f acres", acres))
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
        if let contained = incident.percentContained {
          Text(String(format: "%.0f%% contained", contained))
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
      }
      .font(DesignTokens.Typography.caption())
    }
    .padding(DesignTokens.Spacing.space12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardStyle()
  }

  private func hotspotRow(_ spot: FireHotspot, miles: Double) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
        Text(String(format: "%.0f mi away", miles))
          .font(DesignTokens.Typography.subsection())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        if let frp = spot.frp {
          Text(String(format: "FRP %.1f · %@", frp, spot.confidence ?? "detection"))
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
      }
      Spacer()
      Image(systemName: "flame.fill")
        .foregroundStyle(DesignTokens.Palette.accentWarm)
    }
    .padding(DesignTokens.Spacing.space12)
    .cardStyle()
  }

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(DesignTokens.Typography.subsection())
      .foregroundStyle(DesignTokens.Palette.textTertiary)
      .tracking(DesignTokens.Typography.cardLabelTracking)
  }
}
