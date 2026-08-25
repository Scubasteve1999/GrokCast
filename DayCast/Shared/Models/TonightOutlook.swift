import Foundation

/// First-viewport “Tonight / This afternoon / This morning” line above the hourly graph.
/// Template from Open-Meteo hourly + the current AFD/PNS item. No Grok. No outfit tips.
enum TonightOutlook {
  struct Result: Equatable {
    let period: Period
    let title: String
    let sentence: String
  }

  enum Period: Equatable {
    case thisMorning
    case thisAfternoon
    case tonight

    var title: String {
      switch self {
      case .thisMorning: return "This morning"
      case .thisAfternoon: return "This afternoon"
      case .tonight: return "Tonight"
      }
    }
  }

  static let maxCharacterCount = 160

  static func make(
    weather: DayCastWeather,
    briefingItems: [LocalBriefingItem],
    unit: TemperatureUnit,
    now: Date = Date()
  ) -> Result {
    let calendar = weather.locationCalendar
    let sunrise = weather.daily.first?.sunrise
    let sunset = weather.daily.first?.sunset
    let period = Self.period(now: now, calendar: calendar, sunrise: sunrise, sunset: sunset)
    let window = Self.window(
      period: period, now: now, calendar: calendar, sunrise: sunrise, sunset: sunset)
    let hours = Self.hours(in: window, from: weather.hourly, now: now)
    let raw = sentence(
      period: period,
      hours: hours,
      weather: weather,
      briefingItems: briefingItems,
      unit: unit,
      now: now,
      calendar: calendar
    )
    let screened =
      GrokContentFilter.acceptedText(raw, maxCharacterCount: maxCharacterCount)
      ?? fallbackSentence(period: period, weather: weather, unit: unit)
    return Result(period: period, title: period.title, sentence: screened)
  }

  // MARK: - Period

  static func period(
    now: Date,
    calendar: Calendar,
    sunrise: Date?,
    sunset: Date?
  ) -> Period {
    let hour = calendar.component(.hour, from: now)
    if let sunset, now >= sunset { return .tonight }
    if hour < 5 { return .tonight }
    if hour >= 16 { return .tonight }
    if let sunset, now >= sunset.addingTimeInterval(-2 * 3600), hour >= 14 {
      return .tonight
    }
    if hour < 12 { return .thisMorning }
    return .thisAfternoon
  }

  static func window(
    period: Period,
    now: Date,
    calendar: Calendar,
    sunrise: Date?,
    sunset: Date?
  ) -> DateInterval {
    switch period {
    case .thisMorning:
      let noon =
        calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)
        ?? now.addingTimeInterval(4 * 3600)
      return DateInterval(start: now, end: max(noon, now.addingTimeInterval(3600)))
    case .thisAfternoon:
      let end =
        sunset
        ?? calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now)
        ?? now.addingTimeInterval(6 * 3600)
      return DateInterval(start: now, end: max(end, now.addingTimeInterval(3600)))
    case .tonight:
      let nextSunrise: Date
      if let sunrise, sunrise > now {
        nextSunrise = sunrise
      } else if let sunrise,
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: sunrise)
      {
        nextSunrise = tomorrow
      } else {
        nextSunrise =
          calendar.date(
            bySettingHour: 6, minute: 0, second: 0, of: now.addingTimeInterval(12 * 3600))
          ?? now.addingTimeInterval(10 * 3600)
      }
      return DateInterval(start: now, end: max(nextSunrise, now.addingTimeInterval(3600)))
    }
  }

  // MARK: - Sentence

  static func sentence(
    period: Period,
    hours: [HourlyForecast],
    weather: DayCastWeather,
    briefingItems: [LocalBriefingItem],
    unit: TemperatureUnit,
    now: Date,
    calendar: Calendar
  ) -> String {
    let sky = skyPhrase(period: period, hours: hours, weather: weather)
    let temp = tempPhrase(period: period, hours: hours, weather: weather, unit: unit)
    let precip = precipPhrase(period: period, hours: hours, calendar: calendar, now: now)
    let later = laterBriefingPhrase(
      period: period,
      hours: hours,
      briefingItems: briefingItems,
      now: now,
      calendar: calendar
    )

    var first = [sky, temp].compactMap { $0 }.joined(separator: ", ")
    if first.isEmpty {
      first = "\(period.title) stays \(unit.formatShort(weather.currentTemp))"
    }
    if !first.hasSuffix(".") { first += "." }

    var second: String?
    if let precip, !precip.isEmpty {
      second = precip
    } else if let later {
      second = later
    }

    if let second, !second.isEmpty {
      let clause = second.hasSuffix(".") ? second : second + "."
      return cap("\(first) \(clause)")
    }
    return cap(first)
  }

  // MARK: - Sky / temp / precip

  private static func skyPhrase(
    period: Period,
    hours: [HourlyForecast],
    weather: DayCastWeather
  ) -> String? {
    let codes = hours.map(\.weatherCode)
    let wet = hours.contains { $0.precipChance >= 40 && isWetCode($0.weatherCode) }
    let storms = hours.contains { isStormCode($0.weatherCode) && $0.precipChance >= 30 }
    if storms {
      switch period {
      case .tonight: return "Storms tonight"
      case .thisAfternoon: return "Storms this afternoon"
      case .thisMorning: return "Storms this morning"
      }
    }
    if wet {
      let type = dominantPrecipType(hours)
      switch period {
      case .tonight: return "\(type) overnight"
      case .thisAfternoon: return "\(type) this afternoon"
      case .thisMorning: return "\(type) this morning"
      }
    }

    let clearish = codes.filter { $0 == 0 || $0 == 1 }
    let cloudy = codes.filter { $0 == 2 || $0 == 3 }
    let foggy = codes.filter { $0 == 45 || $0 == 48 }
    if !hours.isEmpty, clearish.count * 2 >= hours.count {
      switch period {
      case .tonight: return "Clear tonight"
      case .thisAfternoon: return "Mostly sunny"
      case .thisMorning: return "Mostly sunny this morning"
      }
    }
    if foggy.count * 2 >= max(hours.count, 1) {
      switch period {
      case .tonight: return "Foggy tonight"
      default: return "Foggy"
      }
    }
    if cloudy.count * 2 >= max(hours.count, 1) {
      let word = codes.contains(3) ? "Cloudy" : "Partly cloudy"
      switch period {
      case .tonight: return "\(word) tonight"
      default: return word
      }
    }
    if hours.isEmpty {
      let text = weather.conditionText.lowercased()
      if text.contains("clear") || text.contains("sunny") {
        return period == .tonight ? "Clear tonight" : "Mostly sunny"
      }
    }
    return period == .tonight ? "Quiet tonight" : nil
  }

  private static func tempPhrase(
    period: Period,
    hours: [HourlyForecast],
    weather: DayCastWeather,
    unit: TemperatureUnit
  ) -> String? {
    let temps = hours.map(\.temp)
    let minTemp = temps.min() ?? weather.low
    let maxTemp = temps.max() ?? weather.high
    switch period {
    case .tonight:
      let low = min(minTemp, weather.low)
      return "cooling to \(unit.formatShort(low))"
    case .thisAfternoon:
      if abs(maxTemp - minTemp) < 2 {
        return "staying \(unit.formatShort(maxTemp))"
      }
      return "\(unit.formatShort(minTemp))–\(unit.formatShort(maxTemp))"
    case .thisMorning:
      return "staying \(unit.formatShort(minTemp))"
    }
  }

  private static func precipPhrase(
    period: Period,
    hours: [HourlyForecast],
    calendar: Calendar,
    now: Date
  ) -> String? {
    guard let peak = hours.max(by: { $0.precipChance < $1.precipChance }) else { return nil }
    if peak.precipChance < 20 { return nil }
    let type = dominantPrecipType(hours.filter { $0.precipChance >= 20 })
    let when = hourLabel(peak.time, calendar: calendar)
    let peakIsNow = peak.time.timeIntervalSince(now) < 45 * 60
    if peak.precipChance >= 40 {
      if peakIsNow {
        let windowWord = period == .tonight ? "overnight" : period.title.lowercased()
        return "\(type) odds stay near \(peak.precipChance)% \(windowWord)"
      }
      return "\(type) odds reach \(peak.precipChance)% by \(when)"
    }
    if peakIsNow {
      return "A slight \(type.lowercased()) chance, near \(peak.precipChance)%"
    }
    return "A slight \(type.lowercased()) chance, peaking at \(peak.precipChance)% by \(when)"
  }

  // MARK: - AFD / PNS weave

  /// Grounded later-or-same-period fact from the office product. Never invents tornadoes.
  static func laterBriefingPhrase(
    period: Period,
    hours: [HourlyForecast],
    briefingItems: [LocalBriefingItem],
    now: Date,
    calendar: Calendar
  ) -> String? {
    guard let title = briefingItems.first?.title, !title.isEmpty else { return nil }
    let lower = title.lowercased()
    if isSurveyOrAdmin(lower) { return nil }
    if mentionsTornado(lower), !hoursContainStorm(hours) { return nil }

    let todayName = weekdayName(now, calendar: calendar)
    if let laterDay = mentionedWeekday(in: lower), laterDay != todayName {
      let when = timingSuffix(in: lower, weekday: laterDay)
      if lower.contains("isolated"),
        lower.contains("thunderstorm") || lower.contains("shower")
      {
        return "Isolated storms wait until \(when)"
      }
      if lower.contains("thunderstorm") || lower.contains("shower") {
        return "Storm chances wait until \(when)"
      }
      return nil
    }

    let talksThisPeriod: Bool = {
      switch period {
      case .tonight:
        return lower.contains("tonight") || lower.contains("overnight")
          || lower.contains("after dark")
      case .thisAfternoon:
        return lower.contains("this afternoon") || lower.contains("afternoon")
      case .thisMorning:
        return lower.contains("this morning") || lower.contains("morning")
      }
    }()
    guard talksThisPeriod else { return nil }
    if lower.contains("thunderstorm") || lower.contains("shower") {
      if period == .tonight {
        return "Showers still have a window after dark"
      }
    }
    return nil
  }

  // MARK: - Helpers

  static func hours(
    in window: DateInterval,
    from hourly: [HourlyForecast],
    now: Date
  ) -> [HourlyForecast] {
    let cutoff = now.addingTimeInterval(-45 * 60)
    return hourly.filter { hour in
      hour.time >= cutoff && hour.time < window.end
    }
  }

  private static func fallbackSentence(
    period: Period,
    weather: DayCastWeather,
    unit: TemperatureUnit
  ) -> String {
    "\(period.title): \(unit.formatShort(weather.currentTemp)) and \(weather.conditionText.lowercased())."
  }

  private static func dominantPrecipType(_ hours: [HourlyForecast]) -> String {
    let wet = hours.filter { $0.precipChance >= 15 }
    let source = wet.isEmpty ? hours : wet
    var rain = 0
    var snow = 0
    var storm = 0
    for hour in source {
      if isStormCode(hour.weatherCode) {
        storm += 1
      } else if isSnowCode(hour.weatherCode) {
        snow += 1
      } else if isWetCode(hour.weatherCode) {
        rain += 1
      }
    }
    if storm >= rain, storm >= snow, storm > 0 { return "Storm" }
    if snow > rain { return "Snow" }
    return "Rain"
  }

  private static func hourLabel(_ date: Date, calendar: Calendar) -> String {
    LocationTimezone.formatter(dateFormat: "h a", timeZone: calendar.timeZone)
      .string(from: date)
      .replacingOccurrences(of: " ", with: "")
      .uppercased()
  }

  private static func weekdayName(_ date: Date, calendar: Calendar) -> String {
    LocationTimezone.formatter(dateFormat: "EEEE", timeZone: calendar.timeZone)
      .string(from: date)
      .lowercased()
  }

  private static let weekdays = [
    "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
  ]

  private static func mentionedWeekday(in lower: String) -> String? {
    weekdays.first { lower.contains($0) }
  }

  private static func timingSuffix(in lower: String, weekday: String) -> String {
    let day = weekday.capitalized
    if lower.contains("morning") { return "\(day) morning" }
    if lower.contains("afternoon") { return "\(day) afternoon" }
    if lower.contains("evening") || lower.contains("tonight") { return "\(day) evening" }
    return day
  }

  private static func isSurveyOrAdmin(_ lower: String) -> Bool {
    if lower.contains("damage survey") || lower.contains("survey") && lower.contains("tornado") {
      return true
    }
    if lower.contains("nwr") || lower.contains("weather radio") { return true }
    return false
  }

  private static func mentionsTornado(_ lower: String) -> Bool {
    lower.contains("tornado")
  }

  private static func hoursContainStorm(_ hours: [HourlyForecast]) -> Bool {
    hours.contains { isStormCode($0.weatherCode) && $0.precipChance >= 20 }
  }

  private static func isWetCode(_ code: Int) -> Bool {
    switch code {
    case 51, 53, 55, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99:
      return true
    default:
      return false
    }
  }

  private static func isStormCode(_ code: Int) -> Bool {
    switch code {
    case 95, 96, 99: return true
    default: return false
    }
  }

  private static func isSnowCode(_ code: Int) -> Bool {
    switch code {
    case 71, 73, 75, 77, 85, 86: return true
    default: return false
    }
  }

  private static func cap(_ string: String) -> String {
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let first = trimmed.first else { return trimmed }
    return String(first).uppercased() + trimmed.dropFirst()
  }
}
