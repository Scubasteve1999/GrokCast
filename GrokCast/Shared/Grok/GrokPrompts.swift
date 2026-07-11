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
    You are an expert meteorological analyst and storm spotter assistant for SpotterCast.

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
    /// Now includes optional active NWS alerts and nearest station observation (hybrid data) when present.
    static func buildTechnicalStormContext(
        for weather: GrokCastWeather,
        alerts: [NWSAlert] = [],
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
            context += "\n\n**Nearest official NWS station observation (\(obs.stationId) as of \(timeStr)):**"
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

        if !alerts.isEmpty {
            context += "\n\n**Active NWS Alerts for this area:**"
            for a in alerts {
                let sev = a.severity ?? "Unknown"
                context += "\n- \(a.event) (\(sev))"
                if let h = a.headline, !h.isEmpty {
                    context += ": \(h)"
                }
                if let area = a.areaDesc, !area.isEmpty {
                    context += " — \(area)"
                }
            }
        }

        if let notes = userNotes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            context += "\n\nObserver notes: \(notes)"
        }

        return context
    }
    
    /// Assembles the full prompt for a storm spotter vision request.
    /// nearestStationObservation + alerts forwarded so the technical context includes official NWS ground truth + warnings.
    static func stormSpotterVisionPrompt(
        for weather: GrokCastWeather,
        alerts: [NWSAlert] = [],
        nearestStationObservation: NWSObservation? = nil,
        userNotes: String?
    ) -> String {
        var prompt = stormSpotterSystemPrompt + "\n\n"
        prompt += buildTechnicalStormContext(for: weather, alerts: alerts, nearestStationObservation: nearestStationObservation, userNotes: userNotes)
        
        prompt += """
        
        Analyze the attached photograph using the conditions above.
        Clearly separate direct visual observations from inferences.
        Highlight any notable low-level features, storm organization, or evolution signals.
        Include practical implications for spotters when relevant.
        """
        
        return prompt
    }
}
