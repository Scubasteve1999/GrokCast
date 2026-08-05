import Foundation

/// Authoritative store for live (past) and forecast frame windows.
struct RadarTimeline: Equatable {
  var live: [RadarFrame] = []
  var forecast: [RadarFrame] = []

  var hasLive: Bool { !live.isEmpty }
  var hasForecast: Bool { !forecast.isEmpty }

  func frames(showingFuture: Bool) -> [RadarFrame] {
    showingFuture ? forecast : live
  }

  func futureRelativeLabels(count: Int) -> [String] {
    guard count > 0, let firstTs = forecast.first?.timestamp else {
      return Array(repeating: "?", count: max(0, count))
    }
    let stepHours: Int = {
      if count > 1, let second = forecast.dropFirst().first {
        let deltaH = Int(round(second.timestamp.timeIntervalSince(firstTs) / 3600))
        return max(1, deltaH)
      }
      return 1
    }()
    return (0..<count).map { i in
      if i == 0 { return "Now" }
      return "+\(i * stepHours)h"
    }
  }

  func activeFrameLabels(showingFuture: Bool) -> [String] {
    let frames = frames(showingFuture: showingFuture)
    guard !frames.isEmpty else { return [] }
    if showingFuture {
      return futureRelativeLabels(count: frames.count)
    }
    return frames.map {
      $0.timelineLabel(showingFuture: false, forecastAnchor: nil)
    }
  }
}