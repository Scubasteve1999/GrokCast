import Foundation

/// Local moon-phase estimate from date (no network). Illumination is approximate.
enum MoonPhase: Equatable, Sendable {
  case new
  case waxingCrescent
  case firstQuarter
  case waxingGibbous
  case full
  case waningGibbous
  case lastQuarter
  case waningCrescent

  var displayName: String {
    switch self {
    case .new: "New Moon"
    case .waxingCrescent: "Waxing Crescent"
    case .firstQuarter: "First Quarter"
    case .waxingGibbous: "Waxing Gibbous"
    case .full: "Full Moon"
    case .waningGibbous: "Waning Gibbous"
    case .lastQuarter: "Last Quarter"
    case .waningCrescent: "Waning Crescent"
    }
  }

  var symbolName: String {
    switch self {
    case .new: "moon.fill"
    case .waxingCrescent: "moonphase.waxing.crescent"
    case .firstQuarter: "moonphase.first.quarter"
    case .waxingGibbous: "moonphase.waxing.gibbous"
    case .full: "moonphase.full.moon"
    case .waningGibbous: "moonphase.waning.gibbous"
    case .lastQuarter: "moonphase.last.quarter"
    case .waningCrescent: "moonphase.waning.crescent"
    }
  }

  /// Synodic-month fraction in `[0, 1)`.
  static func phase(on date: Date = Date()) -> (phase: MoonPhase, illumination: Double) {
    // Known new moon: 2000-01-06 18:14 UTC
    let reference = Date(timeIntervalSince1970: 947_182_440)
    let synodicDays = 29.530588853
    let days = date.timeIntervalSince(reference) / 86_400
    var age = days.truncatingRemainder(dividingBy: synodicDays)
    if age < 0 { age += synodicDays }
    let fraction = age / synodicDays
    let illumination = 0.5 * (1 - cos(2 * Double.pi * fraction))

    let phase: MoonPhase
    switch fraction {
    case 0..<0.0625, 0.9375...1: phase = .new
    case 0.0625..<0.1875: phase = .waxingCrescent
    case 0.1875..<0.3125: phase = .firstQuarter
    case 0.3125..<0.4375: phase = .waxingGibbous
    case 0.4375..<0.5625: phase = .full
    case 0.5625..<0.6875: phase = .waningGibbous
    case 0.6875..<0.8125: phase = .lastQuarter
    default: phase = .waningCrescent
    }
    return (phase, illumination)
  }
}
