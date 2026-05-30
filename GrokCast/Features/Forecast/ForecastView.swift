import SwiftUI
import Foundation // for Date etc if needed

struct ForecastView: View {
    @Environment(WeatherStore.self) private var store

    var weather: GrokCastWeather? { store.currentWeather }

    var body: some View {
        NavigationStack {
            List {
                if let w = weather {
                    Section("HOURLY — NEXT 24H") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(w.hourly.prefix(24)) { hour in
                                    HourlyRow(forecast: hour)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }

                    Section("10-DAY OUTLOOK") {
                        ForEach(w.daily) { day in
                            DailyRow(forecast: day)
                        }
                    }
                } else if store.isLoadingWeather {
                    ProgressView("LOADING HYPER-LOCAL FORECAST")
                } else {
                    ContentUnavailableView("NO FORECAST", systemImage: "calendar", description: Text("Select location to acquire data."))
                }
            }
            .navigationTitle("FORECAST")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await store.refreshWeather() }
        }
    }
}

struct HourlyRow: View {
    let forecast: HourlyForecast

    var body: some View {
        VStack(spacing: 6) {
            Text(forecast.time, format: .dateTime.hour())
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            Image(systemName: forecast.symbolName)
                .font(.title2)

            Text("\(Int(round(forecast.temp)))°")
                .font(.headline.weight(.semibold))

            if forecast.precipChance > 15 {
                Text("\(forecast.precipChance)%")
                    .font(.caption2.bold())
                    .foregroundStyle(.blue)
            }
        }
        .frame(width: 48)
    }
}

struct DailyRow: View {
    let forecast: DailyForecast

    var body: some View {
        HStack {
            Text(forecast.date, format: .dateTime.weekday(.abbreviated))
                .font(.body.weight(.medium))
                .frame(width: 52, alignment: .leading)

            Image(systemName: forecast.symbolName)
                .font(.title3)
                .frame(width: 28)

            Spacer()

            if let uv = forecast.uvMax {
                Text("UV \(Int(uv))").font(.caption2).foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Text("\(Int(round(forecast.low)))°").foregroundStyle(.secondary)
                Text("\(Int(round(forecast.high)))°").fontWeight(.semibold)
            }
            .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ForecastView()
        .environment(WeatherStore())
}