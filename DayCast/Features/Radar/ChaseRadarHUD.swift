import CoreLocation
import SwiftUI

// MARK: - Pure helpers (unit-tested)

/// Scan-age labels, alert shorthand, and urgency colors for the chase strip.
/// Kept free of SwiftUI so tests don't need a view host.
enum ChaseRadarHUDLogic {
  /// Site products update every few minutes; mosaics lag more. Thresholds in minutes.
  static func scanAgeMinutes(now: Date, scanDate: Date?) -> Int? {
    guard let scanDate else { return nil }
    return Int(now.timeIntervalSince(scanDate) / 60)
  }

  static func scanAgeLine(
    showsFuture: Bool,
    futureFrameLabel: String,
    ageMinutes: Int?
  ) -> String {
    if showsFuture { return "FUT \(futureFrameLabel)" }
    guard let age = ageMinutes else { return "SCAN —" }
    if age < 0 { return "SCAN now" }
    if age == 0 { return "SCAN <1m" }
    return "SCAN \(age)m"
  }

  /// Site products use tighter thresholds (5m warn / 10m stale) than composite mosaics
  /// (8m / 15m) because a 12-minute single-site scan is already next-cycle late.
  enum ScanFreshness {
    case fresh
    case aging
    case stale
    case unknown
    case future
  }

  static func scanFreshness(
    showsFuture: Bool,
    ageMinutes: Int?,
    isSiteProduct: Bool
  ) -> ScanFreshness {
    if showsFuture { return .future }
    guard let age = ageMinutes else { return .unknown }
    let warn = isSiteProduct ? 5 : 8
    let stale = isSiteProduct ? 10 : 15
    if age > stale { return .stale }
    if age > warn { return .aging }
    return .fresh
  }

  static func shortEvent(_ event: String) -> String {
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

  /// Life-threatening first, then covering polygons, then nearest by distance.
  static func nearestAlertLine(
    alerts: [NWSAlert],
    mapCenter: CLLocationCoordinate2D
  ) -> (text: String, isLifeThreatening: Bool, isCovering: Bool)? {
    if let covering = alerts.first(where: { $0.containsSelectedPoint }) {
      return (
        "IN \(shortEvent(covering.event))",
        covering.isLifeThreatening,
        true
      )
    }

    let origin = CLLocation(latitude: mapCenter.latitude, longitude: mapCenter.longitude)
    let ranked: [(NWSAlert, CLLocationDistance)] = alerts.compactMap { alert in
      guard let lat = alert.latitude, let lon = alert.longitude else { return nil }
      let meters = origin.distance(from: CLLocation(latitude: lat, longitude: lon))
      return (alert, meters)
    }
    .sorted { $0.1 < $1.1 }

    guard let best = ranked.first else { return nil }
    let miles = best.1 / 1609.344
    let milesText =
      miles < 10
      ? String(format: "≈%.1f mi", miles)
      : String(format: "≈%.0f mi", miles)
    return (
      "\(milesText) · \(shortEvent(best.0.event))",
      best.0.isLifeThreatening,
      false
    )
  }
}

// MARK: - View

/// Compact chase strip: scan age, site/product, coords, nearest alert, product + declutter.
struct ChaseRadarHUD: View {
  var radarState: RadarState
  let mapCenter: CLLocationCoordinate2D
  let alerts: [NWSAlert]
  let day1Summary: String?
  @Binding var isDecluttered: Bool

  /// Product chip currently loading site frames (DETAIL / SRV).
  @State private var busyProduct: RadarProduct?

  var body: some View {
    VStack(alignment: .trailing, spacing: 8) {
      // Tick often enough that SCAN age feels live in the field (was 30s).
      TimelineView(.periodic(from: .now, by: 10)) { context in
        if isDecluttered {
          declutteredStrip(at: context.date)
        } else {
          fullStrip(at: context.date)
        }
      }

      actionChips
    }
    .accessibilityElement(children: .contain)
  }

  // MARK: Layouts

  /// Field "MAP" mode: only safety-critical chrome + restore.
  private func declutteredStrip(at now: Date) -> some View {
    VStack(alignment: .trailing, spacing: 4) {
      Text(scanAgeLine(at: now))
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .foregroundStyle(scanAgeColor(at: now))

      if let alert = nearestAlertPresentation {
        Text(alert.text)
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(alertColor(alert))
          .lineLimit(1)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(cardBackground)
    .overlay(cardStroke(urgency: scanFreshness(at: now)))
  }

  private func fullStrip(at now: Date) -> some View {
    VStack(alignment: .trailing, spacing: 4) {
      Text(scanAgeLine(at: now))
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .foregroundStyle(scanAgeColor(at: now))

      Text(siteProductLine)
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(DesignTokens.Palette.radarTextPrimary)

      Text(coordLine)
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(DesignTokens.Palette.radarTextPrimary.opacity(0.75))

      if let alert = nearestAlertPresentation {
        Text(alert.text)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(alertColor(alert))
          .lineLimit(1)
      }

      if let day1Summary, !day1Summary.isEmpty {
        Text(day1Summary)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(DesignTokens.Palette.radarTextPrimary.opacity(0.7))
          .lineLimit(1)
      }

      if let message = radarState.siteProductUnavailableMessage {
        Text(message)
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(DesignTokens.Palette.warning)
          .multilineTextAlignment(.trailing)
          .lineLimit(2)
      } else if let note = radarState.siteProductAdvisory {
        Text(note)
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(DesignTokens.Palette.warning)
          .multilineTextAlignment(.trailing)
          .lineLimit(2)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(cardBackground)
    .overlay(cardStroke(urgency: scanFreshness(at: now)))
  }

  private var cardBackground: some View {
    RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
      .fill(DesignTokens.Palette.cardElevated)
      .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
  }

  private func cardStroke(urgency: ChaseRadarHUDLogic.ScanFreshness) -> some View {
    let color: Color = {
      switch urgency {
      case .stale: return DesignTokens.Palette.danger.opacity(0.85)
      case .aging: return DesignTokens.Palette.warning.opacity(0.70)
      default: return Color.white.opacity(0.22)
      }
    }()
    return RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
      .stroke(color, lineWidth: urgency == .stale || urgency == .aging ? 1.5 : 1)
  }

  // MARK: Action chips

  private var actionChips: some View {
    HStack(spacing: 8) {
      if isDecluttered {
        // Play without expanding the full bottom panel.
        Button {
          Haptic.selection()
          radarState.togglePlayback()
        } label: {
          Image(systemName: radarState.isAnimating ? "pause.fill" : "play.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(DesignTokens.Palette.radarAccent)
            .frame(width: 32, height: 28)
            .background(DesignTokens.Palette.radarCardBackground.opacity(0.92), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(radarState.isAnimating ? "Pause" : "Play")
      } else {
        productChip(
          .superResReflectivity,
          label: "DETAIL",
          a11yOn: "Exit detail rain",
          a11yOff: "Detail rain super-resolution"
        )
        productChip(
          .stormRelativeVelocity,
          label: "SRV",
          a11yOn: "Exit storm-relative velocity",
          a11yOff: "Storm-relative velocity"
        )
      }

      Button {
        Haptic.selection()
        withAnimation(.easeInOut(duration: 0.2)) {
          isDecluttered.toggle()
        }
      } label: {
        Text(isDecluttered ? "HUD" : "MAP")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(DesignTokens.Palette.radarTextPrimary)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(DesignTokens.Palette.radarCardBackground.opacity(0.92), in: Capsule())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(isDecluttered ? "Show radar controls" : "Declutter radar")
    }
  }

  private func productChip(
    _ product: RadarProduct,
    label: String,
    a11yOn: String,
    a11yOff: String
  ) -> some View {
    let isSelected = radarState.selectedProduct == product
    let isBusy = busyProduct == product
    let unavailable = radarState.showsFuture || radarState.nearestSite == nil

    return Button {
      Haptic.selection()
      Task { await toggleSiteProduct(product) }
    } label: {
      HStack(spacing: 4) {
        if isBusy {
          ProgressView()
            .controlSize(.mini)
            .tint(
              isSelected
                ? DesignTokens.Palette.radarCardBackground
                : DesignTokens.Palette.radarAccent
            )
        }
        Text(label)
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(
            isSelected
              ? DesignTokens.Palette.radarCardBackground
              : DesignTokens.Palette.radarAccent
          )
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(
        isSelected
          ? DesignTokens.Palette.radarAccent
          : DesignTokens.Palette.radarAccent.opacity(0.22),
        in: Capsule()
      )
    }
    .buttonStyle(.plain)
    .disabled(unavailable || busyProduct != nil)
    .opacity(unavailable ? 0.45 : 1)
    .accessibilityLabel(isSelected ? a11yOn : a11yOff)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private func toggleSiteProduct(_ product: RadarProduct) async {
    busyProduct = product
    defer { busyProduct = nil }
    if radarState.selectedProduct == product {
      await radarState.setProduct(.reflectivity)
    } else {
      await radarState.setProduct(product)
    }
  }

  // MARK: Derived text / color

  private func scanAgeLine(at now: Date) -> String {
    ChaseRadarHUDLogic.scanAgeLine(
      showsFuture: radarState.showsFuture,
      futureFrameLabel: radarState.currentFrameDisplayTime,
      ageMinutes: ChaseRadarHUDLogic.scanAgeMinutes(now: now, scanDate: scanFreshnessDate())
    )
  }

  private func scanFreshness(at now: Date) -> ChaseRadarHUDLogic.ScanFreshness {
    ChaseRadarHUDLogic.scanFreshness(
      showsFuture: radarState.showsFuture,
      ageMinutes: ChaseRadarHUDLogic.scanAgeMinutes(now: now, scanDate: scanFreshnessDate()),
      isSiteProduct: radarState.selectedProduct.isSiteProduct
    )
  }

  private func scanAgeColor(at now: Date) -> Color {
    switch scanFreshness(at: now) {
    case .future, .fresh: return DesignTokens.Palette.radarAccent
    case .aging: return DesignTokens.Palette.warning
    case .stale: return DesignTokens.Palette.danger
    case .unknown: return DesignTokens.Palette.radarTextPrimary.opacity(0.6)
    }
  }

  /// While Live is animating, report freshness of the newest volume — not the
  /// mid-loop frame the scrubber is briefly on (which incorrectly read as "41m").
  private func scanFreshnessDate() -> Date? {
    if radarState.isAnimating, !radarState.showsFuture,
      let newest = radarState.activeTimestamps.last
    {
      return newest
    }
    return radarState.currentFrameDate
  }

  private var siteProductLine: String {
    // shortCode, not displayName — "STORM WINDS" overflows the compact strip.
    let product = radarState.selectedProduct.shortCode
    // Prefer the site actually serving tiles (neighbor fallback) over nearest-only.
    if radarState.selectedProduct.isSiteProduct {
      if let serving = radarState.activeSiteProductSite {
        if let home = radarState.nearestSite, home.id != serving.id {
          return "\(serving.id) · \(product)*"
        }
        return "\(serving.id) · \(product)"
      }
      if let site = radarState.nearestSite {
        return "\(site.id) · \(product)"
      }
    }
    if radarState.showsFuture {
      let name = radarState.activeForecastProvider?.hudSourceLabel ?? "FORECAST"
      return "\(name) · \(product)"
    }
    let name = radarState.activeLiveProvider?.hudSourceLabel ?? "LIVE"
    return "\(name) · \(product)"
  }

  private var coordLine: String {
    String(format: "%.3f, %.3f", mapCenter.latitude, mapCenter.longitude)
  }

  private var nearestAlertPresentation:
    (text: String, isLifeThreatening: Bool, isCovering: Bool)?
  {
    ChaseRadarHUDLogic.nearestAlertLine(alerts: alerts, mapCenter: mapCenter)
  }

  private func alertColor(
    _ alert: (text: String, isLifeThreatening: Bool, isCovering: Bool)
  ) -> Color {
    if alert.isLifeThreatening || alert.isCovering {
      return DesignTokens.Palette.danger
    }
    return DesignTokens.Palette.warning
  }
}
