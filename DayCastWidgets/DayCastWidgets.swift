import SwiftUI
import WidgetKit

@main
struct DayCastWidgets: WidgetBundle {
  var body: some Widget {
    DayCastSmallWeatherWidget()
    DayCastMediumWeatherWidget()
    DayCastLargeWeatherWidget()
    DayCastLockScreenWeatherWidget()
    WeatherLiveActivityWidget()
  }
}
