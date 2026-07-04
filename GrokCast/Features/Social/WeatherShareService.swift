import SwiftUI
import UIKit

@MainActor
enum WeatherShareService {
  @available(iOS 16.0, *)
  static func renderCardImage(
    weather: GrokCastWeather,
    score: GrokCastScore,
    locationName: String,
    grokBrief: String?
  ) -> UIImage? {
    let card = WeatherShareCard(
      weather: weather,
      score: score,
      locationName: locationName,
      grokBrief: grokBrief
    )

    let renderer = ImageRenderer(content: card)
    renderer.scale = 3.0
    return renderer.uiImage
  }

  static func shareItems(
    weather: GrokCastWeather,
    score: GrokCastScore,
    locationName: String,
    grokBrief: String?
  ) -> [Any] {
    var items: [Any] = []

    if let image = renderCardImage(
      weather: weather,
      score: score,
      locationName: locationName,
      grokBrief: grokBrief
    ) {
      items.append(image)
    }

    let text = ShareableBriefText.weatherBrief(
      locationName: locationName,
      temperatureLine: "\(Int(weather.currentTemp.rounded()))°F",
      condition: weather.conditionText,
      brief: grokBrief ?? "Score: \(score.value) — \(score.label)"
    )
    items.append(text)

    return items
  }
}
