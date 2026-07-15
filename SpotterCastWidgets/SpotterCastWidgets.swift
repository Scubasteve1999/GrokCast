import SwiftUI
import WidgetKit

@main
struct SpotterCastWidgets: WidgetBundle {
  var body: some Widget {
    SpotterCastSmallWeatherWidget()
    SpotterCastMediumWeatherWidget()
    SpotterCastLockScreenWeatherWidget()
  }
}
