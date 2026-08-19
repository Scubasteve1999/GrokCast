import Foundation
import UIKit

/// RadarScope-style warning boxes painted on Live Radar.
///
/// Same NWS alerts the HUD already uses. Advisories, watches, and statements
/// are never painted — a Heat Advisory polygon would bury the radar.
enum RadarWarningPolygon {
  enum Kind: String, Equatable, CaseIterable {
    case tornado
    case severeThunderstorm
    case flashFlood
    case specialMarine
    case snowSquall
    case extremeWind

    /// RadarScope convention: TOR red, SVR yellow, FFW green, SMW/SQW/EWW orange.
    var fillHex: String {
      switch self {
      case .tornado: return "#FF0000"
      case .severeThunderstorm: return "#FFD400"
      case .flashFlood: return "#00C800"
      case .specialMarine, .snowSquall, .extremeWind: return "#FF8C00"
      }
    }

    var lineHex: String { fillHex }

    var accessibilityLabel: String {
      switch self {
      case .tornado: return "Tornado warning area"
      case .severeThunderstorm: return "Severe thunderstorm warning area"
      case .flashFlood: return "Flash flood warning area"
      case .specialMarine: return "Special marine warning area"
      case .snowSquall: return "Snow squall warning area"
      case .extremeWind: return "Extreme wind warning area"
      }
    }

    var fillUIColor: UIColor {
      UIColor(hex: fillHex) ?? .systemRed
    }
  }

  struct Drawn: Identifiable, Equatable {
    let id: String
    let event: String
    let kind: Kind
    /// GeoJSON MultiPolygon coordinates `[polygon][ring][vertex][lon, lat]`.
    let coordinates: [[[[Double]]]]

    var fillHex: String { kind.fillHex }
    var lineHex: String { kind.lineHex }
    var accessibilityLabel: String { kind.accessibilityLabel }
  }

  static func kind(forEvent event: String) -> Kind? {
    let lower = event.lowercased()
    guard lower.contains("warning") else { return nil }
    if lower.contains("tornado") { return .tornado }
    if lower.contains("severe thunderstorm") { return .severeThunderstorm }
    if lower.contains("flash flood") { return .flashFlood }
    if lower.contains("special marine") { return .specialMarine }
    if lower.contains("snow squall") { return .snowSquall }
    if lower.contains("extreme wind") { return .extremeWind }
    return nil
  }

  static func drawn(from alerts: [NWSAlert]) -> [Drawn] {
    alerts.compactMap { alert in
      guard let kind = kind(forEvent: alert.event) else { return nil }
      guard let coordinates = sanitized(alert.polygonCoordinates), !coordinates.isEmpty
      else { return nil }
      return Drawn(
        id: alert.id,
        event: alert.event,
        kind: kind,
        coordinates: coordinates
      )
    }
  }

  /// Cheap identity so the map representable can skip redundant GeoJSON writes.
  static func overlaySignature(from alerts: [NWSAlert]) -> String {
    drawn(from: alerts)
      .map { item in
        let vertexCount = item.coordinates.reduce(0) { total, polygon in
          total + polygon.reduce(0) { $0 + $1.count }
        }
        return "\(item.id):\(item.kind.rawValue):\(vertexCount)"
      }
      .joined(separator: "|")
  }

  /// Drop empty / 1-number positions so Mapbox never sees a broken ring.
  static func sanitized(_ raw: [[[[Double]]]]?) -> [[[[Double]]]]? {
    guard let raw else { return nil }
    let polygons: [[[[Double]]]] = raw.compactMap { rings in
      let keptRings: [[[Double]]] = rings.compactMap { ring in
        let vertices = ring.filter { $0.count >= 2 }
        return vertices.count >= 3 ? vertices : nil
      }
      return keptRings.isEmpty ? nil : keptRings
    }
    return polygons.isEmpty ? nil : polygons
  }
}

private extension UIColor {
  convenience init?(hex: String) {
    var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.hasPrefix("#") { value.removeFirst() }
    guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
    let r = CGFloat((rgb >> 16) & 0xFF) / 255
    let g = CGFloat((rgb >> 8) & 0xFF) / 255
    let b = CGFloat(rgb & 0xFF) / 255
    self.init(red: r, green: g, blue: b, alpha: 1)
  }
}
