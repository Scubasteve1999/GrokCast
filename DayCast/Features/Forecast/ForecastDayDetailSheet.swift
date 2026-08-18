import SwiftUI

/// Day breakdown for Forecast 10-Day tap — uses fields already on `DailyForecast`.
struct ForecastDayDetailSheet: View {
  let forecast: DailyForecast
  var calendar: Calendar = .current
  var timeZone: TimeZone = .current
  @Environment(\.dismiss) private var dismiss

  private var condition: WeatherCondition {
    WeatherCondition(fromWMO: forecast.weatherCode)
  }

  private var title: String {
    if calendar.isDateInToday(forecast.date) { return "Today" }
    return LocationTimezone.formatter(dateFormat: "EEEE, MMM d", timeZone: timeZone)
      .string(from: forecast.date)
  }

  private var precipTypeLabel: String {
    condition.rowPrecipTypeLabel(precipChance: forecast.precipChance)
  }

  private var precipAmount: String? {
    let liq = (forecast.rainSum ?? 0) + (forecast.showersSum ?? 0)
    let sn = forecast.snowfallSum ?? 0
    return precipAmountText(liquid: liq, snow: sn)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space20) {
          headerBlock
          tempsBlock
          precipBlock
          if forecast.uvMax != nil {
            uvBlock
          }
          if forecast.sunrise != nil || forecast.sunset != nil {
            sunBlock
          }
        }
        .padding(DesignTokens.Spacing.space20)
        .padding(.bottom, DesignTokens.Spacing.space32)
      }
      .background(DesignTokens.Palette.bgPrimary.ignoresSafeArea())
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
            .fontWeight(.semibold)
        }
      }
    }
    .preferredColorScheme(.dark)
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }

  private var headerBlock: some View {
    HStack(spacing: DesignTokens.Spacing.space16) {
      Image(systemName: condition.rowSymbolName(precipChance: forecast.precipChance))
        .font(DesignTokens.Typography.compactTemp())
        .symbolRenderingMode(.multicolor)
        .accessibilityLabel(condition.displayText)
      VStack(alignment: .leading, spacing: 4) {
        Text(condition.displayText)
          .font(DesignTokens.Typography.metric())
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        Text(title)
          .font(DesignTokens.Typography.callout())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      }
      Spacer(minLength: 0)
    }
    .padding(DesignTokens.Spacing.space16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(DesignTokens.Palette.cardElevated.opacity(0.9), in: RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadiusMedium))
    .overlay(
      RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadiusMedium)
        .stroke(DesignTokens.Palette.cardStroke, lineWidth: DesignTokens.Card.strokeWidth)
    )
  }

  private var tempsBlock: some View {
    detailCard(title: "Temperature") {
      HStack(spacing: DesignTokens.Spacing.space24) {
        metric(label: "High", value: "\(Int(round(forecast.high)))°")
        metric(label: "Low", value: "\(Int(round(forecast.low)))°")
        Spacer(minLength: 0)
      }
    }
  }

  private var precipBlock: some View {
    detailCard(title: "Precipitation") {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
        if forecast.precipChance > 0 {
          Text("\(forecast.precipChance)% chance of \(precipTypeLabel)")
            .font(DesignTokens.Typography.headline())
            .foregroundStyle(DesignTokens.Palette.accentCool)
        } else {
          Text("No meaningful precip chance")
            .font(DesignTokens.Typography.headline())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
        if let precipAmount {
          Text("Expected \(precipAmount)")
            .font(DesignTokens.Typography.callout())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
      }
    }
  }

  private var uvBlock: some View {
    detailCard(title: "UV Index") {
      if let uv = forecast.uvMax {
        Text("Max \(Int(round(uv)))")
          .font(DesignTokens.Typography.studioTitle())
          .monospacedDigit()
          .foregroundStyle(DesignTokens.Palette.textPrimary)
      }
    }
  }

  private var sunBlock: some View {
    detailCard(title: "Sun") {
      HStack(spacing: DesignTokens.Spacing.space24) {
        Label(formatTime(forecast.sunrise), systemImage: "sunrise.fill")
          .font(DesignTokens.Typography.subsection())
          .foregroundStyle(DesignTokens.Palette.accentWarm)
        Label(formatTime(forecast.sunset), systemImage: "sunset.fill")
          .font(DesignTokens.Typography.subsection())
          .foregroundStyle(DesignTokens.Palette.accentCool)
        Spacer(minLength: 0)
      }
    }
  }

  private func detailCard<Content: View>(title: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      Text(title.uppercased())
        .font(DesignTokens.Typography.caption())
        .tracking(DesignTokens.Typography.cardLabelTracking)
        .foregroundStyle(DesignTokens.Palette.textTertiary)
      content()
    }
    .padding(DesignTokens.Spacing.space16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(DesignTokens.Palette.cardBackground.opacity(0.85), in: RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadiusMedium))
    .overlay(
      RoundedRectangle(cornerRadius: DesignTokens.Card.cornerRadiusMedium)
        .stroke(DesignTokens.Palette.cardStroke, lineWidth: DesignTokens.Card.strokeWidth)
    )
  }

  private func metric(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(DesignTokens.Typography.caption())
        .foregroundStyle(DesignTokens.Palette.textTertiary)
      Text(value)
        .font(DesignTokens.Typography.studioTitle())
        .monospacedDigit()
        .foregroundStyle(DesignTokens.Palette.textPrimary)
    }
  }

  private func formatTime(_ date: Date?) -> String {
    guard let date else { return "--:--" }
    return LocationTimezone.formatter(dateFormat: "h:mm a", timeZone: timeZone)
      .string(from: date)
  }
}
