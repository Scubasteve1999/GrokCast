import Foundation

/// One Today's Take generate path for morning prewarm, `fetchWeatherBrief`, and cache write.
enum GrokBriefGenerator {
  enum GenerateError: LocalizedError {
    case missingWeather
    case emptyResponse

    var errorDescription: String? {
      switch self {
      case .missingWeather:
        "Weather data isn't loaded yet. Pull to refresh and try again."
      case .emptyResponse:
        "AI returned an empty response. Check your connection and try again."
      }
    }
  }

  static let takeUserMessage = "Give me today's weather take."
  static let takeMaxTokens = 280

  /// Assembles the Take prompt, calls Grok, finalizes, and writes `GrokBriefCache`.
  /// Extra blocks match the morning path (severe + HRRR); they no-op when stores are empty.
  @MainActor
  static func generate(for store: WeatherStore, feature: GrokFeature) async throws -> String {
    guard let weather = store.currentWeather else { throw GenerateError.missingWeather }

    let location = store.currentLocation?.name ?? weather.location.name
    let unit = store.temperatureUnit
    let alertEvents = Array(
      NWSAlertGrouping.uniqueEvents(from: store.displayableActiveAlerts).prefix(3))

    let system = GrokPrompts.todaysTakeSystemPrompt(
      location: location,
      weather: weather,
      unit: unit,
      alertLine: alertEvents.joined(separator: ", "),
      extraBlocks: extraBlocks(for: store, weather: weather)
    )

    let streamed = try await GrokBuildService.complete(
      messages: [
        GrokBuildMessage(role: "system", content: system),
        GrokBuildMessage(role: "user", content: takeUserMessage),
      ],
      feature: feature,
      maxTokens: takeMaxTokens
    )
    let raw =
      streamed.isEmpty
      ? LocalWeatherBrief.make(
        weather: weather,
        unit: unit,
        locationName: location,
        activeAlerts: alertEvents
      )
      : streamed

    guard
      let brief = GrokBriefText.finalize(
        raw: raw,
        weather: weather,
        unit: unit,
        locationName: location,
        activeAlerts: alertEvents
      )
    else { throw GenerateError.emptyResponse }

    if !GrokBriefSafety.shared.isBriefHidden(brief) {
      GrokBriefCache.save(brief, for: store)
    }
    return brief
  }

  @MainActor
  private static func extraBlocks(for store: WeatherStore, weather: DayCastWeather) -> String {
    let locationKey = store.currentLocation?.id.uuidString
    let severe = SevereWeatherStore.shared.context
    let severeBlock: String = {
      guard severe.locationID == locationKey,
        let block = GrokPrompts.severeContextBlock(context: severe)
      else { return "" }
      return "\n\(block)"
    }()
    let shortTerm = ShortTermPrecipStore.shared.context
    let shortTermBlock: String = {
      guard shortTerm.locationID == locationKey,
        let block = GrokPrompts.shortTermPrecipBlock(
          context: shortTerm,
          openMeteoSlots: weather.minutely15
        )
      else { return "" }
      return "\n\(block)"
    }()
    return severeBlock + shortTermBlock
  }
}
