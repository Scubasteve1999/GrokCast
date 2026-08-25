import SwiftUI

struct DailyFeedCard: View {
  @Environment(WeatherStore.self) private var store
  let weather: DayCastWeather
  var plated: Bool = true
  @State private var selectedID: Date?

  private var days: [DailyForecast] {
    Array(weather.daily.prefix(7))
  }

  private var periodLow: Double? { days.map(\.low).min() }
  private var periodHigh: Double? { days.map(\.high).max() }
  private var selected: DailyForecast? {
    days.first(where: { $0.id == selectedID }) ?? days.first
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      Button {
        Haptic.selection()
        store.selectedTab = .forecast
      } label: {
        HStack {
          Text("This Week")
            .font(DesignTokens.Typography.studioTitle())
            .foregroundStyle(DesignTokens.Palette.textPrimary)
          Spacer(minLength: 4)
          Image(systemName: "chevron.right")
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textTertiary)
        }
      }
      .buttonStyle(.plain)
      .accessibilityLabel("This Week")
      .accessibilityHint("Opens full forecast")

      WeekDayChipStrip(
        days: days,
        selectedID: selected?.id,
        calendar: weather.locationCalendar,
        timeZone: weather.locationTimeZone,
        unit: store.temperatureUnit,
        periodLow: periodLow,
        periodHigh: periodHigh,
        onSelect: { selectedID = $0.id }
      )

      if let selected {
        Text(
          DailyOutlook.sentence(
            day: selected,
            unit: store.temperatureUnit,
            calendar: weather.locationCalendar,
            timeZone: weather.locationTimeZone
          )
        )
        .font(DesignTokens.Typography.body())
        .foregroundStyle(DesignTokens.Palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(plated ? DesignTokens.Spacing.space16 : 0)
    .weatherModuleChrome(plated)
    .accessibilityElement(children: .contain)
    .onAppear {
      if selectedID == nil { selectedID = days.first?.id }
    }
  }
}
