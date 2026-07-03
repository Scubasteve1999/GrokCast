import SwiftUI
import WidgetKit

struct WatchWeatherView: View {
  @State private var snapshot: WidgetWeatherSnapshot?
  @State private var lastRefresh = Date.distantPast

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        if let snapshot {
          header(snapshot)
          metrics(snapshot)
          if let grok = snapshot.grokBriefOneLiner {
            grokLine(grok)
          } else if let minutecast = snapshot.minutecastMessage {
            Text(minutecast)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
          Text("Updated \(snapshot.fetchedAt, style: .relative) ago")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        } else {
          ContentUnavailableView {
            Label("No Data", systemImage: "cloud")
          } description: {
            Text("Open GrokCast on iPhone and refresh weather.")
          }
        }
      }
      .padding(.horizontal, 4)
    }
    .navigationTitle(snapshot?.location.name ?? "GrokCast")
    .onAppear(perform: reload)
    .refreshable { reload() }
  }

  private func header(_ snapshot: WidgetWeatherSnapshot) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Image(systemName: snapshot.symbolName)
        .font(.title2)
        .symbolRenderingMode(.multicolor)
      Text("\(Int(snapshot.currentTemp.rounded()))°")
        .font(.system(size: 44, weight: .black, design: .default).width(.condensed))
        .monospacedDigit()
      Spacer(minLength: 0)
    }
  }

  private func metrics(_ snapshot: WidgetWeatherSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(snapshot.conditionText)
        .font(.caption.weight(.semibold))
        .lineLimit(1)
      HStack(spacing: 12) {
        Label("H \(Int(snapshot.high.rounded()))°", systemImage: "arrow.up")
        Label("L \(Int(snapshot.low.rounded()))°", systemImage: "arrow.down")
      }
      .font(.caption2.weight(.semibold))
      .labelStyle(.titleOnly)
      if let score = snapshot.grokCastScore, let label = snapshot.grokCastScoreLabel {
        Text("Score \(score) · \(label)")
          .font(.caption2.weight(.bold))
          .foregroundStyle(.blue)
      }
    }
  }

  private func grokLine(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 4) {
      Image(systemName: "sparkles")
        .font(.caption2)
        .foregroundStyle(.blue)
      Text(text)
        .font(.caption2)
        .lineLimit(3)
    }
  }

  private func reload() {
    snapshot = WidgetDataStore.loadSnapshot(for: nil)
    lastRefresh = Date()
  }
}

#if DEBUG
#Preview {
  WatchWeatherView()
}
#endif
