import SwiftUI

enum HourlyGraphSeries: String, CaseIterable, Identifiable {
  case temp
  case feels
  case precip

  var id: String { rawValue }

  var label: String {
    switch self {
    case .temp: return "Temp"
    case .feels: return "Feels"
    case .precip: return "Precip"
    }
  }

  var fullLabel: String {
    switch self {
    case .temp: return "Temperature"
    case .feels: return "Feels Like"
    case .precip: return "Precipitation"
    }
  }

  static func available(in hours: [HourlyForecast]) -> [HourlyGraphSeries] {
    var items: [HourlyGraphSeries] = [.temp]
    if hours.contains(where: { $0.feelsLike != nil }) {
      items.append(.feels)
    }
    items.append(.precip)
    return items
  }
}

enum HourlyGraphHours {
  static let compactLimit = 24
  static let fullLimit = 48

  /// Upcoming hours even if a cached payload still includes earlier-today slots.
  /// Absolute `Date` cutoff so a remote city's hours are not dropped when the
  /// device timezone differs.
  static func upcoming(
    from weather: DayCastWeather, limit: Int = compactLimit
  ) -> [HourlyForecast] {
    let cutoff = Date().addingTimeInterval(-45 * 60)
    let upcoming = weather.hourly.filter { $0.time >= cutoff }
    let slice = upcoming.isEmpty ? weather.hourly : upcoming
    return Array(slice.prefix(limit))
  }
}

enum HourlyGraphStyle: Equatable {
  /// Today card. `HourlyGraphLayout.height` / glance budget. No precip row, no scrub.
  case compact
  /// Forecast tab. 48h, taller plot, precip bars, day dividers, pan-to-scrub.
  case full
}

struct HourlyGraphMetrics: Equatable {
  var plotHeight: CGFloat
  var timeRowHeight: CGFloat
  var plotTopPad: CGFloat
  var plotBottomPad: CGFloat
  var precipBarHeight: CGFloat
  var readoutHeight: CGFloat
  var readoutSpacing: CGFloat
  var fillTopOpacity: Double

  var plotStackHeight: CGFloat { plotHeight + precipBarHeight + timeRowHeight }
  var height: CGFloat { readoutHeight + readoutSpacing + plotStackHeight }

  static let compact = HourlyGraphMetrics(
    plotHeight: 58,
    timeRowHeight: 16,
    plotTopPad: 18,
    plotBottomPad: 8,
    precipBarHeight: 0,
    readoutHeight: 0,
    readoutSpacing: 0,
    fillTopOpacity: 0.32
  )

  static let full = HourlyGraphMetrics(
    plotHeight: 108,
    timeRowHeight: 28,
    plotTopPad: 26,
    plotBottomPad: 10,
    precipBarHeight: 36,
    readoutHeight: 22,
    readoutSpacing: 6,
    fillTopOpacity: 0.22
  )
}

struct HourlyGraphSunEvent: Equatable {
  let date: Date
  let title: String

  static func inWindow(days: [DailyForecast], hours: [HourlyForecast]) -> [HourlyGraphSunEvent] {
    guard let first = hours.first?.time, let last = hours.last?.time else { return [] }
    var events: [HourlyGraphSunEvent] = []
    for day in days {
      if let rise = day.sunrise, rise >= first, rise <= last {
        events.append(HourlyGraphSunEvent(date: rise, title: "Sunrise"))
      }
      if let set = day.sunset, set >= first, set <= last {
        events.append(HourlyGraphSunEvent(date: set, title: "Sunset"))
      }
    }
    return events
  }
}

struct HourlySeriesPicker: View {
  let options: [HourlyGraphSeries]
  @Binding var selection: HourlyGraphSeries
  var compact: Bool = true

  var body: some View {
    HStack(spacing: DesignTokens.Spacing.space8) {
      ForEach(options) { option in
        Button {
          Haptic.impact(.light)
          selection = option
        } label: {
          Text(compact ? option.label : option.fullLabel)
            .font(DesignTokens.Typography.caption())
            .fontWeight(selection == option ? .semibold : .regular)
            .foregroundStyle(
              selection == option
                ? (compact ? DesignTokens.Palette.textPrimary : DesignTokens.Palette.bgPrimary)
                : DesignTokens.Palette.textSecondary
            )
            .padding(.horizontal, compact ? 8 : 12)
            .padding(.vertical, 6)
            .frame(minHeight: compact ? 28 : 32)
            .background(
              compact
                ? Color.clear
                : (selection == option
                  ? DesignTokens.Palette.textPrimary
                  : DesignTokens.Palette.cardBackground.opacity(0.7))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.fullLabel)
        .accessibilityAddTraits(selection == option ? .isSelected : [])
      }
    }
  }
}

struct HourlyGraphSkeleton: View {
  var style: HourlyGraphStyle = .compact

  private var metrics: HourlyGraphMetrics { HourlyGraphLayout.metrics(for: style) }

  var body: some View {
    VStack(alignment: .leading, spacing: TodayGlanceLayout.hourlyInnerSpacing) {
      HStack {
        ShimmerBlock(width: 64, height: 12, cornerRadius: 4)
        Spacer(minLength: 0)
        ShimmerBlock(width: 108, height: 16, cornerRadius: 8)
      }
      .frame(height: TodayGlanceLayout.hourlyHeaderHeight)
      if style == .full {
        ShimmerBlock(width: 180, height: 12, cornerRadius: 4)
      }
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
        ShimmerBlock(
          width: HourlyGraphLayout.columnWidth * 8,
          height: 10,
          cornerRadius: 5
        )
        .padding(.top, DesignTokens.Spacing.space16)
        HStack(spacing: 0) {
          ForEach(0..<4, id: \.self) { _ in
            ShimmerBlock(width: 28, height: 10, cornerRadius: 3)
              .frame(width: HourlyGraphLayout.columnWidth * 2)
          }
          Spacer(minLength: 0)
        }
      }
      .frame(height: metrics.plotStackHeight, alignment: .top)
    }
    .padding(
      style == .full ? DesignTokens.Spacing.space16 : TodayGlanceLayout.hourlyCardPadding
    )
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardStyle()
  }
}

enum HourlyGraphLayout {
  static let columnWidth: CGFloat = 32
  static let plotHeight: CGFloat = 58
  static let timeRowHeight: CGFloat = 16
  static let plotTopPad: CGFloat = 16
  static let plotBottomPad: CGFloat = 8
  /// Compact Today graph. Do not point glance tests at `.full`.
  static var height: CGFloat { HourlyGraphMetrics.compact.plotStackHeight }

  static func metrics(for style: HourlyGraphStyle) -> HourlyGraphMetrics {
    style == .full ? .full : .compact
  }

  static func height(for style: HourlyGraphStyle) -> CGFloat {
    metrics(for: style).height
  }

  /// Pad actual min/max by 15% so a 6° night has shape instead of a ruler.
  static func valueBounds(values: [Double], series: HourlyGraphSeries) -> (
    min: Double, max: Double
  ) {
    if series == .precip { return (0, 100) }
    let lo = values.min() ?? 0
    let hi = values.max() ?? 0
    let span = max(hi - lo, 0.5)
    let pad = span * 0.15
    return (lo - pad, hi + pad)
  }

  static func midnightIndexes(hours: [HourlyForecast], calendar: Calendar) -> [Int] {
    hours.enumerated().compactMap { index, hour in
      calendar.component(.hour, from: hour.time) == 0 ? index : nil
    }
  }

  static func selectedIndex(offset: CGFloat, hourCount: Int) -> Int {
    guard hourCount > 0 else { return 0 }
    let index = Int((offset / columnWidth).rounded())
    return min(max(index, 0), hourCount - 1)
  }

  static func clampedOffset(
    raw: CGFloat, canvasWidth: CGFloat, viewportWidth: CGFloat
  ) -> CGFloat {
    let maxOffset = max(0, canvasWidth - max(viewportWidth, columnWidth))
    return min(max(raw, 0), maxOffset)
  }

  static func readoutText(
    hour: HourlyForecast,
    index: Int,
    series: HourlyGraphSeries,
    timeZone: TimeZone
  ) -> String {
    let timePart: String
    if index == 0 {
      timePart = "Now"
    } else {
      let day = LocationTimezone.formatter(dateFormat: "EEE", timeZone: timeZone)
        .string(from: hour.time)
      let time = LocationTimezone.formatter(dateFormat: "h a", timeZone: timeZone)
        .string(from: hour.time)
      timePart = "\(day) \(time)"
    }
    let degrees: Int
    switch series {
    case .feels:
      degrees = Int(round(hour.feelsLike ?? hour.temp))
    case .temp, .precip:
      degrees = Int(round(hour.temp))
    }
    if let amount = precipAmountText(liquid: hour.liquidPrecip, snow: hour.snowfall ?? 0) {
      return "\(timePart)  ·  \(degrees)°  ·  \(amount)"
    }
    return "\(timePart)  ·  \(degrees)°  ·  \(hour.precipChance)%"
  }

  static func accessibilityLabel(
    hour: HourlyForecast,
    index: Int,
    hourCount: Int,
    series: HourlyGraphSeries,
    timeZone: TimeZone
  ) -> String {
    let spoken = readoutText(hour: hour, index: index, series: series, timeZone: timeZone)
      .replacingOccurrences(of: "  ·  ", with: ", ")
      .replacingOccurrences(of: "°", with: " degrees")
    return "\(spoken). \(hourCount)-hour forecast."
  }

  /// Center-x of the hour column. Sunset interpolates between hour centers.
  static func xOffset(for date: Date, hours: [HourlyForecast]) -> CGFloat? {
    guard hours.count >= 1 else { return nil }
    let times = hours.map(\.time)
    if date <= times[0] { return columnWidth / 2 }
    if date >= times[times.count - 1] {
      return columnWidth * CGFloat(times.count - 1) + columnWidth / 2
    }
    for index in 0..<(times.count - 1) {
      let start = times[index]
      let end = times[index + 1]
      if date >= start, date <= end {
        let span = end.timeIntervalSince(start)
        let t = span > 0 ? date.timeIntervalSince(start) / span : 0
        return columnWidth * (CGFloat(index) + 0.5 + CGFloat(t))
      }
    }
    return nil
  }

  static func y(
    value: Double,
    min: Double,
    max: Double,
    plotHeight: CGFloat = plotHeight,
    topPad: CGFloat = plotTopPad,
    bottomPad: CGFloat = plotBottomPad
  ) -> CGFloat {
    let usable = plotHeight - topPad - bottomPad
    let span = max - min
    if span < 0.5 { return topPad + usable / 2 }
    let t = (value - min) / span
    return topPad + usable * (1 - CGFloat(t))
  }

  /// Now, then every 3 hours. Never a glyph per hour.
  static func labeledIndexes(count: Int) -> [Int] {
    guard count > 0 else { return [] }
    var indexes = [0]
    var index = 3
    while index < count {
      indexes.append(index)
      index += 3
    }
    return indexes
  }

  /// Peaks at ≥20%, plus hours with a measurable amount. Skip 1% wallpaper.
  static func precipLabelIndexes(chances: [Int], hasAmount: [Bool]) -> [Int] {
    let count = min(chances.count, hasAmount.count)
    var indexes: [Int] = []
    for index in 0..<count {
      if hasAmount[index] {
        indexes.append(index)
        continue
      }
      let chance = chances[index]
      if chance < 20 { continue }
      let left = index > 0 ? chances[index - 1] : -1
      let right = index + 1 < count ? chances[index + 1] : -1
      if chance >= left, chance >= right {
        indexes.append(index)
      }
    }
    return indexes
  }

  static func points(
    values: [Double],
    min: Double,
    max: Double,
    plotHeight: CGFloat,
    topPad: CGFloat = plotTopPad,
    bottomPad: CGFloat = plotBottomPad
  ) -> [CGPoint] {
    values.enumerated().map { index, value in
      CGPoint(
        x: columnWidth * (CGFloat(index) + 0.5),
        y: y(
          value: value, min: min, max: max, plotHeight: plotHeight, topPad: topPad,
          bottomPad: bottomPad)
      )
    }
  }

  /// Catmull-Rom as cubic Béziers. Temperature should read as a curve, not a polyline.
  static func smoothPath(through points: [CGPoint]) -> Path {
    var path = Path()
    guard let first = points.first else { return path }
    path.move(to: first)
    guard points.count >= 2 else { return path }
    if points.count == 2 {
      path.addLine(to: points[1])
      return path
    }
    let tension: CGFloat = 1.0 / 6.0
    for index in 0..<(points.count - 1) {
      let p0 = index == 0 ? points[index] : points[index - 1]
      let p1 = points[index]
      let p2 = points[index + 1]
      let p3 = index + 2 < points.count ? points[index + 2] : p2
      let c1 = CGPoint(
        x: p1.x + (p2.x - p0.x) * tension,
        y: p1.y + (p2.y - p0.y) * tension
      )
      let c2 = CGPoint(
        x: p2.x - (p3.x - p1.x) * tension,
        y: p2.y - (p3.y - p1.y) * tension
      )
      path.addCurve(to: p2, control1: c1, control2: c2)
    }
    return path
  }
}

struct HourlyGraphView: View {
  let hours: [HourlyForecast]
  let series: HourlyGraphSeries
  var style: HourlyGraphStyle = .compact
  var sunrise: Date? = nil
  var sunset: Date? = nil
  var sunEvents: [HourlyGraphSunEvent] = []
  var timeZone: TimeZone = .current
  var calendar: Calendar = .current
  var onInspectedHourChange: ((HourlyForecast) -> Void)? = nil

  @State private var scrubOffset: CGFloat = 0
  @GestureState private var dragTranslation: CGFloat = 0
  @State private var viewportWidth: CGFloat = 0

  private var metrics: HourlyGraphMetrics { HourlyGraphLayout.metrics(for: style) }

  var body: some View {
    Group {
      if style == .full {
        fullGraph
      } else {
        compactGraph
      }
    }
    .frame(height: metrics.height)
    .onAppear { reportInspectedHour() }
    .onChange(of: selectedIndex) { _, _ in reportInspectedHour() }
  }

  private func reportInspectedHour() {
    guard hours.indices.contains(selectedIndex) else { return }
    onInspectedHourChange?(hours[selectedIndex])
  }

  private var compactGraph: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      plotStack
        .frame(width: canvasWidth, height: metrics.plotStackHeight, alignment: .topLeading)
    }
    .frame(height: metrics.plotStackHeight)
    .accessibilityHidden(true)
  }

  private var fullGraph: some View {
    VStack(alignment: .leading, spacing: metrics.readoutSpacing) {
      readoutRow
        .frame(height: metrics.readoutHeight, alignment: .leading)

      GeometryReader { geo in
        let width = geo.size.width
        ZStack(alignment: .topLeading) {
          plotStack
            .frame(width: canvasWidth, alignment: .topLeading)
            .offset(x: -displayedOffset(viewWidth: width))

          playhead
            .frame(width: HourlyGraphLayout.columnWidth, height: metrics.plotHeight)
            .offset(x: 0)
            .allowsHitTesting(false)
        }
        .frame(width: width, height: metrics.plotStackHeight, alignment: .topLeading)
        .clipped()
        .contentShape(Rectangle())
        .gesture(scrubGesture(viewWidth: width))
        .onAppear { viewportWidth = width }
        .onChange(of: width) { _, newWidth in
          viewportWidth = newWidth
          scrubOffset = HourlyGraphLayout.clampedOffset(
            raw: scrubOffset, canvasWidth: canvasWidth, viewportWidth: newWidth)
        }
      }
      .frame(height: metrics.plotStackHeight)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(graphAccessibilityLabel)
    .accessibilityHint("Swipe up or down to move hour")
    .accessibilityAdjustableAction(adjustScrub)
  }

  private var plotStack: some View {
    VStack(alignment: .leading, spacing: 0) {
      ZStack(alignment: .topLeading) {
        plot
        valueLabels
        sunCaptions
      }
      .frame(width: canvasWidth, height: metrics.plotHeight)
      if style == .full {
        precipBars
          .frame(width: canvasWidth, height: metrics.precipBarHeight)
      }
      timeRow
    }
  }

  private var readoutRow: some View {
    Text(readoutText)
      .font(DesignTokens.Typography.callout())
      .foregroundStyle(DesignTokens.Palette.textPrimary)
      .monospacedDigit()
      .lineLimit(1)
      .minimumScaleFactor(0.8)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var playhead: some View {
    Rectangle()
      .fill(DesignTokens.Palette.textPrimary.opacity(0.85))
      .frame(width: 1)
      .frame(maxHeight: .infinity)
      .padding(.leading, HourlyGraphLayout.columnWidth / 2 - 0.5)
  }

  private var canvasWidth: CGFloat {
    let columns = HourlyGraphLayout.columnWidth * CGFloat(max(hours.count, 1))
    return columns + (style == .full ? 28 : 12)
  }

  private var resolvedSunEvents: [HourlyGraphSunEvent] {
    if !sunEvents.isEmpty { return sunEvents }
    var events: [HourlyGraphSunEvent] = []
    if let sunrise {
      events.append(HourlyGraphSunEvent(date: sunrise, title: "Sunrise"))
    }
    if let sunset {
      events.append(HourlyGraphSunEvent(date: sunset, title: "Sunset"))
    }
    return events
  }

  private var selectedIndex: Int {
    HourlyGraphLayout.selectedIndex(
      offset: displayedOffset(viewWidth: viewportWidth), hourCount: hours.count)
  }

  private var selectedHour: HourlyForecast? {
    guard hours.indices.contains(selectedIndex) else { return hours.first }
    return hours[selectedIndex]
  }

  private var readoutText: String {
    guard let hour = selectedHour else { return "Hourly forecast" }
    return HourlyGraphLayout.readoutText(
      hour: hour, index: selectedIndex, series: series, timeZone: timeZone)
  }

  private var graphAccessibilityLabel: String {
    guard let hour = selectedHour else { return "Hourly forecast." }
    return HourlyGraphLayout.accessibilityLabel(
      hour: hour, index: selectedIndex, hourCount: hours.count, series: series,
      timeZone: timeZone)
  }

  private func displayedOffset(viewWidth: CGFloat) -> CGFloat {
    HourlyGraphLayout.clampedOffset(
      raw: scrubOffset - dragTranslation,
      canvasWidth: canvasWidth,
      viewportWidth: viewWidth)
  }

  private func scrubGesture(viewWidth: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 8)
      .updating($dragTranslation) { value, state, _ in
        state = value.translation.width
      }
      .onEnded { value in
        let raw = scrubOffset - value.translation.width
        let clamped = HourlyGraphLayout.clampedOffset(
          raw: raw, canvasWidth: canvasWidth, viewportWidth: viewWidth)
        let snapped =
          (clamped / HourlyGraphLayout.columnWidth).rounded() * HourlyGraphLayout.columnWidth
        scrubOffset = HourlyGraphLayout.clampedOffset(
          raw: snapped, canvasWidth: canvasWidth, viewportWidth: viewWidth)
      }
  }

  private func adjustScrub(_ direction: AccessibilityAdjustmentDirection) {
    let delta = HourlyGraphLayout.columnWidth
    let next: CGFloat
    switch direction {
    case .increment:
      next = scrubOffset + delta
    case .decrement:
      next = scrubOffset - delta
    @unknown default:
      return
    }
    scrubOffset = HourlyGraphLayout.clampedOffset(
      raw: next, canvasWidth: canvasWidth, viewportWidth: max(viewportWidth, delta))
  }

  private var timeRow: some View {
    let midnights = Set(HourlyGraphLayout.midnightIndexes(hours: hours, calendar: calendar))
    return HStack(spacing: 0) {
      ForEach(Array(hours.enumerated()), id: \.element.time) { index, hour in
        Text(timeLabel(for: hour, index: index, isMidnight: midnights.contains(index)))
          .font(DesignTokens.Typography.caption())
          .fontWeight(midnights.contains(index) && style == .full ? .semibold : .regular)
          .foregroundStyle(timeColor(index: index, isMidnight: midnights.contains(index)))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .frame(
            width: HourlyGraphLayout.columnWidth, height: metrics.timeRowHeight)
      }
    }
  }

  private var precipBars: some View {
    let amountIndexes = Set(
      HourlyGraphLayout.precipLabelIndexes(
        chances: hours.map(\.precipChance),
        hasAmount: hours.map {
          precipAmountText(liquid: $0.liquidPrecip, snow: $0.snowfall ?? 0) != nil
        }
      ))
    return HStack(spacing: 0) {
      ForEach(Array(hours.enumerated()), id: \.element.time) { index, hour in
        VStack(spacing: 1) {
          if amountIndexes.contains(index),
            let amount = precipAmountText(
              liquid: hour.liquidPrecip, snow: hour.snowfall ?? 0)
          {
            Text(amount)
              .font(DesignTokens.Typography.micro())
              .foregroundStyle(DesignTokens.Palette.accentCool)
              .lineLimit(1)
              .minimumScaleFactor(0.6)
          }
          Capsule()
            .fill(precipBarColor(hour.precipChance))
            .frame(width: 8, height: precipBarHeight(hour.precipChance))
        }
        .frame(
          width: HourlyGraphLayout.columnWidth, height: metrics.precipBarHeight,
          alignment: .bottom)
      }
    }
  }

  private var plot: some View {
    let values = seriesValues
    let bounds = HourlyGraphLayout.valueBounds(values: values, series: series)
    let lineColor = seriesColor
    let points = HourlyGraphLayout.points(
      values: values, min: bounds.min, max: bounds.max,
      plotHeight: metrics.plotHeight, topPad: metrics.plotTopPad,
      bottomPad: metrics.plotBottomPad)
    let midnights = HourlyGraphLayout.midnightIndexes(hours: hours, calendar: calendar)
    let sunXs = resolvedSunEvents.compactMap { sunTickX($0.date) }

    return Canvas { context, size in
      if style == .full {
        strokeHourTicks(context: &context, height: size.height)
        for midnight in midnights {
          let x =
            HourlyGraphLayout.columnWidth * (CGFloat(midnight) + 0.5)
          strokeMidnightTick(context: &context, x: x, height: size.height)
        }
      }
      for x in sunXs {
        strokeSunTick(context: &context, x: x, height: size.height)
      }

      guard hours.count >= 1, values.count == hours.count, !points.isEmpty else { return }

      let line = HourlyGraphLayout.smoothPath(through: points)
      var fill = line
      if let last = points.last, let first = points.first {
        fill.addLine(to: CGPoint(x: last.x, y: size.height))
        fill.addLine(to: CGPoint(x: first.x, y: size.height))
        fill.closeSubpath()
      }

      let gradient = Gradient(colors: [
        lineColor.opacity(metrics.fillTopOpacity),
        lineColor.opacity(0.04),
      ])
      context.fill(
        fill,
        with: .linearGradient(
          gradient,
          startPoint: CGPoint(x: 0, y: 0),
          endPoint: CGPoint(x: 0, y: size.height)
        )
      )
      context.stroke(
        line, with: .color(lineColor),
        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
      )

      if style == .compact, let first = points.first {
        let ring = Path(ellipseIn: CGRect(x: first.x - 5, y: first.y - 5, width: 10, height: 10))
        context.fill(ring, with: .color(lineColor.opacity(0.35)))
        let dot = Path(ellipseIn: CGRect(x: first.x - 3.5, y: first.y - 3.5, width: 7, height: 7))
        context.fill(dot, with: .color(lineColor))
      }
    }
  }

  private var valueLabels: some View {
    let values = seriesValues
    let bounds = HourlyGraphLayout.valueBounds(values: values, series: series)
    return ZStack(alignment: .topLeading) {
      ForEach(labelIndexes, id: \.self) { index in
        let value = values[index]
        let x = HourlyGraphLayout.columnWidth * (CGFloat(index) + 0.5)
        let y = HourlyGraphLayout.y(
          value: value, min: bounds.min, max: bounds.max,
          plotHeight: metrics.plotHeight, topPad: metrics.plotTopPad,
          bottomPad: metrics.plotBottomPad)
        Text(valueLabel(at: index, value: value))
          .font(DesignTokens.Typography.caption())
          .fontWeight(index == 0 ? .semibold : .medium)
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.8)
          .position(x: x, y: y < metrics.plotTopPad ? y + 14 : y - 12)
      }
    }
    .frame(width: canvasWidth, height: metrics.plotHeight, alignment: .topLeading)
    .allowsHitTesting(false)
  }

  private var sunCaptions: some View {
    ZStack(alignment: .topLeading) {
      ForEach(Array(resolvedSunEvents.enumerated()), id: \.offset) { _, event in
        if let x = sunTickX(event.date) {
          Text(event.title)
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.accentWarm)
            .position(x: x, y: 10)
        }
      }
    }
    .frame(width: canvasWidth, height: metrics.plotHeight, alignment: .topLeading)
    .allowsHitTesting(false)
  }

  private func strokeSunTick(
    context: inout GraphicsContext,
    x: CGFloat,
    height: CGFloat
  ) {
    var tick = Path()
    tick.move(to: CGPoint(x: x, y: 0))
    tick.addLine(to: CGPoint(x: x, y: height))
    context.stroke(
      tick,
      with: .color(DesignTokens.Palette.accentWarm.opacity(0.45)),
      style: StrokeStyle(lineWidth: 0.75)
    )
  }

  private func strokeMidnightTick(
    context: inout GraphicsContext,
    x: CGFloat,
    height: CGFloat
  ) {
    var tick = Path()
    tick.move(to: CGPoint(x: x, y: 0))
    tick.addLine(to: CGPoint(x: x, y: height))
    context.stroke(
      tick,
      with: .color(DesignTokens.Palette.textTertiary.opacity(0.55)),
      style: StrokeStyle(lineWidth: 1)
    )
  }

  private func strokeHourTicks(context: inout GraphicsContext, height: CGFloat) {
    for index in 0..<hours.count {
      let x = HourlyGraphLayout.columnWidth * (CGFloat(index) + 0.5)
      var tick = Path()
      tick.move(to: CGPoint(x: x, y: height - 5))
      tick.addLine(to: CGPoint(x: x, y: height))
      context.stroke(
        tick,
        with: .color(DesignTokens.Palette.textTertiary.opacity(0.35)),
        style: StrokeStyle(lineWidth: 0.5)
      )
    }
  }

  /// Tick only when the sun event sits inside the plotted hours — not clamped to an edge.
  private func sunTickX(_ date: Date?) -> CGFloat? {
    guard let date, let first = hours.first?.time, let last = hours.last?.time else {
      return nil
    }
    guard date >= first, date <= last else { return nil }
    return HourlyGraphLayout.xOffset(for: date, hours: hours)
  }

  private var seriesValues: [Double] {
    hours.map { hour in
      switch series {
      case .temp:
        return hour.temp
      case .feels:
        return hour.feelsLike ?? hour.temp
      case .precip:
        return Double(hour.precipChance)
      }
    }
  }

  private var seriesColor: Color {
    switch series {
    case .temp: return DesignTokens.Palette.accentWarm
    case .feels: return DesignTokens.Palette.accent
    case .precip: return DesignTokens.Palette.accentCool
    }
  }

  private var labelIndexes: [Int] {
    if series != .precip {
      return HourlyGraphLayout.labeledIndexes(count: hours.count)
    }
    return HourlyGraphLayout.precipLabelIndexes(
      chances: hours.map(\.precipChance),
      hasAmount: hours.map {
        precipAmountText(liquid: $0.liquidPrecip, snow: $0.snowfall ?? 0) != nil
      }
    )
  }

  private func valueLabel(at index: Int, value: Double) -> String {
    let hour = hours[index]
    if series == .precip {
      if let amount = precipAmountText(liquid: hour.liquidPrecip, snow: hour.snowfall ?? 0) {
        return amount
      }
      return "\(hour.precipChance)%"
    }
    return "\(Int(round(value)))°"
  }

  private func timeLabel(for hour: HourlyForecast, index: Int, isMidnight: Bool) -> String {
    if index == 0 { return "Now" }
    if style == .full, isMidnight {
      return LocationTimezone.formatter(dateFormat: "EEE", timeZone: timeZone)
        .string(from: hour.time)
    }
    if !HourlyGraphLayout.labeledIndexes(count: hours.count).contains(index) { return "" }
    return LocationTimezone.formatter(dateFormat: "ha", timeZone: timeZone)
      .string(from: hour.time)
  }

  private func timeColor(index: Int, isMidnight: Bool) -> Color {
    if index == 0 { return DesignTokens.Palette.accent }
    if style == .full, isMidnight { return DesignTokens.Palette.textPrimary }
    return DesignTokens.Palette.textTertiary
  }

  private func precipBarHeight(_ chance: Int) -> CGFloat {
    let maxHeight: CGFloat = 22
    if chance <= 0 { return 2 }
    return max(2, maxHeight * CGFloat(chance) / 100)
  }

  private func precipBarColor(_ chance: Int) -> Color {
    if chance >= 50 { return DesignTokens.Palette.accentCool }
    if chance >= 20 { return DesignTokens.Palette.accentCool.opacity(0.7) }
    return DesignTokens.Palette.cardStroke
  }
}
