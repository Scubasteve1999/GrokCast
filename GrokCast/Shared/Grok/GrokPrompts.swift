//
//  GrokPrompts.swift
//  GrokCast
//
//  Centralized system prompts for Grok AI features.
//  Keeps prompting logic maintainable and separate from service code.
//

import Foundation

enum GrokPrompts {

  // MARK: - Storm Spotter / Advanced Technical Analysis

  /// High-quality system prompt for technical sky and storm photo analysis.
  /// Designed for serious spotters, chasers, and meteorology enthusiasts.
  static let stormSpotterSystemPrompt = """
    You are a witty AI weather assistant, an expert meteorological analyst and storm spotter assistant for SpotterCast.

    Your job is to give precise, field-useful analysis of sky and storm photographs by combining the image with real-time surface observations and short-term guidance.

    Focus areas (in priority order):
    - Cloud identification and key morphological features
    - Low-level storm features (inflow, gust fronts, wall clouds, beaver tails, shelf clouds, etc.)
    - Overall storm organization and signs of evolution or rapid change
    - Severe weather indicators visible or strongly implied
    - Clear distinction between what can be directly observed in the image versus what is inferred from the data or photo characteristics
    - Actionable implications for spotters in the field

    Guidelines:
    - Clearly separate direct visual observations from inferences.
    - Be specific and technical while remaining practical for experienced amateur spotters.
    - Prioritize actionable field intelligence.
    - Flag uncertainty when it exists.
    - Use standard meteorological terminology without becoming overly academic.
    """

  /// Builds a focused technical weather context for storm analysis.
  /// Prefers `severeContext` (alerts + SPC products); falls back to `alerts` alone.
  static func buildTechnicalStormContext(
    for weather: GrokCastWeather,
    alerts: [NWSAlert] = [],
    severeContext: SevereWeatherContext? = nil,
    shortTermContext: ShortTermPrecipContext? = nil,
    nearestStationObservation: NWSObservation? = nil,
    userNotes: String? = nil
  ) -> String {
    let temp = Int(round(weather.currentTemp))
    let feels = Int(round(weather.feelsLike))
    let humidity = weather.humidity
    let wind = Int(round(weather.windSpeed))
    let precip = weather.precipitationChance

    var context = """
      Current conditions — \(weather.location.name):
      Temperature: \(temp)°F (feels \(feels)°F)
      Humidity: \(humidity)%
      Wind: \(wind) mph
      Conditions: \(weather.conditionText)
      Precipitation chance: \(precip)%
      """

    if let obs = nearestStationObservation {
      let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
      }()
      let timeStr = timeFormatter.string(from: obs.observedAt)
      context +=
        "\n\n**Nearest official NWS station observation (\(obs.stationId) as of \(timeStr)):**"
      if let t = obs.temperatureF {
        context += "\nTemperature: \(Int(round(t)))°F"
      }
      if let w = obs.windSpeedMph {
        context += "\nWind: \(Int(round(w))) mph"
        if let dir = obs.windDirectionDegrees {
          context += " from \(dir)°"
        }
      }
    }

    // WeatherStore CAP alerts win when severe context's embedded fetch was empty/failed.
    let resolvedAlerts: [NWSAlert] = {
      guard let severeAlerts = severeContext?.alerts else { return alerts }
      if severeAlerts.isEmpty { return alerts }
      if alerts.isEmpty { return severeAlerts }
      return alerts
    }()
    if !resolvedAlerts.isEmpty {
      context += "\n\n**Active NWS Alerts for this area:**"
      for a in resolvedAlerts {
        let sev = a.severity ?? "Unknown"
        context += "\n- \(a.event) (\(sev))"
        if let h = a.headline, !h.isEmpty {
          context += ": \(h)"
        }
        if let area = a.areaDesc, !area.isEmpty {
          context += " — \(area)"
        }
        if a.containsSelectedPoint {
          context += " [covers selected location]"
        }
        if let bbox = a.geometryBBoxSummary, !bbox.isEmpty {
          context += " (polygon ~\(bbox)"
          if let verts = a.geometryVertexCount {
            context += ", \(verts) verts"
          }
          context += ")"
        }
      }
    }

    if let severeBlock = severeContextBlock(context: severeContext), !severeBlock.isEmpty {
      context += "\n\n" + severeBlock
    }

    if let shortTermBlock = shortTermPrecipBlock(
      context: shortTermContext,
      openMeteoSlots: weather.minutely15
    ), !shortTermBlock.isEmpty {
      context += "\n\n" + shortTermBlock
    }

    if let notes = userNotes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
      context += "\n\nObserver notes: \(notes)"
    }

    return context
  }

  /// Short-term (0–90 min) precip block when CONUS HRRR slots are available.
  static func shortTermPrecipBlock(
    context: ShortTermPrecipContext?,
    openMeteoSlots: [MinutelyForecast] = []
  ) -> String? {
    guard let context, context.hasHRRRSlots else { return nil }
    let summary =
      context.summary
      ?? MinutecastEngine.summary(from: context.slots)
    var lines: [String] = [
      "- Source: HRRR 15-min (Open-Meteo GFS)",
      "- Outlook: \(summary.message)",
    ]
    let slotBits = context.slots.prefix(6).map { slot in
      let mins = max(0, Int(slot.time.timeIntervalSinceNow / 60))
      let precip = String(format: "%.3f", slot.precipitation)
      return "+\(mins)m: \(precip) in, \(slot.precipChance)%"
    }
    if !slotBits.isEmpty {
      lines.append("- Slots: \(slotBits.joined(separator: "; "))")
    }
    if !openMeteoSlots.isEmpty {
      let agreement = MinutecastAgreement.compare(
        hrrr: context.slots, openMeteo: openMeteoSlots)
      if let note = MinutecastAgreement.grokNote(for: agreement) {
        lines.append("- \(note)")
      }
    }
    return "**Short-term precip (0–90 min):**\n" + lines.joined(separator: "\n")
  }

  /// Short severe-guidance block for Grok briefs/chat when SPC/MD/LSR content exists.
  static func severeContextBlock(context: SevereWeatherContext?) -> String? {
    guard let context else { return nil }
    var lines: [String] = []

    if context.day1Outlook.isMeaningful {
      lines.append("- \(context.day1Outlook.summaryLine)")
      if let detail = context.day1Outlook.labelDetail, !detail.isEmpty {
        lines.append("  \(detail)")
      }
    }

    if !context.mesoscaleDiscussions.isEmpty {
      let mdSummaries = context.mesoscaleDiscussions.prefix(4).map { md in
        if let detail = md.detailLine, !detail.isEmpty {
          return "\(md.title): \(detail)"
        }
        return md.title
      }
      lines.append("- Active mesoscale discussions: \(mdSummaries.joined(separator: "; "))")
    }

    if !context.localStormReports.isEmpty {
      let lsrSummaries = context.localStormReports.prefix(5).map { report in
        let sub = report.subtitle
        return sub.isEmpty ? report.title : "\(report.title) — \(sub)"
      }
      lines.append("- Nearby local storm reports: \(lsrSummaries.joined(separator: "; "))")
    }

    guard !lines.isEmpty else { return nil }
    return "**Severe guidance:**\n" + lines.joined(separator: "\n")
  }

  /// Assembles the full prompt for a storm spotter vision request.
  /// nearestStationObservation + alerts forwarded so the technical context includes official NWS ground truth + warnings.
  static func stormSpotterVisionPrompt(
    for weather: GrokCastWeather,
    alerts: [NWSAlert] = [],
    severeContext: SevereWeatherContext? = nil,
    shortTermContext: ShortTermPrecipContext? = nil,
    nearestStationObservation: NWSObservation? = nil,
    userNotes: String?
  ) -> String {
    var prompt = stormSpotterSystemPrompt + "\n\n"
    prompt += buildTechnicalStormContext(
      for: weather,
      alerts: alerts,
      severeContext: severeContext,
      shortTermContext: shortTermContext,
      nearestStationObservation: nearestStationObservation,
      userNotes: userNotes)

    prompt += """

      Analyze the attached photograph using the conditions above.
      Clearly separate direct visual observations from inferences.
      Highlight any notable low-level features, storm organization, or evolution signals.
      Include practical implications for spotters when relevant.
      """

    return prompt
  }
}
