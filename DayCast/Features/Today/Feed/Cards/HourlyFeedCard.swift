import SwiftUI

struct HourlyFeedCard: View {
  let weather: DayCastWeather
  var onTap: () -> Void

  private var hours: [HourlyForecast] {
    HourlyGraphHours.upcoming(from: weather)
  }

  var body: some View {
    HourlyGraphView(
      hours: hours,
      series: .temp,
      sunrise: weather.daily.first?.sunrise,
      sunset: weather.daily.first?.sunset,
      timeZone: weather.locationTimeZone
    )
    .frame(height: TodayGlanceLayout.hourlyGraphHeight)
    .contentShape(Rectangle())
    .onTapGesture {
      onTap()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilitySummary)
    .accessibilityAddTraits(.isButton)
  }

  private var accessibilitySummary: String {
    Self.accessibilityLabel(
      hourLabel: hours.isEmpty ? nil : "Now",
      temp: hours.first.map { Int(round($0.temp)) },
      precipChance: hours.first?.precipChance
    )
  }

  /// One VoiceOver string for the whole card. Children stay visual-only.
  static func accessibilityLabel(
    title: String? = nil,
    sentence: String? = nil,
    hourLabel: String?,
    temp: Int?,
    precipChance: Int?,
    opensForecast: Bool = true
  ) -> String {
    var parts: [String] = []
    if let title, !title.isEmpty { parts.append(title) }
    if let sentence, !sentence.isEmpty { parts.append(sentence) }
    if let hourLabel, let temp, let precipChance {
      parts.append(
        "\(hourLabel) \(temp) degrees, \(precipChance) percent chance of precipitation.")
    }
    if parts.isEmpty {
      return opensForecast ? "Hourly forecast. Opens full forecast." : "Hourly forecast."
    }
    if opensForecast {
      parts.append("Opens full forecast.")
    }
    return parts.joined(separator: " ")
  }
}
