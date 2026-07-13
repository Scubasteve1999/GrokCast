import SwiftUI

struct TripPlannerView: View {
  @Environment(WeatherStore.self) private var store
  @State private var destination = ""
  @State private var startDate = Date().addingTimeInterval(86400)
  @State private var endDate = Date().addingTimeInterval(86400 * 3)
  @State private var tripForecast: TripForecastResult?
  @State private var isLoading = false
  @State private var errorMessage: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space20) {
        inputSection
        if isLoading {
          loadingSection
        } else if let result = tripForecast {
          resultSection(result)
        } else if let error = errorMessage {
          errorSection(error)
        }
      }
      .padding(.horizontal, DesignTokens.Spacing.space20)
      .padding(.vertical, DesignTokens.Spacing.space16)
    }
    .background(DesignTokens.Palette.bgPrimary.ignoresSafeArea())
    .navigationTitle("Trip Planner")
    .navigationBarTitleDisplayMode(.large)
  }

  private var inputSection: some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
      VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
        Text("DESTINATION")
          .font(.caption.weight(.bold))
          .tracking(DesignTokens.Typography.cardLabelTracking)
          .foregroundStyle(DesignTokens.Palette.textTertiary)

        TextField("City or place name", text: $destination)
          .textFieldStyle(.roundedBorder)
          .autocorrectionDisabled()
      }

      HStack(spacing: DesignTokens.Spacing.space16) {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
          Text("FROM")
            .font(.caption2.weight(.bold))
            .foregroundStyle(DesignTokens.Palette.textTertiary)
          DatePicker("", selection: $startDate, in: Date()..., displayedComponents: .date)
            .labelsHidden()
        }

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
          Text("TO")
            .font(.caption2.weight(.bold))
            .foregroundStyle(DesignTokens.Palette.textTertiary)
          DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
            .labelsHidden()
        }
      }

      Button {
        Haptic.impact(.medium)
        Task { await fetchTripForecast() }
      } label: {
        Label("GET TRIP FORECAST", systemImage: "airplane.departure")
          .font(.subheadline.weight(.semibold))
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .tint(DesignTokens.Palette.accent)
      .disabled(destination.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
    }
    .padding(DesignTokens.Spacing.space16)
    .glassCardStyle()
  }

  private var loadingSection: some View {
    VStack(spacing: DesignTokens.Spacing.space12) {
      ProgressView()
        .tint(DesignTokens.Palette.accent)
      Text("Checking forecast for \(destination)...")
        .font(.caption)
        .foregroundStyle(DesignTokens.Palette.textSecondary)
    }
    .frame(maxWidth: .infinity)
    .padding(DesignTokens.Spacing.space24)
  }

  private func resultSection(_ result: TripForecastResult) -> some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space16) {
      HStack {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.space4) {
          Text(result.locationName)
            .font(.title3.weight(.bold))
            .foregroundStyle(DesignTokens.Palette.textPrimary)
          Text(result.dateRange)
            .font(.caption)
            .foregroundStyle(DesignTokens.Palette.textSecondary)
        }
        Spacer()
        if let avgScore = result.averageScore {
          VStack(spacing: 2) {
            Text("\(avgScore)")
              .font(.title2.weight(.bold))
              .foregroundStyle(DesignTokens.Palette.accent)
            Text("Avg Score")
              .font(.caption2)
              .foregroundStyle(DesignTokens.Palette.textTertiary)
          }
        }
      }

      ForEach(result.days) { day in
        tripDayRow(day)
      }

      if let packing = result.packingSuggestions, !packing.isEmpty {
        packingSection(packing)
      }

      if let grokAdvice = result.grokAdvice, !grokAdvice.isEmpty {
        grokAdviceSection(grokAdvice)
      }
    }
  }

  private func tripDayRow(_ day: TripDayForecast) -> some View {
    HStack(spacing: DesignTokens.Spacing.space12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(day.dayLabel)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        Text(day.condition)
          .font(.caption)
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      }

      Spacer()

      Image(systemName: day.symbolName)
        .font(.title3)
        .symbolRenderingMode(.multicolor)

      VStack(alignment: .trailing, spacing: 2) {
        Text("\(Int(day.high.rounded()))°")
          .font(.subheadline.weight(.bold))
          .foregroundStyle(DesignTokens.Palette.textPrimary)
        Text("\(Int(day.low.rounded()))°")
          .font(.caption)
          .foregroundStyle(DesignTokens.Palette.textSecondary)
      }
      .frame(width: 36)

      if day.precipChance > 0 {
        Text("\(day.precipChance)%")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.cyan)
          .frame(width: 36)
      } else {
        Color.clear.frame(width: 36)
      }
    }
    .padding(DesignTokens.Spacing.space12)
    .glassCardStyle(cornerRadius: DesignTokens.Radius.small)
  }

  private func packingSection(_ items: [String]) -> some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      Label("PACKING LIST", systemImage: "suitcase.fill")
        .font(.caption.weight(.bold))
        .tracking(DesignTokens.Typography.cardLabelTracking)
        .foregroundStyle(DesignTokens.Palette.accentWarm)

      FlowLayout(spacing: 8) {
        ForEach(items, id: \.self) { item in
          Text(item)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DesignTokens.Palette.cardElevated, in: Capsule())
            .foregroundStyle(DesignTokens.Palette.textPrimary)
        }
      }
    }
    .padding(DesignTokens.Spacing.space16)
    .glassCardStyle()
  }

  private func grokAdviceSection(_ advice: String) -> some View {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.space8) {
      Label("TODAY'S TAKE", systemImage: "sparkles")
        .font(.caption.weight(.bold))
        .tracking(DesignTokens.Typography.cardLabelTracking)
        .foregroundStyle(DesignTokens.Palette.accent)

      Text(advice)
        .font(.body)
        .foregroundStyle(DesignTokens.Palette.textPrimary)
    }
    .padding(DesignTokens.Spacing.space16)
    .glassCardStyle(strokeTint: DesignTokens.Palette.accent.opacity(0.3))
  }

  private func errorSection(_ message: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(DesignTokens.Palette.danger)
      Text(message)
        .font(.caption)
        .foregroundStyle(DesignTokens.Palette.danger)
    }
    .padding(DesignTokens.Spacing.space12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(DesignTokens.Palette.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
  }

  private func fetchTripForecast() async {
    isLoading = true
    errorMessage = nil
    tripForecast = nil

    do {
      let result = try await TripForecastService.fetchForecast(
        destination: destination,
        startDate: startDate,
        endDate: endDate,
        store: store
      )
      tripForecast = result
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }
}

struct FlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let result = layout(proposal: proposal, subviews: subviews)
    return result.size
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let result = layout(proposal: proposal, subviews: subviews)
    for (index, subview) in subviews.enumerated() {
      subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                y: bounds.minY + result.positions[index].y),
                    proposal: .unspecified)
    }
  }

  private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
    let maxWidth = proposal.width ?? .infinity
    var positions: [CGPoint] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > maxWidth && x > 0 {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      positions.append(CGPoint(x: x, y: y))
      rowHeight = max(rowHeight, size.height)
      x += size.width + spacing
    }

    return (CGSize(width: maxWidth, height: y + rowHeight), positions)
  }
}

#Preview {
  NavigationStack {
    TripPlannerView()
      .environment(WeatherStore.shared)
  }
  .preferredColorScheme(.dark)
}
