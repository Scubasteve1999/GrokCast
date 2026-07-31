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
            .font(DesignTokens.Figma.Typography.subsectionLabel)
            .foregroundStyle(DesignTokens.Palette.accentWarm)
            .textCase(.uppercase)
            .tracking(DesignTokens.Typography.cardLabelTracking)
            .labelStyle(.titleAndIcon)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }

        Text(summary.title)
          .font(.title3.weight(.semibold))
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .lineLimit(2)

        Text(summary.subtitle)
          .font(.subheadline)
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
      .font(.caption.weight(.medium))
      .foregroundStyle(DesignTokens.Palette.accentWarm.opacity(0.95))
      .labelStyle(.titleAndIcon)
  }
}

struct FireDetailView: View {
  let snapshot: FireSnapshot
  let origin: CLLocationCoordinate2D?
  let fireWeatherAlerts: [NWSAlert]

  @State private var smokeObservation: AirNowService.Observation?
  @State private var didLoadSmoke = false

  private var rankedIncidents: [(FireIncident, Double?)] {
    guard let origin else {
      return snapshot.incidents.map { ($0, nil) }
    }
    return snapshot.incidents
      .map { incident -> (FireIncident, Double?) in
        guard let coordinate = incident.coordinate else { return (incident, nil) }
        return (incident, FireProximityDedupe.distanceMiles(from: origin, to: coordinate))
      }
      .sorted { lhs, rhs in
        switch (lhs.1, rhs.1) {
        case let (l?, r?): return l < r
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): return lhs.0.displayName < rhs.0.displayName
        }
      }
  }

  private var rankedHotspots: [(FireHotspot, Double)] {
    guard let origin else { return [] }
    return snapshot.hotspots
      .map { ($0, FireProximityDedupe.distanceMiles(from: origin, to: $0.coordinate)) }
      .sorted { $0.1 < $1.1 }
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
          sectionHeader("Incidents")
          ForEach(rankedIncidents.prefix(12), id: \.0.id) { item in
            incidentRow(item.0, miles: item.1)
          }
        }

        if !rankedHotspots.isEmpty {
          sectionHeader("Satellite heat detections")
          ForEach(rankedHotspots.prefix(20), id: \.0.id) { item in
            hotspotRow(item.0, miles: item.1)
          }
        }

        if rankedIncidents.isEmpty && rankedHotspots.isEmpty && fireWeatherAlerts.isEmpty {
          Text("No active fire data for this location right now.")
            .font(.body)
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }

        Text(
          "Hotspots from NASA FIRMS; incidents from NIFC. Red Flag warnings come from NWS."
        )
        .font(.footnote)
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
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(DesignTokens.Palette.accentWarm)
          if let headline = alert.headline, !headline.isEmpty {
            Text(headline)
              .font(.caption)
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
          .font(.system(size: 40, weight: .bold, design: .rounded))
          .foregroundStyle(AirQualityCategory(usAQI: observation.aqi).color)
          .monospacedDigit()
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
          Text(observation.category)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(DesignTokens.Palette.textPrimary)
          Text(observation.parameter.map { "AirNow \($0)" } ?? "AirNow")
            .font(.caption)
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
        .font(.subheadline.weight(.semibold))
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
      .font(.caption)
    }
    .padding(DesignTokens.Spacing.space12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardStyle()
  }

  private func hotspotRow(_ spot: FireHotspot, miles: Double) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space2) {
        Text(String(format: "%.0f mi away", miles))
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        if let frp = spot.frp {
          Text(String(format: "FRP %.1f · %@", frp, spot.confidence ?? "detection"))
            .font(.caption)
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
      .font(DesignTokens.Figma.Typography.subsectionLabel)
      .foregroundStyle(DesignTokens.Palette.textTertiary)
      .textCase(.uppercase)
      .tracking(DesignTokens.Typography.cardLabelTracking)
  }
}
