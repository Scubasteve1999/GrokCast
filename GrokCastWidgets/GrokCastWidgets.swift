import SwiftUI
import WidgetKit

@main
struct GrokCastWidgets: WidgetBundle {
  var body: some Widget {
    GrokCastSmallWeatherWidget()
    GrokCastMediumWeatherWidget()
    GrokCastLargeWeatherWidget()
    GrokCastLockScreenWeatherWidget()
    WeatherLiveActivityWidget()
  }
}
