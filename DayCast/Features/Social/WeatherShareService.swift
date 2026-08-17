import SwiftUI
import UIKit

@MainActor
enum WeatherShareService {
  @available(iOS 16.0, *)
  static func renderCardImage(
    weather: DayCastWeather,
    score: DayCastScore,
    locationName: String,
    grokBrief: String?,
    unit: TemperatureUnit
  ) -> UIImage? {
    let card = WeatherShareCard(
      weather: weather,
      score: score,
      locationName: locationName,
      grokBrief: grokBrief,
      unit: unit
    )

    let renderer = ImageRenderer(content: card)
    renderer.scale = 3.0
    return renderer.uiImage
  }

  static func shareItems(
    weather: DayCastWeather,
    score: DayCastScore,
    locationName: String,
    grokBrief: String?,
    unit: TemperatureUnit
  ) -> [Any] {
    var items: [Any] = []

    if let image = renderCardImage(
      weather: weather,
      score: score,
      locationName: locationName,
      grokBrief: grokBrief,
      unit: unit
    ) {
      items.append(image)
    }

    let text = ShareableBriefText.weatherBrief(
      locationName: locationName,
      temperatureLine: unit.format(weather.currentTemp),
      condition: weather.conditionText,
      brief: grokBrief ?? "Score: \(score.value) — \(score.label)"
    )
    items.append(text)

    return items
  }
}
