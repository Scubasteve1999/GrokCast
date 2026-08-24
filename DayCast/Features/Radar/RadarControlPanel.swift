import CoreLocation
import SwiftUI

/// Composes playback controls, timeline scrubber, mode toggle, and opacity for the Mapbox radar tab.
struct RadarControlPanel: View {
  @Environment(WeatherStore.self) private var store
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Bindable var radarState: RadarState
  @Binding var opacity: Double
  @Binding var recenterDefaultTrigger: UUID?
  @Binding var recenterUserCoordinate: CLLocationCoordinate2D?
  @Binding var isDecluttered: Bool

  @State private var showExplainRadar = false
  @State private var showDisplayOptions = false
  /// Collapsed shows only playback + scrubber; expanded adds mode/product chips.
  @State private var isCollapsed = true
  /// User-driven Advanced disclosure; SRV also forces it open.
  @State private var advancedManuallyExpanded = false
  /// Mirrors RadarTipStore so dismissing re-renders without touching UserDefaults on every pass.
  @State private var dismissedTips: Set<RadarProduct> = Set(
    RadarProduct.allCases.filter { RadarTipStore.isDismissed($0) }
  )

  private var prefersFigmaHUD: Bool {
    horizontalSizeClass == .compact
  }

  var body: some View {
    VStack(spacing: DesignTokens.Spacing.space8) {
      slimModeRow
      RadarTimelineScrubber(radarState: radarState, layout: prefersFigmaHUD ? .figma : .standard)
      compactPlaybackRow
      compactStatusFooter
    }
    .padding(DesignTokens.Spacing.space12)
    .glassCardStyle(cornerRadius: DesignTokens.Card.cornerRadiusMedium)
    .animation(.easeInOut(duration: 0.25), value: radarState.isFutureMode)
    .animation(.easeInOut(duration: 0.25), value: radarState.isSwitchingMode)
    .sheet(isPresented: $showDisplayOptions) {
      RadarDisplayOptionsSheet(
        radarState: radarState,
        opacity: $opacity,
        isDecluttered: $isDecluttered,
        onExplain: {
          showDisplayOptions = false
          showExplainRadar = true
        }
      )
    }
    .sheet(isPresented: $showExplainRadar) {
      ExplainRadarSheet(
        context: RadarExplainContext(
          modeLabel: radarState.showsFuture ? RadarChromeCopy.futureChip : RadarChromeCopy.liveChip,
          frameLabel: currentFrameLabel,
          productName: radarState.selectedProduct.displayName,
          productTechnicalName: radarState.selectedProduct.technicalName,
          locationName: store.currentLocation?.name
            ?? store.displayedWeather?.location.name ?? "Map",
          locationID: store.currentLocation?.id,
          conditionText: store.displayedWeather?.conditionText,
          precipitationChance: store.displayedWeather?.precipitationChance
        )
      )
      .environment(store)
    }
  }

  /// One mode row: Live / 24-hr plus Layers. Advanced products live in the sheet.
  private var slimModeRow: some View {
    HStack(spacing: DesignTokens.Spacing.space8) {
      liveForecastPicker
      Spacer(minLength: 0)
      Button {
        Haptic.impact(.light)
        showDisplayOptions = true
      } label: {
        HStack(spacing: 4) {
          Image(systemName: "slider.horizontal.3")
            .font(DesignTokens.Typography.micro())
          Text(RadarChromeCopy.layers)
            .font(DesignTokens.Typography.micro())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(DesignTokens.Palette.radarTrack)
        .clipShape(Capsule())
        .foregroundStyle(DesignTokens.Palette.radarTextSecondary)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(RadarChromeCopy.layers)
    }
  }

  private var compactPlaybackRow: some View {
    HStack(spacing: DesignTokens.Spacing.space8) {
      Button {
        radarState.togglePlayback()
      } label: {
        Image(systemName: radarState.isAnimating ? "pause.fill" : "play.fill")
          .font(DesignTokens.Typography.headline())
          .foregroundStyle(DesignTokens.Palette.radarAccent)
          .frame(minWidth: 28, minHeight: 28)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(radarState.isAnimating ? "Pause" : "Play")

      Text(radarState.currentFrameDisplayTime)
        .font(DesignTokens.Typography.caption().monospacedDigit())
        .foregroundStyle(DesignTokens.Palette.radarTextSecondary)
        .lineLimit(1)

      Spacer(minLength: 4)

      RadarPlaybackSpeedPicker(radarState: radarState)

      Button {
        Haptic.impact(.light)
        // Selected weather location — same as iPad house button (not device GPS).
        recenterUserCoordinate = nil
        recenterDefaultTrigger = UUID()
      } label: {
        Image(systemName: "house.fill")
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.radarAccent)
          .frame(width: 28, height: 28)
          .background(DesignTokens.Palette.radarTrack)
          .clipShape(Capsule())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Recenter to selected location")
    }
  }

  /// Opacity used to live only in the Display sheet — on phone that buried the
  /// control people tweak every session. Dim when the overlay is off.
  private var compactOpacityRow: some View {
    HStack(spacing: DesignTokens.Spacing.space8) {
      Image(systemName: "circle.lefthalf.filled")
        .font(DesignTokens.Typography.micro())
        .foregroundStyle(DesignTokens.Palette.radarTextSecondary)
        .accessibilityHidden(true)

      Slider(
        value: $opacity,
        in: RadarPreferences.radarOpacityRange,
        step: 0.05
      )
      .tint(DesignTokens.Palette.radarAccent)
      .disabled(!radarState.showRadarOverlay)
      .opacity(radarState.showRadarOverlay ? 1 : 0.4)
      .accessibilityLabel("Radar opacity")
      .accessibilityValue("\(Int((opacity * 100).rounded())) percent")

      Text(String(format: "%.0f%%", opacity * 100))
        .font(DesignTokens.Typography.micro().monospacedDigit())
        .foregroundStyle(DesignTokens.Palette.radarTextSecondary)
        .frame(width: 36, alignment: .trailing)
        .accessibilityHidden(true)
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
          Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
            .font(DesignTokens.Typography.micro())
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
      Button {
        guard radarState.hasFutureFrames else { return }
        radarState.setFutureMode(false)
      } label: {
        Text(RadarChromeCopy.liveChip)
          .font(DesignTokens.Typography.micro())
          .padding(.horizontal, 10)
          .padding(.vertical, 3)
          .background(
            !radarState.showsFuture ? DesignTokens.Palette.radarAccent.opacity(0.2) : Color.clear
          )
          .clipShape(Capsule())
          .foregroundStyle(
            !radarState.showsFuture
              ? DesignTokens.Palette.radarAccent : DesignTokens.Palette.radarTextSecondary
          )
      }
      .buttonStyle(.plain)
      .accessibilityLabel(RadarChromeCopy.liveAccessibility)
      .accessibilityAddTraits(!radarState.showsFuture ? .isSelected : [])

      Button {
        guard radarState.hasFutureFrames else { return }
        radarState.setFutureMode(true)
      } label: {
        Text(RadarChromeCopy.futureChip)
          .font(DesignTokens.Typography.micro())
          .padding(.horizontal, 10)
          .padding(.vertical, 3)
          .background(
            radarState.showsFuture ? DesignTokens.Palette.radarAccent.opacity(0.2) : Color.clear
          )
          .clipShape(Capsule())
          .foregroundStyle(
            radarState.showsFuture
              ? DesignTokens.Palette.radarAccent : DesignTokens.Palette.radarTextSecondary
          )
      }
      .buttonStyle(.plain)
      .accessibilityLabel(RadarChromeCopy.futureAccessibility)
      .accessibilityAddTraits(radarState.showsFuture ? .isSelected : [])
      .disabled(!radarState.hasFutureFrames)
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
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(.secondary)
      }
    case .warning:
      Text(footer.text)
        .font(DesignTokens.Typography.micro())
        .foregroundStyle(.orange)
    case .error:
      Text(footer.text)
        .font(DesignTokens.Typography.micro())
        .foregroundStyle(.red)
    case .secondary:
      EmptyView()
    }
  }

  /// Storm winds stay behind Advanced. Live Rain is nearest-site N0B, so that
  /// chip lives on the main row — do not hide it just because it is a site product.
  private var isAdvancedExpanded: Bool {
    advancedManuallyExpanded || radarState.selectedProduct == .stormRelativeVelocity
  }

  private var advancedAvailable: Bool {
    radarState.siteProductsAvailable && !radarState.showsFuture
  }

  private var productChips: some View {
    VStack(alignment: .leading, spacing: 6) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          productChip(.superResReflectivity)
          productChip(.reflectivity)
          if advancedAvailable {
            advancedChip
          }
        }
      }

      if isAdvancedExpanded, advancedAvailable {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            if let site = radarState.nearestSite {
              siteBadge(site.id)
            }
            productChip(.stormRelativeVelocity)
          }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
      }

      productTip
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .animation(.easeInOut(duration: 0.2), value: isAdvancedExpanded)
    .animation(.easeInOut(duration: 0.2), value: advancedAvailable)
    .onChange(of: radarState.showsFuture) { _, isFuture in
      // Site products are live-only; don't leave an orphaned row open in forecast.
      if isFuture { advancedManuallyExpanded = false }
    }
    .onChange(of: radarState.siteProductsAvailable) { _, available in
      if !available { advancedManuallyExpanded = false }
    }
  }

  private var advancedChip: some View {
    chip(
      "Advanced", systemImage: isAdvancedExpanded ? "chevron.down" : "chevron.right",
      isSelected: isAdvancedExpanded
    ) {
      Haptic.impact(.light)
      if radarState.selectedProduct == .stormRelativeVelocity {
        // Collapsing while SRV is live would strand the selection in a hidden
        // row. Return to default Live Rain (nearest-site N0B), not the mosaic.
        advancedManuallyExpanded = false
        Task { await radarState.setProduct(.defaultLive) }
      } else {
        advancedManuallyExpanded.toggle()
      }
    }
    .accessibilityLabel("Advanced radar products")
    .accessibilityValue(isAdvancedExpanded ? "Expanded" : "Collapsed")
    .accessibilityHint(
      isAdvancedExpanded ? "Collapses advanced products" : "Shows storm winds"
    )
  }

  /// Non-interactive provenance label (the old chip was a no-op Button — a VoiceOver trap).
  private func siteBadge(_ id: String) -> some View {
    HStack(spacing: 4) {
      Image(systemName: "wifi")
        .font(DesignTokens.Typography.micro())
      Text(id)
        .font(DesignTokens.Typography.micro())
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 4)
    .background(DesignTokens.Palette.radarTrack)
    .clipShape(Capsule())
    .foregroundStyle(DesignTokens.Palette.radarTextSecondary)
    .accessibilityLabel("Nearest radar site \(id)")
  }

  @ViewBuilder
  private var productTip: some View {
    let product = radarState.selectedProduct
    if let tip = product.userTip, !dismissedTips.contains(product) {
      HStack(alignment: .top, spacing: 6) {
        Text(tip)
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(DesignTokens.Palette.radarTextSecondary)
          .fixedSize(horizontal: false, vertical: true)

        Spacer(minLength: 0)

        Button {
          Haptic.impact(.light)
          RadarTipStore.dismiss(product)
          dismissedTips.insert(product)
        } label: {
          Image(systemName: "xmark")
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(DesignTokens.Palette.radarTextSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss tip")
      }
      .transition(.opacity)
    }
  }

  private func productChip(_ product: RadarProduct) -> some View {
    chip(
      product.displayName, systemImage: nil,
      isSelected: radarState.selectedProduct == product
    ) {
      Haptic.impact(.light)
      if product != .stormRelativeVelocity { advancedManuallyExpanded = false }
      Task { await radarState.setProduct(product) }
    }
  }

  private func chip(
    _ title: String, systemImage: String?, isSelected: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 4) {
        if let img = systemImage {
          Image(systemName: img)
            .font(DesignTokens.Typography.micro())
        }
        Text(title)
          .font(DesignTokens.Typography.micro())
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(
        isSelected ? DesignTokens.Palette.radarAccent.opacity(0.2) : DesignTokens.Palette.radarTrack
      )
      .clipShape(Capsule())
      .overlay(
        Capsule()
          .stroke(DesignTokens.Palette.radarAccent, lineWidth: 1)
          .opacity(isSelected ? 1 : 0)
      )
      .foregroundStyle(
        isSelected ? DesignTokens.Palette.radarAccent : DesignTokens.Palette.radarTextSecondary
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
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
    switch provider {
    case .iem, .mrms: return "National radar"
    case .xweather: return "Xweather"
    case .rainViewer: return "RainViewer"
    case .openWeatherMap: return "OpenWeatherMap"
    case .none: return "No source"
    }
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
  @Binding var isDecluttered: Bool
  var onExplain: () -> Void

  var body: some View {
    NavigationStack {
      Form {
        Section {
          namedSwitch(RadarChromeCopy.autoResumeSwitch, isOn: $radarState.autoResumeAfterScrub)
          namedSwitch(RadarChromeCopy.mapOnlySwitch, isOn: $isDecluttered)
        } footer: {
          Text("Map only keeps SCAN and hides the extra chase lines. Live, 24-hr, and Layers stay on.")
        }

        Section {
          productRow(.superResReflectivity)
          productRow(.reflectivity)
          productRow(.stormRelativeVelocity)
        } header: {
          Text("Products")
        } footer: {
          Text(
            "Site Doppler is nearest-site NEXRAD (N0B). National radar is the CONUS picture. Storm winds are live NEXRAD only. Motion tracks exist only on National radar — they do not paint on Site Doppler."
          )
        }

        Section {
          Button("Explain radar") {
            onExplain()
          }
        }

        if showsRasterColorScheme {
          Section("Colors") {
            Picker("Palette", selection: $radarState.colorScheme) {
              ForEach(RadarColorScheme.allCases, id: \.self) { scheme in
                Text(scheme.displayName).tag(scheme)
              }
            }
            .pickerStyle(.segmented)
          }
        }

        Section("Legend") {
          RadarMiniLegend(
            showsVelocity: showsVelocityLegend,
            keysClearAir: radarState.selectedProduct.isSiteProduct
              && !radarState.showsFuture,
            style: .sheet
          )
        }

        #if DEBUG
          Section {
            Picker("National paint", selection: $radarState.debugNationalPaint) {
              ForEach(DebugFlags.NationalPaint.allCases) { mode in
                Text(mode.debugLabel).tag(mode)
              }
            }
          } footer: {
            Text(
              "DEBUG. Auto uses National tiles when the local worker is fresh, else MapsGL rain. Never shown as MRMS."
            )
          }
        #endif

        Section {
          namedSwitch(RadarChromeCopy.radarOverlaySwitch, isOn: $radarState.showRadarOverlay)
          namedSwitch(
            RadarChromeCopy.fireLayerSwitch,
            isOn: Binding(
              get: { radarState.showFireLayer },
              set: { newValue in
                radarState.showFireLayer = newValue
                Analytics.track(.fireLayerToggle, parameters: ["on": newValue ? "1" : "0"])
              }
            )
          )
          namedSwitch(
            RadarChromeCopy.lightningLayerSwitch,
            isOn: Binding(
              get: { radarState.showLightningLayer },
              set: { newValue in
                radarState.showLightningLayer = newValue
                Analytics.track(.lightningLayerToggle, parameters: ["on": newValue ? "1" : "0"])
              }
            )
          )
          Picker("Base map", selection: $radarState.baseMapStyle) {
            ForEach(RadarBaseMapStyle.allCases) { style in
              Label(style.displayName, systemImage: style.systemImage).tag(style)
            }
          }
        } header: {
          Text("Map")
        } footer: {
          Text(
            "Lightning is Live only — recent cloud-to-ground strikes from Vaisala Xweather. Works on Site Doppler and National."
          )
        }

        Section("Opacity") {
          HStack {
            Slider(
              value: $opacity,
              in: RadarPreferences.radarOpacityRange,
              step: 0.05
            )
            Text(String(format: "%.0f%%", opacity * 100))
              .font(DesignTokens.Typography.caption().monospacedDigit())
              .foregroundStyle(.secondary)
              .frame(width: 40)
          }
          .disabled(!radarState.showRadarOverlay)
          .opacity(radarState.showRadarOverlay ? 1 : 0.4)
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

  /// PNG-only fallback. MapsGL rain and IEM site tiles already have a real scale.
  private var showsRasterColorScheme: Bool {
    MapsGLRadarPalette.showsRasterColorScheme(
      overlayOn: radarState.showRadarOverlay,
      isSiteProduct: radarState.selectedProduct.isSiteProduct,
      keysPresent: MapsGLRadarHost.keysPresent
    )
  }

  private func namedSwitch(_ title: String, isOn: Binding<Bool>) -> some View {
    HStack {
      Text(title)
        .accessibilityHidden(true)
      Spacer()
      NamedSettingsSwitch(isOn: isOn, label: title)
    }
    .accessibilityElement(children: .contain)
  }

  private func productRow(_ product: RadarProduct) -> some View {
    let siteLocked = product.isSiteProduct && (radarState.showsFuture || !radarState.siteProductsAvailable)
    return Button {
      Task { await radarState.setProduct(product) }
    } label: {
      HStack {
        Text(product.displayName)
        Spacer()
        if radarState.selectedProduct == product {
          Image(systemName: "checkmark")
            .foregroundStyle(DesignTokens.Palette.radarAccent)
        }
      }
    }
    .disabled(siteLocked)
    .foregroundStyle(siteLocked ? .secondary : DesignTokens.Palette.radarTextPrimary)
    .accessibilityAddTraits(radarState.selectedProduct == product ? .isSelected : [])
  }
}

// MARK: - Mini legend (panel + Display sheet)

/// Compact dBZ / velocity key. Rain uses the MapsGL NWS stops, not a second scale.
/// Panel uses a tight strip; the sheet adds the range-fold note for SRV.
struct RadarMiniLegend: View {
  enum Style {
    case panel
    case sheet
  }

  var showsVelocity: Bool
  /// National starts at 15 green; Site N0B (`keysClearAir`) starts at 25.
  var keysClearAir: Bool = false
  var style: Style = .panel

  var body: some View {
    if showsVelocity {
      velocityLegend
    } else {
      reflectivityLegend
    }
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
      .frame(height: style == .panel ? 6 : 8)
      .clipShape(RoundedRectangle(cornerRadius: 2))
      .accessibilityLabel("Velocity legend: green toward radar, red away from radar")

      HStack {
        Text("Toward").font(DesignTokens.Typography.micro()).foregroundStyle(
          style == .panel
            ? DesignTokens.Palette.radarTextSecondary : .secondary
        )
        Spacer()
        Text("Away").font(DesignTokens.Typography.micro()).foregroundStyle(
          style == .panel
            ? DesignTokens.Palette.radarTextSecondary : .secondary
        )
      }

      if style == .sheet {
        // NWS SRV palettes paint range-folded / edge returns purple-magenta.
        HStack(spacing: 6) {
          Circle()
            .fill(Color(red: 0.72, green: 0.28, blue: 0.85))
            .frame(width: 8, height: 8)
          Text("Purple at scan edge = range fold (unreliable)")
            .font(DesignTokens.Typography.micro())
            .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Purple at scan edge means range fold and is unreliable")
      }
    }
  }

  /// Same RGB stops the current paint uses, discrete (no gradient). Ticks sit
  /// under the matching band so the key agrees with the map.
  private var reflectivityLegend: some View {
    let stops = MapsGLRadarPalette.paintedReflectivityStops(
      keysClearAir: keysClearAir)
    let ticks = Set(MapsGLRadarPalette.legendTicks(keysClearAir: keysClearAir))
    return VStack(alignment: .leading, spacing: 4) {
      Text("dBZ")
        .font(DesignTokens.Typography.micro())
        .foregroundStyle(legendCaptionColor)

      HStack(spacing: 0) {
        ForEach(stops, id: \.dbz) { stop in
          Rectangle()
            .fill(Color(hex: stop.hex))
        }
      }
      .frame(height: style == .panel ? 8 : 12)
      .clipShape(RoundedRectangle(cornerRadius: 2))

      HStack(spacing: 0) {
        ForEach(stops, id: \.dbz) { stop in
          Text(ticks.contains(stop.dbz) ? String(Int(stop.dbz)) : "")
            .font(DesignTokens.Typography.micro().monospacedDigit())
            .foregroundStyle(legendCaptionColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "Reflectivity legend, dBZ \(Int(stops.first?.dbz ?? 15)) to \(Int(stops.last?.dbz ?? 70))"
    )
  }

  private var legendCaptionColor: Color {
    style == .panel ? DesignTokens.Palette.radarTextSecondary : .secondary
  }
}

/// Vertical dBZ key on Live Radar. Stops match the paint: 0/5/10 cyan-blue
/// are keyed out on both products. National starts at 15 green; Site N0B
/// (`keysClearAir`) starts at 25 so the bar matches the raised paint floor.
struct RadarMapColorbar: View {
  var keysClearAir: Bool = false

  var body: some View {
    let stops = Array(
      MapsGLRadarPalette.paintedReflectivityStops(keysClearAir: keysClearAir)
        .reversed())
    let ticks = Set(MapsGLRadarPalette.legendTicks(keysClearAir: keysClearAir))
    let low = Int(stops.last?.dbz ?? 15)
    let high = Int(stops.first?.dbz ?? 70)
    return VStack(alignment: .leading, spacing: 4) {
      Text("dBZ")
        .font(DesignTokens.Typography.micro())
        .foregroundStyle(DesignTokens.Palette.radarTextSecondary)

      HStack(alignment: .center, spacing: 4) {
        VStack(spacing: 0) {
          ForEach(stops, id: \.dbz) { stop in
            Rectangle()
              .fill(Color(hex: stop.hex))
          }
        }
        .frame(width: 10)
        .clipShape(RoundedRectangle(cornerRadius: 2))

        VStack(spacing: 0) {
          ForEach(stops, id: \.dbz) { stop in
            Text(ticks.contains(stop.dbz) ? String(Int(stop.dbz)) : "")
              .font(DesignTokens.Typography.micro().monospacedDigit())
              .foregroundStyle(DesignTokens.Palette.radarTextSecondary)
              .lineLimit(1)
              .minimumScaleFactor(0.7)
              .frame(maxHeight: .infinity, alignment: .center)
          }
        }
      }
      .frame(height: 152)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 6)
    .background(
      DesignTokens.Palette.cardBackground.opacity(0.94),
      in: RoundedRectangle(cornerRadius: 8)
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(colorbarAccessibilityLabel(low: low, high: high))
  }

  private func colorbarAccessibilityLabel(low: Int, high: Int) -> String {
    let range = "Reflectivity legend, dBZ \(low) to \(high)"
    if keysClearAir { return range }
    return "\(range). \(RadarChromeCopy.motionTracks)"
  }
}
