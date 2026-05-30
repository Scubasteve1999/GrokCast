import SwiftUI

struct TodayView: View {
    @Environment(WeatherStore.self) private var store

    var weather: GrokCastWeather? { store.currentWeather }
    var locationName: String { store.currentLocation?.name ?? "—" }

    var body: some View {
        NavigationStack {
            ZStack {
                tacticalBackground
                    .ignoresSafeArea()

                if store.isLoadingWeather && weather == nil {
                    VStack {
                        ProgressView()
                            .tint(.white)
                        Text("ACQUIRING TACTICAL WEATHER DATA")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.top, 12)
                    }
                } else if let w = weather {
                    ScrollView {
                        VStack(spacing: 32) {
                            header(for: w)

                            heroCard(for: w)

                            tacticalDetailsGrid(for: w)

                            // Grok Imagine quick action
                            GrokImagineButton(weather: w)

                            if let error = store.weatherError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .padding()
                            }

                            Button {
                                Haptic.impact(.medium)
                                Task { await store.refreshWeather() }
                            } label: {
                                Label("REFRESH DATA", systemImage: "arrow.clockwise")
                                    .font(.footnote.weight(.semibold))
                                    .tracking(1.5)
                            }
                            .buttonStyle(.bordered)
                            .tint(.white.opacity(0.6))
                            .padding(.top, 12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 80)
                        .padding(.bottom, 60)
                    }
                    .refreshable {
                        await store.refreshWeather()
                    }
                } else {
                    ContentUnavailableView {
                        Label("NO SIGNAL", systemImage: "antenna.radiowaves.left.and.right.slash")
                    } description: {
                        Text("Establish location or pull to acquire forecast.")
                    } actions: {
                        Button("USE MY POSITION") {
                            Task { await store.useCurrentDeviceLocation() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.useCurrentDeviceLocation() }
                    } label: {
                        Image(systemName: "location.circle.fill")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var tacticalBackground: some View {
        ZStack {
            Color.black
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.12), .black],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.blue.opacity(0.85), Color.indigo.opacity(0.9)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func header(for w: GrokCastWeather) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(locationName.uppercased())
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.9))

                Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Text("\(w.fetchedAt, format: .dateTime.hour().minute())")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private func heroCard(for w: GrokCastWeather) -> some View {
        VStack(spacing: 8) {
            Image(systemName: w.symbolName)
                .font(.system(size: 72))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, options: .repeating)

            Text("\(Int(round(w.currentTemp)))°")
                .font(.system(size: 108, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text(w.conditionText.uppercased())
                .font(.title3.weight(.bold))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: 28) {
                VStack {
                    Text("HIGH").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                    Text("\(Int(round(w.high)))°").font(.title2.weight(.semibold))
                }
                VStack {
                    Text("LOW").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                    Text("\(Int(round(w.low)))°").font(.title2.weight(.semibold))
                }
            }
            .foregroundStyle(.white)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private func tacticalDetailsGrid(for w: GrokCastWeather) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            TacticalCard(label: "FEELS LIKE", value: "\(Int(round(w.feelsLike)))°", icon: "thermometer.medium")
            TacticalCard(label: "HUMIDITY", value: "\(w.humidity)%", icon: "humidity")
            TacticalCard(label: "WIND", value: "\(Int(w.windSpeed)) MPH", icon: "wind")
            TacticalCard(label: "UV INDEX", value: "\(Int(w.uvIndex))", icon: "sun.max")
            TacticalCard(label: "PRECIP", value: "\(w.precipitationChance)%", icon: "drop")
            if let aqi = w.airQualityIndex {
                TacticalCard(label: "AQI", value: "\(aqi)", icon: "aqi.medium")
            }
            if let pollen = w.pollenLevel {
                TacticalCard(label: "POLLEN", value: pollen, icon: "leaf")
            }
        }
    }
}

struct TacticalCard: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1)
            }
            .foregroundStyle(.white.opacity(0.5))

            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// Placeholder for Grok Imagine button (full implementation in later iteration)
struct GrokImagineButton: View {
    let weather: GrokCastWeather

    var body: some View {
        Button {
            // TODO: Trigger image generation + present sheet
            Haptic.impact(.heavy)
        } label: {
            Label("GENERATE WHAT TODAY LOOKS LIKE", systemImage: "sparkles.rectangle.stack")
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.indigo.opacity(0.7))
        .padding(.top, 8)
    }
}

#Preview {
    TodayView()
        .environment(WeatherStore())
}