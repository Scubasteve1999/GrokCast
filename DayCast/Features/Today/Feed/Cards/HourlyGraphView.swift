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

  static func available(in hours: [HourlyForecast]) -> [HourlyGraphSeries] {
    var items: [HourlyGraphSeries] = [.temp]
    if hours.contains(where: { $0.feelsLike != nil }) {
      items.append(.feels)
    }
    items.append(.precip)
    return items
  }
}

enum HourlyGraphLayout {
  static let columnWidth: CGFloat = 32
  static let plotHeight: CGFloat = 58
  static let timeRowHeight: CGFloat = 16
  static let plotTopPad: CGFloat = 16
  static let plotBottomPad: CGFloat = 8
  static var height: CGFloat { plotHeight + timeRowHeight }

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

  static func y(value: Double, min: Double, max: Double, plotHeight: CGFloat = plotHeight)
    -> CGFloat
  {
    let usable = plotHeight - plotTopPad - plotBottomPad
    let span = max - min
    if span < 0.5 { return plotTopPad + usable / 2 }
    let t = (value - min) / span
    return plotTopPad + usable * (1 - CGFloat(t))
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
    plotHeight: CGFloat
  ) -> [CGPoint] {
    values.enumerated().map { index, value in
      CGPoint(
        x: columnWidth * (CGFloat(index) + 0.5),
        y: y(value: value, min: min, max: max, plotHeight: plotHeight)
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
  var sunrise: Date? = nil
  var sunset: Date? = nil
  var timeZone: TimeZone = .current

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      VStack(alignment: .leading, spacing: 0) {
        ZStack(alignment: .topLeading) {
          plot
          valueLabels
          sunCaptions
        }
        .frame(width: canvasWidth, height: HourlyGraphLayout.plotHeight)
        timeRow
      }
      .frame(width: canvasWidth, height: HourlyGraphLayout.height, alignment: .topLeading)
    }
    .frame(height: HourlyGraphLayout.height)
    .accessibilityHidden(true)
  }

  private var canvasWidth: CGFloat {
    let columns = HourlyGraphLayout.columnWidth * CGFloat(max(hours.count, 1))
    return columns + 12
  }

  private var timeRow: some View {
    HStack(spacing: 0) {
      ForEach(Array(hours.enumerated()), id: \.element.time) { index, hour in
        Text(timeLabel(for: hour, index: index))
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(
            index == 0
              ? DesignTokens.Palette.accent
              : DesignTokens.Palette.textTertiary
          )
          .lineLimit(1)
          .minimumScaleFactor(0.75)
          .frame(width: HourlyGraphLayout.columnWidth, height: HourlyGraphLayout.timeRowHeight)
      }
    }
  }

  private var plot: some View {
    let values = seriesValues
    let bounds = valueBounds(values)
    let lineColor = seriesColor
    let sunX = sunTickX(sunset)
    let riseX = sunTickX(sunrise)
    let points = HourlyGraphLayout.points(
      values: values, min: bounds.min, max: bounds.max,
      plotHeight: HourlyGraphLayout.plotHeight)

    return Canvas { context, size in
      if let sunX { strokeSunTick(context: &context, x: sunX, height: size.height) }
      if let riseX { strokeSunTick(context: &context, x: riseX, height: size.height) }

      guard hours.count >= 1, values.count == hours.count, !points.isEmpty else { return }

      let line = HourlyGraphLayout.smoothPath(through: points)
      var fill = line
      if let last = points.last, let first = points.first {
        fill.addLine(to: CGPoint(x: last.x, y: size.height))
        fill.addLine(to: CGPoint(x: first.x, y: size.height))
        fill.closeSubpath()
      }

      let gradient = Gradient(colors: [
        lineColor.opacity(0.32),
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

      if let first = points.first {
        let ring = Path(ellipseIn: CGRect(x: first.x - 5, y: first.y - 5, width: 10, height: 10))
        context.fill(ring, with: .color(lineColor.opacity(0.35)))
        let dot = Path(ellipseIn: CGRect(x: first.x - 3.5, y: first.y - 3.5, width: 7, height: 7))
        context.fill(dot, with: .color(lineColor))
      }
    }
  }

  private var valueLabels: some View {
    let values = seriesValues
    let bounds = valueBounds(values)
    return ZStack(alignment: .topLeading) {
      ForEach(labelIndexes, id: \.self) { index in
        let value = values[index]
        let x = HourlyGraphLayout.columnWidth * (CGFloat(index) + 0.5)
        let y = HourlyGraphLayout.y(
          value: value, min: bounds.min, max: bounds.max,
          plotHeight: HourlyGraphLayout.plotHeight)
        Text(valueLabel(at: index, value: value))
          .font(DesignTokens.Typography.caption())
          .fontWeight(index == 0 ? .semibold : .medium)
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.8)
          .position(x: x, y: y < 18 ? y + 12 : y - 11)
      }
    }
    .frame(width: canvasWidth, height: HourlyGraphLayout.plotHeight, alignment: .topLeading)
    .allowsHitTesting(false)
  }

  private var sunCaptions: some View {
    ZStack(alignment: .topLeading) {
      if let x = sunTickX(sunset) {
        Text("Sunset")
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(DesignTokens.Palette.accentWarm)
          .position(x: x, y: 7)
      }
      if let x = sunTickX(sunrise) {
        Text("Sunrise")
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(DesignTokens.Palette.accentWarm)
          .position(x: x, y: 7)
      }
    }
    .frame(width: canvasWidth, height: HourlyGraphLayout.plotHeight, alignment: .topLeading)
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

  private func valueBounds(_ values: [Double]) -> (min: Double, max: Double) {
    if series == .precip { return (0, 100) }
    let lo = (values.min() ?? 0) - 2
    let hi = (values.max() ?? 100) + 2
    return (lo, hi)
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

  private func timeLabel(for hour: HourlyForecast, index: Int) -> String {
    if index == 0 { return "Now" }
    if !HourlyGraphLayout.labeledIndexes(count: hours.count).contains(index) { return "" }
    return LocationTimezone.formatter(dateFormat: "ha", timeZone: timeZone)
      .string(from: hour.time)
  }
}
