import CoreLocation
import SwiftUI

// MARK: - Pure helpers (unit-tested)

/// Scan-age labels, spoken warning names, and urgency colors for the chase strip.
/// Kept free of SwiftUI so tests don't need a view host.
enum ChaseRadarHUDLogic {
  /// Site products update every few minutes; mosaics lag more. Thresholds in minutes.
  static func scanAgeMinutes(now: Date, scanDate: Date?) -> Int? {
    guard let scanDate else { return nil }
    return Int(now.timeIntervalSince(scanDate) / 60)
  }

  /// SCAN / stale keys off the newest live volume, not the scrubbed frame.
  /// Play history is ~1h; HUD freshness is whether now is current.
  static func scanDateForDisplay(
    currentFrameDate: Date?,
    newestTimestamp: Date?,
    isAnimating: Bool,
    showsFuture: Bool
  ) -> Date? {
    _ = isAnimating
    if showsFuture { return currentFrameDate }
    return newestTimestamp ?? currentFrameDate
  }

  static func scanAgeLine(
    showsFuture: Bool,
    futureFrameLabel: String,
    ageMinutes: Int?
  ) -> String {
    if showsFuture { return "24-hr \(futureFrameLabel)" }
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

  /// NWS event as a person would say it. Warning vs watch stays; no TOR/SVR teletype.
  static func shortEvent(_ event: String) -> String {
    let trimmed = event.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = trimmed.lowercased()
    if lower.contains("tornado warning") { return "Tornado Warning" }
    if lower.contains("tornado watch") { return "Tornado Watch" }
    if lower.contains("severe thunderstorm warning") { return "Severe Thunderstorm Warning" }
    if lower.contains("severe thunderstorm watch") { return "Severe Thunderstorm Watch" }
    if lower.contains("flash flood warning") { return "Flash Flood Warning" }
    if lower.contains("flash flood watch") { return "Flash Flood Watch" }
    if lower.contains("special weather") { return "Special Weather Statement" }
    return trimmed
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

  /// City before the comma so the strip stays one line. Empty → “This location”.
  static func hudCityLine(locationName: String?) -> String {
    guard let raw = locationName?.trimmingCharacters(in: .whitespacesAndNewlines),
      !raw.isEmpty
    else {
      return "This location"
    }
    if let comma = raw.firstIndex(of: ",") {
      let city = raw[..<comma].trimmingCharacters(in: .whitespaces)
      if !city.isEmpty { return String(city) }
    }
    return raw
  }

  /// What the map is showing. Site product is "Site Doppler"; NQA etc. is
  /// secondary (`lookingAtSiteSecondary`). National radar never says Mosaic.
  static func lookingAtLine(
    product: RadarProduct,
    showsFuture: Bool,
    siteID: String? = nil
  ) -> String {
    _ = siteID
    if showsFuture { return "24-hr · \(product.displayName)" }
    return product.displayName
  }

  /// IEM site id under Site Doppler (NQA). Nil for National radar / SRV.
  static func lookingAtSiteSecondary(
    product: RadarProduct,
    showsFuture: Bool,
    siteID: String?
  ) -> String? {
    guard !showsFuture, product == .superResReflectivity,
      let siteID, !siteID.isEmpty
    else { return nil }
    return siteID
  }
}

// MARK: - View

/// Compact strip: SCAN age, city, what you’re looking at, nearest alert.
struct ChaseRadarHUD: View {
  var radarState: RadarState
  let mapCenter: CLLocationCoordinate2D
  var cityName: String?
  let alerts: [NWSAlert]
  let day1Summary: String?
  @Binding var isDecluttered: Bool

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

      // Map-only slims this strip to SCAN. The Live/24-hr sheet stays up.
    }
    .accessibilityElement(children: .contain)
  }

  // MARK: Layouts

  /// Field "MAP" mode: only safety-critical chrome + restore.
  private func declutteredStrip(at now: Date) -> some View {
    VStack(alignment: .trailing, spacing: 4) {
      Text(scanAgeLine(at: now))
        .font(DesignTokens.Typography.micro().monospaced())
        .foregroundStyle(scanAgeColor(at: now))

      if let alert = nearestAlertPresentation {
        Text(alert.text)
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(alertColor(alert))
          .multilineTextAlignment(.trailing)
          .lineLimit(2)
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
        .font(DesignTokens.Typography.micro().monospaced())
        .foregroundStyle(scanAgeColor(at: now))

      Text(ChaseRadarHUDLogic.hudCityLine(locationName: cityName))
        .font(DesignTokens.Typography.micro())
        .foregroundStyle(DesignTokens.Palette.radarTextPrimary)
        .lineLimit(1)

      Text(
        ChaseRadarHUDLogic.lookingAtLine(
          product: radarState.selectedProduct,
          showsFuture: radarState.showsFuture,
          siteID: radarState.activeSiteProductSite?.id ?? radarState.nearestSite?.id
        )
      )
      .font(DesignTokens.Typography.micro())
      .foregroundStyle(DesignTokens.Palette.radarTextPrimary.opacity(0.85))
      .lineLimit(1)

      if let siteID = ChaseRadarHUDLogic.lookingAtSiteSecondary(
        product: radarState.selectedProduct,
        showsFuture: radarState.showsFuture,
        siteID: radarState.activeSiteProductSite?.id ?? radarState.nearestSite?.id
      ) {
        Text(siteID)
          .font(DesignTokens.Typography.micro().monospaced())
          .foregroundStyle(DesignTokens.Palette.radarTextPrimary.opacity(0.62))
          .lineLimit(1)
      }

      if let alert = nearestAlertPresentation {
        Text(alert.text)
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(alertColor(alert))
          .multilineTextAlignment(.trailing)
          .lineLimit(2)
      }

      if let day1Summary, !day1Summary.isEmpty {
        Text(day1Summary)
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(DesignTokens.Palette.radarTextPrimary.opacity(0.7))
          .lineLimit(1)
      }

      if let message = radarState.siteProductUnavailableMessage {
        Text(message)
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(DesignTokens.Palette.warning)
          .multilineTextAlignment(.trailing)
          .lineLimit(2)
      } else if let note = radarState.siteProductAdvisory {
        Text(note)
          .font(DesignTokens.Typography.micro())
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
      .fill(
        LinearGradient(
          colors: [
            DesignTokens.Palette.cardElevated.opacity(0.96),
            DesignTokens.Palette.cardBackground.opacity(0.93),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .overlay(
        RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
          .stroke(
            LinearGradient(
              colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: DesignTokens.Card.strokeWidth
          )
      )
      .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
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

  private func scanFreshnessDate() -> Date? {
    ChaseRadarHUDLogic.scanDateForDisplay(
      currentFrameDate: radarState.currentFrameDate,
      newestTimestamp: radarState.activeTimestamps.last,
      isAnimating: radarState.isAnimating,
      showsFuture: radarState.showsFuture
    )
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
