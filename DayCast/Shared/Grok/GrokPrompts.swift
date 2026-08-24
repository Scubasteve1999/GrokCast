//
//  GrokPrompts.swift
//  DayCast
//
//  Centralized system prompts for Grok AI features.
//  Keeps prompting logic maintainable and separate from service code.
//

import Foundation

enum GrokPrompts {

  // MARK: - Storm Spotter / Advanced Technical Analysis

  /// High-quality system prompt for technical sky and storm photo analysis.
  static let stormSpotterSystemPrompt = """
    You are Sky Check in DayCast — an expert meteorological analyst.

    Your job is to give precise, field-useful analysis of sky and storm photographs by combining the image with real-time surface observations and short-term guidance.

    This analysis is not an NWS product and is not a warning. Do not invent warnings. Clearly distinguish what is observed in the photograph from what is inferred from data or photo characteristics.

    Focus areas (in priority order):
    - Cloud identification and key morphological features
    - Low-level storm features (inflow, gust fronts, wall clouds, beaver tails, shelf clouds, etc.)
    - Overall storm organization and signs of evolution or rapid change
    - Severe weather indicators visible or strongly implied
    - Clear distinction between what can be directly observed in the image versus what is inferred from the data or photo characteristics
    - Actionable implications for people outdoors

    Guidelines:
    - Clearly separate direct visual observations from inferences.
    - Be specific and technical while remaining practical.
    - Prioritize actionable field intelligence.
    - Flag uncertainty when it exists.
    - Use standard meteorological terminology without becoming overly academic.
    """

  /// Shared current-conditions block for chat, Imagine, and Storm Spotter.
  static func currentConditionsBlock(
    weather: DayCastWeather,
    locationName: String,
    unit: TemperatureUnit
  ) -> String {
    """
    Current conditions for \(locationName):
    - Temperature: \(unit.format(weather.currentTemp))
    - Condition: \(weather.conditionText)
    - Feels like: \(unit.format(weather.feelsLike))
    - Humidity: \(weather.humidity)%
    - Wind: \(unit.formatWind(weather.windSpeed))
    """
  }

  /// Builds a focused technical weather context for storm analysis.
  /// Prefers `severeContext` (alerts + SPC products); falls back to `alerts` alone.
  static func buildTechnicalStormContext(
    for weather: DayCastWeather,
    unit: TemperatureUnit = .fahrenheit,
    alerts: [NWSAlert] = [],
    severeContext: SevereWeatherContext? = nil,
    shortTermContext: ShortTermPrecipContext? = nil,
    nearestStationObservation: NWSObservation? = nil,
    userNotes: String? = nil
  ) -> String {
    var context = currentConditionsBlock(
      weather: weather, locationName: weather.location.name, unit: unit)
    context += "\n- Precipitation chance: \(weather.precipitationChance)%"

    if let obsBlock = nwsObservationBlock(nearestStationObservation, unit: unit) {
      context += "\n\n" + obsBlock
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
      context += "\n\nUser notes: \(notes)"
    }

    return context
  }

  /// Official nearest-station observation. Shared by vision and Sky Check chat.
  static func nwsObservationBlock(
    _ observation: NWSObservation?,
    unit: TemperatureUnit
  ) -> String? {
    guard let obs = observation else { return nil }
    let timeFormatter: DateFormatter = {
      let f = DateFormatter()
      f.dateFormat = "HH:mm"
      f.locale = Locale(identifier: "en_US_POSIX")
      return f
    }()
    let timeStr = timeFormatter.string(from: obs.observedAt)
    var block =
      "**Nearest official NWS station observation (\(obs.stationId) as of \(timeStr)):**"
    if let t = obs.temperatureF {
      block += "\nTemperature: \(unit.formatFromFahrenheit(t))"
    }
    if let w = obs.windSpeedMph {
      block += "\nWind: \(unit.formatWindFromMph(w))"
      if let dir = obs.windDirectionDegrees {
        block += " from \(dir)°"
      }
    }
    return block
  }

  /// Next ~12–24 hourly slots (temp, precip %, amount when present).
  static func hourlyOutlookBlock(
    hourly: [HourlyForecast],
    unit: TemperatureUnit,
    timeZone: TimeZone,
    now: Date = Date(),
    maxHours: Int = 24
  ) -> String? {
    let cutoff = now.addingTimeInterval(-45 * 60)
    var upcoming = hourly.filter { $0.time >= cutoff }
    if upcoming.isEmpty { upcoming = hourly }
    let slice = Array(upcoming.prefix(maxHours))
    guard !slice.isEmpty else { return nil }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "h a"

    var lines: [String] = ["**Next 12–24 hours:**"]
    for hour in slice {
      var bit =
        "- \(formatter.string(from: hour.time)): \(unit.format(hour.temp)), \(hour.precipChance)% precip"
      let liquid = (hour.rain ?? 0) + (hour.showers ?? 0)
      let snow = hour.snowfall ?? 0
      if let amount = precipAmountText(liquid: liquid, snow: snow) {
        bit += ", \(amount)"
      }
      lines.append(bit)
    }
    return lines.joined(separator: "\n")
  }

  /// AFD KEY MESSAGES / PNS titles as issued. Chat must not rewrite this text.
  static func localBriefingBlock(items: [LocalBriefingItem]) -> String? {
    let usable = items.filter {
      !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    guard !usable.isEmpty else { return nil }
    let source = usable.first?.sourceName ?? "NWS"
    var lines: [String] = [
      "**NWS local briefing (\(source)):**",
      "Quoted as issued from AFD/PNS. Do not rewrite or invent AFD text.",
    ]
    for item in usable.prefix(LocalBriefingParser.maxCards) {
      lines.append("- [\(item.productCode)] \(item.title)")
    }
    return lines.joined(separator: "\n")
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
    for weather: DayCastWeather,
    unit: TemperatureUnit = .fahrenheit,
    alerts: [NWSAlert] = [],
    severeContext: SevereWeatherContext? = nil,
    shortTermContext: ShortTermPrecipContext? = nil,
    nearestStationObservation: NWSObservation? = nil,
    userNotes: String?
  ) -> String {
    var prompt = stormSpotterSystemPrompt + "\n\n"
    prompt += buildTechnicalStormContext(
      for: weather,
      unit: unit,
      alerts: alerts,
      severeContext: severeContext,
      shortTermContext: shortTermContext,
      nearestStationObservation: nearestStationObservation,
      userNotes: userNotes)

    prompt += """

      Analyze the attached photograph using the conditions above.
      Clearly separate direct visual observations from inferences.
      Highlight any notable low-level features, storm organization, or evolution signals.
      Include practical implications for people outdoors when relevant.
      """

    return prompt
  }

  /// Chat-desk identity. Not field-first / chase / SRV. Do not invent radar reads.
  static let skyCheckChatIdentity = """
    You are Sky Check in DayCast — an honest weather desk for the public. \
    Answer questions about the sky, hazards, timing, and what to watch next. \
    Use only the data provided. Cite NWS, HRRR, or AFD when you use those blocks. \
    Do not invent radar reads, warnings, or numbers that are not in the data.
    """

  static func skyCheckChatSystemPrompt(
    conditionsBlock: String?,
    alertLines: String = "",
    severeExtra: String = ""
  ) -> String {
    skyCheckChatSystemPrompt(
      conditionsBlock: conditionsBlock,
      groundedBlocks: alertLines + severeExtra
    )
  }

  /// Grounded Sky Check chat. Reuses current-conditions / obs / HRRR / severe / AFD builders.
  static func skyCheckChatSystemPrompt(
    weather: DayCastWeather?,
    locationName: String,
    unit: TemperatureUnit = .fahrenheit,
    alerts: [NWSAlert] = [],
    severeContext: SevereWeatherContext? = nil,
    shortTermContext: ShortTermPrecipContext? = nil,
    nearestStationObservation: NWSObservation? = nil,
    briefingItems: [LocalBriefingItem] = [],
    now: Date = Date()
  ) -> String {
    guard let weather else {
      return skyCheckChatSystemPrompt(conditionsBlock: nil)
    }

    let conditions = currentConditionsBlock(
      weather: weather, locationName: locationName, unit: unit)

    var extras: [String] = []
    if let obs = nwsObservationBlock(nearestStationObservation, unit: unit) {
      extras.append(obs)
    }
    if let hourly = hourlyOutlookBlock(
      hourly: weather.hourly,
      unit: unit,
      timeZone: weather.locationTimeZone,
      now: now
    ) {
      extras.append(hourly)
    }
    if let shortTerm = shortTermPrecipBlock(
      context: shortTermContext,
      openMeteoSlots: weather.minutely15
    ) {
      extras.append(shortTerm)
    }

    let alertPrefix = Array(alerts.prefix(5))
    if !alertPrefix.isEmpty {
      let lines = alertPrefix.map { a in
        let sev = a.severity ?? "Unknown"
        return "- \(a.event) (\(sev))"
      }.joined(separator: "\n")
      extras.append("Active NWS alerts:\n" + lines)
    }
    if let severe = severeContextBlock(context: severeContext), !severe.isEmpty {
      extras.append(severe)
    }
    if let briefing = localBriefingBlock(items: briefingItems) {
      extras.append(briefing)
    }

    let grounded = extras.isEmpty ? "" : "\n" + extras.joined(separator: "\n\n") + "\n"
    return skyCheckChatSystemPrompt(
      conditionsBlock: conditions,
      groundedBlocks: grounded
    )
  }

  static func skyCheckChatSystemPrompt(
    conditionsBlock: String?,
    groundedBlocks: String
  ) -> String {
    guard let conditionsBlock else {
      return """
        \(skyCheckChatIdentity) \
        Lifestyle advice only if the user asks. Be concise. Do not invent warnings.
        """
    }
    return """
      \(skyCheckChatIdentity) \
      Lifestyle advice (outfits, walks) only if the user asks.

      \(conditionsBlock)
      \(groundedBlocks)
      Be concise and practical. Lead with what's happening and what to watch next. Do not invent warnings.
      """
  }
}
