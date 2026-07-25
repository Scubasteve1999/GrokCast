import CoreLocation
import SwiftUI

/// Compact chase strip: scan age, site/product, coords, nearest alert, declutter + SRV.
struct ChaseRadarHUD: View {
  var radarState: RadarState
  let mapCenter: CLLocationCoordinate2D
  let alerts: [NWSAlert]
  let day1Summary: String?
  @Binding var isDecluttered: Bool

  var body: some View {
    VStack(alignment: .trailing, spacing: 8) {
      VStack(alignment: .trailing, spacing: 4) {
        Text(scanAgeLine)
          .font(.system(size: 11, weight: .bold, design: .monospaced))
          .foregroundStyle(scanAgeColor)

        Text(siteProductLine)
          .font(.system(size: 11, weight: .semibold, design: .monospaced))
          .foregroundStyle(DesignTokens.Palette.radarTextPrimary)

        Text(coordLine)
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundStyle(DesignTokens.Palette.radarTextPrimary.opacity(0.75))

        if let alertLine = nearestAlertLine {
          Text(alertLine)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(DesignTokens.Palette.warning)
            .lineLimit(1)
        }

        if let day1Summary, !day1Summary.isEmpty {
          Text(day1Summary)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(DesignTokens.Palette.radarTextPrimary.opacity(0.7))
            .lineLimit(1)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(DesignTokens.Palette.radarCardBackground.opacity(0.92), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(DesignTokens.Palette.radarAccent.opacity(0.28), lineWidth: 1)
      )

      HStack(spacing: 8) {
        Button {
          Haptic.selection()
          Task { await radarState.setProduct(.stormRelativeVelocity) }
        } label: {
          Text("SRV")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(
              radarState.selectedProduct == .stormRelativeVelocity
                ? DesignTokens.Palette.radarCardBackground
                : DesignTokens.Palette.radarAccent
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
              radarState.selectedProduct == .stormRelativeVelocity
                ? DesignTokens.Palette.radarAccent
                : DesignTokens.Palette.radarAccent.opacity(0.22),
              in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .disabled(radarState.showsFuture || radarState.nearestSite == nil)
        .opacity(radarState.showsFuture || radarState.nearestSite == nil ? 0.45 : 1)

        Button {
          Haptic.selection()
          withAnimation(.easeInOut(duration: 0.2)) {
            isDecluttered.toggle()
          }
        } label: {
          Image(systemName: isDecluttered ? "eye" : "eye.slash")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(DesignTokens.Palette.radarTextPrimary)
            .padding(8)
            .background(DesignTokens.Palette.radarCardBackground.opacity(0.92), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isDecluttered ? "Show radar controls" : "Declutter radar")
      }
    }
    .accessibilityElement(children: .contain)
  }

  private var scanAgeLine: String {
    if radarState.showsFuture {
      return "FUT \(radarState.currentFrameDisplayTime)"
    }
    guard let date = radarState.currentFrameDate else { return "SCAN —" }
    let age = Int(Date().timeIntervalSince(date) / 60)
    if age < 0 { return "SCAN now" }
    if age == 0 { return "SCAN <1m" }
    return "SCAN \(age)m"
  }

  private var scanAgeColor: Color {
    if radarState.showsFuture { return DesignTokens.Palette.radarAccent }
    guard let date = radarState.currentFrameDate else {
      return DesignTokens.Palette.radarTextPrimary.opacity(0.6)
    }
    let age = Date().timeIntervalSince(date) / 60
    if age > 15 { return DesignTokens.Palette.danger }
    if age > 8 { return DesignTokens.Palette.warning }
    return DesignTokens.Palette.radarAccent
  }

  private var siteProductLine: String {
    let product = radarState.selectedProduct.displayName.uppercased()
    if let site = radarState.nearestSite {
      return "\(site.id) · \(product)"
    }
    return product
  }

  private var coordLine: String {
    String(format: "%.3f, %.3f", mapCenter.latitude, mapCenter.longitude)
  }

  private var nearestAlertLine: String? {
    let origin = CLLocation(latitude: mapCenter.latitude, longitude: mapCenter.longitude)
    let ranked: [(NWSAlert, CLLocationDistance)] = alerts.compactMap { alert in
      guard let lat = alert.latitude, let lon = alert.longitude else { return nil }
      let meters = origin.distance(from: CLLocation(latitude: lat, longitude: lon))
      return (alert, meters)
    }
    .sorted { $0.1 < $1.1 }

    if let best = ranked.first {
      let miles = best.1 / 1609.344
      let milesText =
        miles < 10
        ? String(format: "%.1f mi", miles)
        : String(format: "%.0f mi", miles)
      let short = Self.shortEvent(best.0.event)
      if best.0.containsSelectedPoint {
        return "IN \(short)"
      }
      return "\(milesText) · \(short)"
    }

    if let local = alerts.first(where: { $0.containsSelectedPoint }) {
      return "IN \(Self.shortEvent(local.event))"
    }
    return nil
  }

  private static func shortEvent(_ event: String) -> String {
    let lower = event.lowercased()
    if lower.contains("tornado warning") { return "TOR WARN" }
    if lower.contains("tornado watch") { return "TOR WATCH" }
    if lower.contains("severe thunderstorm warning") { return "SVR WARN" }
    if lower.contains("severe thunderstorm watch") { return "SVR WATCH" }
    if lower.contains("flash flood warning") { return "FF WARN" }
    if lower.contains("flash flood watch") { return "FF WATCH" }
    if lower.contains("special weather") { return "SPS" }
    let words = event.split(separator: " ").prefix(2).joined(separator: " ")
    return words.uppercased()
  }
}
