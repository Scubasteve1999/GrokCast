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
  static let columnWidth: CGFloat = 28
  static let iconRowHeight: CGFloat = 16
  static let plotHeight: CGFloat = 44
  static let timeRowHeight: CGFloat = 14
  static var height: CGFloat { iconRowHeight + plotHeight + timeRowHeight }

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
    let pad: CGFloat = 4
    let usable = plotHeight - pad * 2
    let span = max - min
    if span < 0.5 { return plotHeight / 2 }
    let t = (value - min) / span
    return pad + usable * (1 - CGFloat(t))
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
      ZStack(alignment: .topLeading) {
        plot
          .frame(width: canvasWidth, height: HourlyGraphLayout.plotHeight)
          .padding(.top, HourlyGraphLayout.iconRowHeight)

        sunGlyphs
          .padding(.top, HourlyGraphLayout.iconRowHeight)

        iconRow
        timeRow
          .padding(.top, HourlyGraphLayout.iconRowHeight + HourlyGraphLayout.plotHeight)
      }
      .frame(width: canvasWidth, height: HourlyGraphLayout.height, alignment: .topLeading)
    }
    .frame(height: HourlyGraphLayout.height)
    .accessibilityHidden(true)
  }

  private var canvasWidth: CGFloat {
    max(HourlyGraphLayout.columnWidth * CGFloat(hours.count), HourlyGraphLayout.columnWidth)
  }

  private var iconRow: some View {
    HStack(spacing: 0) {
      ForEach(Array(hours.enumerated()), id: \.element.time) { _, hour in
        Group {
          if series == .precip {
            Text(precipTopLabel(for: hour))
              .font(DesignTokens.Typography.micro())
              .foregroundStyle(DesignTokens.Palette.accentCool)
              .monospacedDigit()
              .lineLimit(1)
              .minimumScaleFactor(0.7)
          } else {
            Image(systemName: symbolName(for: hour))
              .font(DesignTokens.Typography.symbol(12))
              .symbolRenderingMode(.multicolor)
          }
        }
        .frame(width: HourlyGraphLayout.columnWidth, height: HourlyGraphLayout.iconRowHeight)
      }
    }
  }

  private var timeRow: some View {
    HStack(spacing: 0) {
      ForEach(Array(hours.enumerated()), id: \.element.time) { index, hour in
        Text(timeLabel(for: hour, index: index))
          .font(DesignTokens.Typography.micro())
          .foregroundStyle(
            index == 0
              ? DesignTokens.Palette.accent
              : DesignTokens.Palette.textTertiary
          )
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .frame(width: HourlyGraphLayout.columnWidth, height: HourlyGraphLayout.timeRowHeight)
      }
    }
  }

  private var plot: some View {
    let values = seriesValues
    let minValue = series == .precip ? 0 : (values.min() ?? 0) - 2
    let maxValue = series == .precip ? 100 : (values.max() ?? 100) + 2
    let lineColor: Color = {
      switch series {
      case .temp: return DesignTokens.Palette.accentWarm
      case .feels: return DesignTokens.Palette.accent
      case .precip: return DesignTokens.Palette.accentCool
      }
    }()
    let sunX = sunTickX(sunset)
    let riseX = sunTickX(sunrise)

    return Canvas { context, size in
      if let sunX { strokeSunTick(context: &context, x: sunX, height: size.height) }
      if let riseX { strokeSunTick(context: &context, x: riseX, height: size.height) }

      guard hours.count >= 1, values.count == hours.count else { return }

      var line = Path()
      var fill = Path()
      for (index, value) in values.enumerated() {
        let x = HourlyGraphLayout.columnWidth * (CGFloat(index) + 0.5)
        let y = HourlyGraphLayout.y(
          value: value, min: minValue, max: maxValue, plotHeight: size.height)
        if index == 0 {
          line.move(to: CGPoint(x: x, y: y))
          fill.move(to: CGPoint(x: x, y: size.height))
          fill.addLine(to: CGPoint(x: x, y: y))
        } else {
          line.addLine(to: CGPoint(x: x, y: y))
          fill.addLine(to: CGPoint(x: x, y: y))
        }
      }
      if hours.count >= 1 {
        let lastX = HourlyGraphLayout.columnWidth * (CGFloat(hours.count - 1) + 0.5)
        fill.addLine(to: CGPoint(x: lastX, y: size.height))
        fill.closeSubpath()
      }

      context.fill(fill, with: .color(lineColor.opacity(0.16)))
      context.stroke(
        line, with: .color(lineColor),
        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

      if let first = values.first {
        let x = HourlyGraphLayout.columnWidth * 0.5
        let y = HourlyGraphLayout.y(
          value: first, min: minValue, max: maxValue, plotHeight: size.height)
        let dot = Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6))
        context.fill(dot, with: .color(lineColor))
      }
    }
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
      with: .color(DesignTokens.Palette.accentWarm.opacity(0.55)),
      style: StrokeStyle(lineWidth: 1, dash: [3, 3])
    )
  }

  private var sunGlyphs: some View {
    ZStack(alignment: .topLeading) {
      if let x = sunTickX(sunset) {
        Image(systemName: "sunset.fill")
          .font(DesignTokens.Typography.symbol(10))
          .foregroundStyle(DesignTokens.Palette.accentWarm)
          .position(x: x, y: 6)
      }
      if let x = sunTickX(sunrise) {
        Image(systemName: "sunrise.fill")
          .font(DesignTokens.Typography.symbol(10))
          .foregroundStyle(DesignTokens.Palette.accentWarm)
          .position(x: x, y: 6)
      }
    }
    .frame(width: canvasWidth, height: HourlyGraphLayout.plotHeight, alignment: .topLeading)
    .allowsHitTesting(false)
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

  private func symbolName(for hour: HourlyForecast) -> String {
    WeatherCondition(fromWMO: hour.weatherCode)
      .rowSymbolName(precipChance: hour.precipChance, isDay: hour.isDay ?? true)
  }

  private func precipTopLabel(for hour: HourlyForecast) -> String {
    if let amount = precipAmountText(liquid: hour.liquidPrecip, snow: hour.snowfall ?? 0) {
      return amount
    }
    if hour.precipChance > 0 { return "\(hour.precipChance)%" }
    return " "
  }

  private func timeLabel(for hour: HourlyForecast, index: Int) -> String {
    if index == 0 { return "Now" }
    if index % 2 != 0 { return "" }
    return LocationTimezone.formatter(dateFormat: "ha", timeZone: timeZone)
      .string(from: hour.time)
  }
}
