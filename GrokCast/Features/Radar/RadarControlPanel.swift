import CoreLocation
import SwiftUI

/// Composes playback controls, timeline scrubber, mode toggle, and opacity for the Mapbox radar tab.
struct RadarControlPanel: View {
  @Bindable var radarState: RadarState
  @Binding var opacity: Double
  @Binding var recenterDefaultTrigger: UUID?
  @Binding var recenterUserCoordinate: CLLocationCoordinate2D?

  @State private var autoResumeAfterScrub = true

  var body: some View {
    VStack(spacing: DesignTokens.Spacing.space8) {
      // Header matching previous panel style: title + badge + updated time
      HStack {
        Image(systemName: "cloud.rain.fill")
          .font(.caption)
          .foregroundStyle(DesignTokens.Palette.radarAccent)
        Text("Radar · \(radarState.selectedProduct.displayName)")
          .font(.caption.weight(.semibold))
          .foregroundStyle(DesignTokens.Palette.radarTextPrimary)

        Text(sourceBadgeText)
          .font(.caption2)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(DesignTokens.Palette.radarTrack)
          .clipShape(Capsule())
          .foregroundStyle(DesignTokens.Palette.radarTextSecondary)

        Spacer()

        if let updatedText {
          Text(updatedText)
            .font(.caption2)
            .foregroundStyle(DesignTokens.Palette.radarTextSecondary)
        }
      }

      RadarPlaybackControls(
        radarState: radarState,
        recenterDefaultTrigger: $recenterDefaultTrigger,
        recenterUserCoordinate: $recenterUserCoordinate
      )

      RadarTimelineScrubber(radarState: radarState)

      // Auto-resume toggle (restored from previous style)
      Toggle("Auto-resume after scrub", isOn: $radarState.autoResumeAfterScrub)
        .font(.caption2)
        .tint(DesignTokens.Palette.radarAccent)
        .padding(.horizontal, 4)

      // Mode selector for Live (NOW) vs Forecast (FUTURE / fradar) - this is the "future tab"
      HStack(spacing: 0) {
        Text("Live")
          .font(.caption2.weight(!radarState.showsFuture ? .semibold : .regular))
          .padding(.horizontal, 10)
          .padding(.vertical, 3)
          .background(!radarState.showsFuture ? DesignTokens.Palette.radarAccent.opacity(0.2) : Color.clear)
          .clipShape(Capsule())
          .foregroundStyle(!radarState.showsFuture ? DesignTokens.Palette.radarAccent : DesignTokens.Palette.radarTextSecondary)
          .onTapGesture { if radarState.hasFutureFrames { radarState.setFutureMode(false) } }

        Text("Forecast")
          .font(.caption2.weight(radarState.showsFuture ? .semibold : .regular))
          .padding(.horizontal, 10)
          .padding(.vertical, 3)
          .background(radarState.showsFuture ? DesignTokens.Palette.radarAccent.opacity(0.2) : Color.clear)
          .clipShape(Capsule())
          .foregroundStyle(radarState.showsFuture ? DesignTokens.Palette.radarAccent : DesignTokens.Palette.radarTextSecondary)
          .onTapGesture { if radarState.hasFutureFrames { radarState.setFutureMode(true) } }
      }
      .background(DesignTokens.Palette.radarTrack)
      .clipShape(Capsule())
      .disabled(!radarState.hasFutureFrames)

      Group {
        if showsVelocityLegend {
          velocityLegendPill
        } else {
          legendPill
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      // Product chips row (restored style: NQA, Reflectivity, Velocity, SRV)
      productChips

      // Color scheme toggle (Vibrant / Balanced) from previous panel
      colorSchemePicker

      opacityRow
      statusFooter
    }
    .padding(DesignTokens.Spacing.space12)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
    .animation(.easeInOut(duration: 0.25), value: radarState.isFutureMode)
    .animation(.easeInOut(duration: 0.25), value: radarState.isSwitchingMode)
  }

  private var productChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        // Resolved nearest NEXRAD site — lights up when a single-site product is active.
        if let site = radarState.nearestSite {
          chip(
            site.id, systemImage: "wifi",
            isSelected: radarState.selectedProduct.isSiteProduct
          ) {}
        }
        productChip(.reflectivity)
        productChip(.superResReflectivity)
        productChip(.stormRelativeVelocity)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func productChip(_ product: RadarProduct) -> some View {
    // Site products need a resolved US site and only exist for live scans.
    let enabled =
      !product.isSiteProduct
      || (radarState.siteProductsAvailable && !radarState.showsFuture)
    return chip(
      product.displayName, systemImage: nil,
      isSelected: radarState.selectedProduct == product
    ) {
      guard enabled else { return }
      Haptic.impact(.light)
      Task { await radarState.setProduct(product) }
    }
    .opacity(enabled ? 1 : 0.35)
  }

  private func chip(_ title: String, systemImage: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
    HStack(spacing: 4) {
      if let img = systemImage {
        Image(systemName: img)
          .font(.caption2)
      }
      Text(title)
        .font(.caption2.weight(isSelected ? .semibold : .regular))
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 4)
    .background(isSelected ? DesignTokens.Palette.radarAccent.opacity(0.2) : DesignTokens.Palette.radarTrack)
    .clipShape(Capsule())
    .overlay(
      Capsule()
        .stroke(DesignTokens.Palette.radarAccent, lineWidth: 1)
        .opacity(isSelected ? 1 : 0)
    )
    .foregroundStyle(isSelected ? DesignTokens.Palette.radarAccent : DesignTokens.Palette.radarTextSecondary)
    .onTapGesture(perform: action)
  }

  private var colorSchemePicker: some View {
    HStack(spacing: 0) {
      ForEach(RadarColorScheme.allCases, id: \.self) { scheme in
        let isSelected = radarState.colorScheme == scheme
        Text(scheme.displayName)
          .font(.caption2.weight(isSelected ? .semibold : .regular))
          .padding(.horizontal, 12)
          .padding(.vertical, 4)
          .background(isSelected ? DesignTokens.Palette.radarAccent.opacity(0.2) : Color.clear)
          .clipShape(Capsule())
          .foregroundStyle(
            isSelected ? DesignTokens.Palette.radarAccent : DesignTokens.Palette.radarTextSecondary
          )
          .onTapGesture {
            Haptic.impact(.light)
            radarState.colorScheme = scheme
          }
      }
    }
    .background(DesignTokens.Palette.radarTrack)
    .clipShape(Capsule())
  }

  private var headerRow: some View {
    HStack {
      Spacer()
      Text(radarState.currentFrameDisplayTime)
        .font(.caption.monospacedDigit())
        .foregroundStyle(DesignTokens.Palette.radarTextSecondary)
    }
  }

  /// Velocity products get a toward/away legend instead of the dBZ scale.
  private var showsVelocityLegend: Bool {
    radarState.selectedProduct.isVelocityProduct && !radarState.showsFuture
  }

  private var velocityLegendPill: some View {
    VStack(alignment: .leading, spacing: 4) {
      LinearGradient(
        colors: [
          DesignTokens.Palette.success, DesignTokens.Palette.radarTrack,
          DesignTokens.Palette.danger,
        ],
        startPoint: .leading, endPoint: .trailing
      )
      .frame(height: 8)
      .clipShape(RoundedRectangle(cornerRadius: 2))

      HStack {
        Text("Toward radar").font(.caption2)
          .foregroundStyle(DesignTokens.Palette.radarTextSecondary)
        Spacer()
        Text("Away from radar").font(.caption2)
          .foregroundStyle(DesignTokens.Palette.radarTextSecondary)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Radial velocity legend: green toward the radar, red away")
  }

  private var legendPill: some View {
    // Rich legend bar to match previous panel style
    VStack(alignment: .leading, spacing: 4) {
      // Gradient bar for reflectivity-like scale
      GeometryReader { geo in
        HStack(spacing: 0) {
          Rectangle().fill(DesignTokens.Palette.accentCool)     // Light
            .frame(width: geo.size.width * 0.25)
          Rectangle().fill(DesignTokens.Palette.warning)        // Moderate
            .frame(width: geo.size.width * 0.25)
          Rectangle().fill(DesignTokens.Palette.accentWarm)     // Heavy
            .frame(width: geo.size.width * 0.25)
          Rectangle().fill(DesignTokens.Palette.danger)         // Extreme
            .frame(width: geo.size.width * 0.25)
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .overlay(
          HStack {
            ForEach([10, 20, 30, 40, 50, 60, 70], id: \.self) { val in
              Spacer()
              Text("\(val)")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(DesignTokens.Palette.radarTextSecondary)
            }
            Spacer()
          }
          .padding(.horizontal, 2)
        )
      }
      .frame(height: 8)

      HStack {
        Text("Light").font(.caption2).foregroundStyle(DesignTokens.Palette.radarTextSecondary)
        Spacer()
        Text("Moderate").font(.caption2).foregroundStyle(DesignTokens.Palette.radarTextSecondary)
        Spacer()
        Text("Heavy").font(.caption2).foregroundStyle(DesignTokens.Palette.radarTextSecondary)
        Spacer()
        Text("Extreme").font(.caption2).foregroundStyle(DesignTokens.Palette.radarTextSecondary)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Precipitation intensity legend with dBZ scale")
  }

  /// Real active tile source for the current mode (replaces the old hardcoded badge).
  private var sourceBadgeText: String {
    if !radarState.showsFuture, radarState.selectedProduct.isSiteProduct,
      let site = radarState.nearestSite
    {
      return "NWS \(site.id)"
    }
    let provider =
      radarState.showsFuture
      ? radarState.activeForecastProvider
      : radarState.activeLiveProvider
    return provider?.displayName ?? "No source"
  }

  /// Freshness of the newest live radar frame; nil until frames load.
  private var updatedText: String? {
    guard let latest = radarState.timeline.live.last?.timestamp else { return nil }
    let minutes = Int(-latest.timeIntervalSinceNow / 60)
    if minutes < 1 { return "Updated just now" }
    if minutes < 60 { return "Updated \(minutes) min. ago" }
    return "Updated \(minutes / 60)h ago"
  }

  private var showsFutureUnavailableHint: Bool {
    radarState.hasFutureFrames
      && radarState.futureUnavailableMessage != nil
      && !radarState.isFutureMode
      && !radarState.isSwitchingMode
  }

  private var modePicker: some View {
    VStack(alignment: .trailing, spacing: DesignTokens.Spacing.space4) {
      Picker(
        "Mode",
        selection: Binding(
          get: { radarState.pickerShowsFuture },
          set: { radarState.setFutureMode($0) }
        )
      ) {
        Text("NOW").tag(false)
        Text("FUTURE").tag(true)
          .disabled(!radarState.hasFutureFrames)
      }
      .pickerStyle(.segmented)
      .frame(width: 140)
      .disabled(!radarState.hasFutureFrames || radarState.isSwitchingMode)

      if showsFutureUnavailableHint, let message = radarState.futureUnavailableMessage {
        Text(message)
          .font(.caption2)
          .foregroundStyle(.orange)
          .multilineTextAlignment(.trailing)
          .frame(maxWidth: 140, alignment: .trailing)
      }
    }
  }

  private var opacityRow: some View {
    HStack {
      Image(systemName: "eye")
      Slider(value: $opacity, in: 0.3...1.0, step: 0.1)
      Text(String(format: "%.0f%%", opacity * 100))
        .font(.caption2.monospacedDigit())
        .frame(width: 40)
    }
  }

  @ViewBuilder
  private var statusFooter: some View {
    let footer = radarState.statusFooterContent
    switch footer.style {
    case .loading:
      HStack(spacing: DesignTokens.Spacing.space8) {
        ProgressView()
          .controlSize(.small)
        Text(footer.text)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    case .secondary:
      Text(footer.text)
        .font(.caption2)
        .foregroundStyle(.secondary)
    case .warning:
      Text(footer.text)
        .font(.caption2)
        .foregroundStyle(.orange)
    case .error:
      Text(footer.text)
        .font(.caption2)
        .foregroundStyle(.red)
    }

    Text("Tap map to explore • Pinch to zoom")
      .font(.caption2)
      .foregroundStyle(.secondary)
  }
}
