import SwiftUI

struct MainTabView: View {
    @Environment(WeatherStore.self) private var store

    var body: some View {
        TabView(selection: Bindable(store).selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }
                .tag(WeatherStore.Tab.today)

            ForecastView()
                .tabItem {
                    Label("Forecast", systemImage: "calendar")
                }
                .tag(WeatherStore.Tab.forecast)

            GrokAIView()
                .tabItem {
                    Label("Grok AI", systemImage: "sparkles")
                }
                .tag(WeatherStore.Tab.grok)

            LocationsView()
                .tabItem {
                    Label("Locations", systemImage: "mappin.and.ellipse")
                }
                .tag(WeatherStore.Tab.locations)
        }
        .task {
            if store.currentWeather == nil {
                await store.refreshWeather()
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(WeatherStore())
}