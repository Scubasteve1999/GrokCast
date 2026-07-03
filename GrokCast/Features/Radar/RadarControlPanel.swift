import CoreLocation
import SwiftUI

/// Composes playback controls, timeline scrubber, mode toggle, and opacity for the Mapbox radar tab.
struct RadarControlPanel: View {
  @Environment(WeatherStore.self) private var store
  @Bindable var radarState: RadarState
  @Binding var opacity: Double
  @Binding var recenterDefaultTrigger: UUID?
  @Binding var recenterUserCoordinate: CLLocationCoordinate2D?

  @State private var showExplainRadar = false
  @State private var showDisplayOptions = false
  /// Collapsed shows only playback + scrubber; expanded adds mode/product chips.
  @State private var isCollapsed = true

  var body: some View {
    VStack(spacing: DesignTokens.Spacing.space8) {
      collapseHandle

      // Header: title + source + actions
      HStack(spacing: DesignTokens.Spacing.space8) {
        Image(systemName: "cloud.rain.fill")
          .font(.caption)
          .foregroundStyle(DesignTokens.Palette.radarAccent)
        Text("Radar · \(radarState.selectedProduct.displayName)")
          .font(.caption.weight(.semibold))
          .foregroundStyle(DesignTokens.Palette.radarTextPrimary)
          .lineLimit(1)

        Text(sourceBadgeText)
          .font(.caption2)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(DesignTokens.Palette.radarTrack)
          .clipShape(Capsule())
          .foregroundStyle(DesignTokens.Palette.radarTextSecondary)
          .lineLimit(1)

        Spacer(minLength: 0)

        Button {
          Haptic.impact(.light)
          showDisplayOptions = true
        } label: {
          Image(systemName: "slider.horizontal.3")
            .font(.caption.weight(.semibold))
            .foregroundStyle(DesignTokens.Palette.radarTextSecondary)
        }
        .accessibilityLabel("Radar display options")

        Button {
          Haptic.impact(.light)
          showExplainRadar = true
        } label: {
          Image(systemName: "sparkles")
            .font(.caption.weight(.semibold))
            .foregroundStyle(DesignTokens.Palette.radarAccent)
        }
        .accessibilityLabel("Explain radar with Grok")
      }

      if let updatedText {
        HStack {
          Text(updatedText)
            .font(.caption2)
            .foregroundStyle(DesignTokens.Palette.radarTextSecondary)
          Spacer()
        }
      }

      RadarPlaybackControls(
        radarState: radarState,
        recenterDefaultTrigger: $recenterDefaultTrigger,
        recenterUserCoordinate: $recenterUserCoordinate
      )

      RadarTimelineScrubber(radarState: radarState)

      if !isCollapsed {
        liveForecastPicker
        productChips
        compactStatusFooter
      }
    }
    .padding(DesignTokens.Spacing.space12)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
    .animation(.easeInOut(duration: 0.25), value: radarState.isFutureMode)
    .animation(.easeInOut(duration: 0.25), value: radarState.isSwitchingMode)
    .sheet(isPresented: $showDisplayOptions) {
      RadarDisplayOptionsSheet(
        radarState: radarState,
        opacity: $opacity
      )
    }
    .sheet(isPresented: $showExplainRadar) {
      ExplainRadarSheet(
        context: RadarExplainContext(
          modeLabel: radarState.showsFuture ? "Forecast" : "Live",
          frameLabel: currentFrameLabel,
          productName: radarState.selectedProduct.displayName,
          locationName: store.currentLocation?.name ?? "Map"
        )
      )
    }
  }

  private var currentFrameLabel: String {
    let labels = radarState.activeFrameLabels
    let index = max(0, min(radarState.currentIndex, max(0, labels.count - 1)))
    guard index < labels.count else { return "Now" }
    return labels[index]
  }

  /// Grabber + chevron that collapses the panel down to just the playback
  /// controls + scrubber, freeing the lower half of the map. Full-width tap
  /// target so it's easy to hit.
  private var collapseHandle: some View {
    Button {
      Haptic.impact(.light)
      withAnimation(.easeInOut(duration: 0.25)) { isCollapsed.toggle() }
    } label: {
      ZStack {
        Capsule()
          .fill(DesignTokens.Palette.radarTextSecondary.opacity(0.4))
          .frame(width: 36, height: 5)
        HStack {
          Spacer()
          Image(systemName: isCollapsed ? "chevron.up" : "chevron.down")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(DesignTokens.Palette.radarTextSecondary)
        }
      }
      .frame(maxWidth: .infinity, minHeight: 16)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(isCollapsed ? "Expand radar controls" : "Collapse radar controls")
  }

  private var liveForecastPicker: some View {
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
  }

  @ViewBuilder
  private var compactStatusFooter: some View {
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
    case .warning:
      Text(footer.text)
        .font(.caption2)
        .foregroundStyle(.orange)
    case .error:
      Text(footer.text)
        .font(.caption2)
        .foregroundStyle(.red)
    case .secondary:
      EmptyView()
    }
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
}

// MARK: - Display options sheet (legend, map, opacity — kept off the main panel)

private struct RadarDisplayOptionsSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var radarState: RadarState
  @Binding var opacity: Double

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle("Auto-resume after scrub", isOn: $radarState.autoResumeAfterScrub)
        }

        Section("Colors") {
          Picker("Palette", selection: $radarState.colorScheme) {
            ForEach(RadarColorScheme.allCases, id: \.self) { scheme in
              Text(scheme.displayName).tag(scheme)
            }
          }
          .pickerStyle(.segmented)
        }

        Section("Legend") {
          if showsVelocityLegend {
            velocityLegend
          } else {
            reflectivityLegend
          }
        }

        Section("Map") {
          Toggle("Radar overlay", isOn: $radarState.showRadarOverlay)
          Picker("Base map", selection: $radarState.baseMapStyle) {
            ForEach(RadarBaseMapStyle.allCases) { style in
              Label(style.displayName, systemImage: style.systemImage).tag(style)
            }
          }
        }

        Section("Opacity") {
          HStack {
            Slider(value: $opacity, in: 0.3...1.0, step: 0.1)
            Text(String(format: "%.0f%%", opacity * 100))
              .font(.caption.monospacedDigit())
              .foregroundStyle(.secondary)
              .frame(width: 40)
          }
        }
      }
      .navigationTitle("Display")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private var showsVelocityLegend: Bool {
    radarState.selectedProduct.isVelocityProduct && !radarState.showsFuture
  }

  private var velocityLegend: some View {
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
      .accessibilityLabel("Velocity legend: green toward radar, red away from radar")

      HStack {
        Text("Toward radar").font(.caption2).foregroundStyle(.secondary)
        Spacer()
        Text("Away from radar").font(.caption2).foregroundStyle(.secondary)
      }
    }
  }

  private var reflectivityLegend: some View {
    VStack(alignment: .leading, spacing: 4) {
      GeometryReader { geo in
        HStack(spacing: 0) {
          Rectangle().fill(DesignTokens.Palette.accentCool)
            .frame(width: geo.size.width * 0.25)
          Rectangle().fill(DesignTokens.Palette.warning)
            .frame(width: geo.size.width * 0.25)
          Rectangle().fill(DesignTokens.Palette.accentWarm)
            .frame(width: geo.size.width * 0.25)
          Rectangle().fill(DesignTokens.Palette.danger)
            .frame(width: geo.size.width * 0.25)
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
      }
      .frame(height: 8)
      .accessibilityLabel("Reflectivity legend: light to extreme precipitation intensity")

      HStack {
        Text("Light").font(.caption2).foregroundStyle(.secondary)
        Spacer()
        Text("Moderate").font(.caption2).foregroundStyle(.secondary)
        Spacer()
        Text("Heavy").font(.caption2).foregroundStyle(.secondary)
        Spacer()
        Text("Extreme").font(.caption2).foregroundStyle(.secondary)
      }
    }
  }
}
