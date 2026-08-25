import SwiftUI

/// TWC-style hourly table under the Forecast graph. Expand a row for the metric grid.
struct ForecastHourlyList: View {
  let hours: [HourlyForecast]
  var unit: TemperatureUnit
  var calendar: Calendar
  var timeZone: TimeZone
  @State private var expandedID: Date?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(groupedHours) { group in
        Text(dayHeading(group.day))
          .font(DesignTokens.Typography.subsection())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .padding(.top, DesignTokens.Spacing.space16)
          .padding(.bottom, DesignTokens.Spacing.space8)

        ForEach(group.hours) { hour in
          row(hour)
          if expandedID == hour.id {
            HourlyDetailGrid(hour: hour, unit: unit)
              .padding(.vertical, DesignTokens.Spacing.space8)
          }
          if hour.id != group.hours.last?.id {
            Divider().overlay(DesignTokens.Palette.cardHairline)
          }
        }
      }
    }
  }

  private struct DayGroup: Identifiable {
    let day: Date
    var hours: [HourlyForecast]
    var id: Date { day }
  }

  private var groupedHours: [DayGroup] {
    var calendar = calendar
    calendar.timeZone = timeZone
    var groups: [DayGroup] = []
    for hour in hours.prefix(24) {
      let start = calendar.startOfDay(for: hour.time)
      if let last = groups.last, last.day == start {
        groups[groups.count - 1].hours.append(hour)
      } else {
        groups.append(DayGroup(day: start, hours: [hour]))
      }
    }
    return groups
  }

  private func dayHeading(_ day: Date) -> String {
    var calendar = calendar
    calendar.timeZone = timeZone
    if calendar.isDateInToday(day) {
      return LocationTimezone.formatter(dateFormat: "EEE, MMM d", timeZone: timeZone)
        .string(from: day)
    }
    return LocationTimezone.formatter(dateFormat: "EEE, MMM d", timeZone: timeZone)
      .string(from: day)
  }

  private func row(_ hour: HourlyForecast) -> some View {
    let expanded = expandedID == hour.id
    return Button {
      Haptic.selection()
      withAnimation(.easeInOut(duration: 0.2)) {
        expandedID = expanded ? nil : hour.id
      }
    } label: {
      HStack(spacing: DesignTokens.Spacing.space12) {
        Text(hourLabel(hour.time))
          .font(DesignTokens.Typography.callout())
          .fontWeight(.medium)
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .frame(width: 44, alignment: .leading)
          .monospacedDigit()

        Image(systemName: hour.symbolName)
          .font(DesignTokens.Typography.symbol(18))
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .frame(width: 22)
          .accessibilityHidden(true)

        Text("\(hour.precipChance)%")
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(
            DailyPrecipEmphasis.forChance(hour.precipChance).color
          )
          .frame(width: 36, alignment: .leading)
          .monospacedDigit()

        Text(unit.formatShort(hour.temp))
          .font(DesignTokens.Typography.callout())
          .fontWeight(.semibold)
          .foregroundStyle(DesignTokens.Palette.textPrimary)
          .frame(width: 44, alignment: .trailing)
          .monospacedDigit()

        Text(windLabel(hour))
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textSecondary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
          .frame(maxWidth: .infinity, alignment: .trailing)

        Image(systemName: expanded ? "minus" : "plus")
          .font(DesignTokens.Typography.caption())
          .foregroundStyle(DesignTokens.Palette.textTertiary)
          .frame(width: 16)
      }
      .padding(.vertical, DesignTokens.Spacing.space12)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(rowLabel(hour))
    .accessibilityAddTraits(.isButton)
  }

  private func hourLabel(_ date: Date) -> String {
    let now = Date()
    if abs(date.timeIntervalSince(now)) < 35 * 60 { return "Now" }
    return LocationTimezone.formatter(dateFormat: "ha", timeZone: timeZone)
      .string(from: date)
      .replacingOccurrences(of: " ", with: "")
      .lowercased()
  }

  private func windLabel(_ hour: HourlyForecast) -> String {
    guard let speed = hour.windSpeed else { return HourlyDetailMetrics.unknown }
    let speedText = unit.formatWind(speed)
    guard let degrees = hour.windDirection else { return speedText }
    return "\(speedText) \(HourlyDetailMetrics.compassAbbr(degrees))"
  }

  private func rowLabel(_ hour: HourlyForecast) -> String {
    "\(hourLabel(hour.time)), \(Int(round(hour.temp))) degrees, \(hour.precipChance) percent chance of precipitation, wind \(windLabel(hour))"
  }
}

struct HourlyDetailGrid: View {
  let hour: HourlyForecast
  let unit: TemperatureUnit

  private let columns = [
    GridItem(.flexible(), spacing: DesignTokens.Spacing.space12),
    GridItem(.flexible(), spacing: DesignTokens.Spacing.space12),
    GridItem(.flexible(), spacing: DesignTokens.Spacing.space12),
  ]

  var body: some View {
    let rows = HourlyDetailMetrics.rows(hour: hour, unit: unit)
    LazyVGrid(columns: columns, alignment: .leading, spacing: DesignTokens.Spacing.space12) {
      ForEach(rows) { row in
        VStack(alignment: .leading, spacing: 2) {
          Text(row.label)
            .font(DesignTokens.Typography.caption())
            .foregroundStyle(DesignTokens.Palette.textSecondary)
          Text(row.value)
            .font(DesignTokens.Typography.callout())
            .fontWeight(.medium)
            .foregroundStyle(DesignTokens.Palette.textPrimary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(HourlyDetailMetrics.accessibilityLabel(hour: hour, unit: unit))
  }
}
