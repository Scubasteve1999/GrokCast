import SwiftUI

@main
struct GrokCastApp: App {
    @State private var store = WeatherStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(store)
                .tint(.accentColor)
        }
    }
}