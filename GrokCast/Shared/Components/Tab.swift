import SwiftUI

enum CompactTab: String, CaseIterable, Identifiable {
  case today
  case forecast
  case radar
  case alerts
  case more

  var id: String { rawValue }

  var title: String {
    switch self {
    case .today: "Today"
    case .forecast: "Forecast"
    case .radar: "Radar"
    case .alerts: "Alerts"
    case .more: "More"
    }
  }

  var icon: String {
    switch self {
    case .today: "sun.max.fill"
    case .forecast: "calendar"
    case .radar: "map.fill"
    case .alerts: "bell.badge.fill"
    case .more: "ellipsis"
    }
  }

  var weatherTab: WeatherStore.Tab? {
    switch self {
    case .today: .today
    case .forecast: .forecast
    case .radar: .radar
    case .alerts: .alerts
    case .more: nil
    }
  }

  func isSelected(for selection: WeatherStore.Tab) -> Bool {
    switch self {
    case .more:
      return WeatherStore.Tab.moreHub.contains(selection)
    default:
      return weatherTab == selection
    }
  }
}

extension WeatherStore.Tab {
  static let moreHub: [WeatherStore.Tab] = [.grok, .locations, .settings]
}

/// Child views (e.g. Grok AI chat) set this when the keyboard should replace the tab bar.
struct TabBarSuppressionPreferenceKey: PreferenceKey {
  static let defaultValue = false

  static func reduce(value: inout Bool, nextValue: () -> Bool) {
    value = value || nextValue()
  }
}

struct CompactTabBar: View {
  @Binding var selection: WeatherStore.Tab
  private let tabs = CompactTab.allCases

  private(set) var pillCornerRadius: CGFloat
  private(set) var animation: Animation
  private(set) var activeColor: Color
  private(set) var inactiveColor: Color
  private(set) var backgroundMaterial: Material

  @State private var showMoreSheet = false

  init(
    selection: Binding<WeatherStore.Tab>,
    namespace: Namespace.ID,
    pillCornerRadius: CGFloat = 12,
    animation: Animation = .spring(response: 0.35, dampingFraction: 0.75),
    activeColor: Color = .black,
    inactiveColor: Color = .white.opacity(0.6),
    backgroundMaterial: Material = .ultraThinMaterial
  ) {
    _selection = selection
    self.namespace = namespace
    self.pillCornerRadius = pillCornerRadius
    self.animation = animation
    self.activeColor = activeColor
    self.inactiveColor = inactiveColor
    self.backgroundMaterial = backgroundMaterial
  }

  private let namespace: Namespace.ID

  var body: some View {
    HStack(spacing: 0) {
      ForEach(tabs) { tab in
        Button {
          if tab == .more {
            Haptic.selection()
            showMoreSheet = true
          } else if let target = tab.weatherTab, target != selection {
            Haptic.selection()
            withAnimation(animation) {
              selection = target
            }
          }
        } label: {
          tabContent(for: tab)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .frame(maxWidth: .infinity)
      }
    }
    .padding(.top, 8)
    .padding(.bottom, 6)
    .background(backgroundMaterial)
    .background(Color.black.opacity(0.25))
    .ignoresSafeArea(.keyboard)
    .sheet(isPresented: $showMoreSheet) {
      MoreHubSheet()
    }
  }

  private func tabContent(for tab: CompactTab) -> some View {
    let active = tab.isSelected(for: selection)
    return VStack(spacing: 3) {
      ZStack {
        if active {
          RoundedRectangle(cornerRadius: pillCornerRadius)
            .fill(Color.white)
            .matchedGeometryEffect(id: "pill", in: namespace)
            .frame(width: 40, height: 28)
        }
        Image(systemName: tab.icon)
          .font(.system(size: 20))
          .foregroundStyle(active ? activeColor : inactiveColor)
          .animation(nil, value: selection)
      }
      .frame(height: 28)
      Text(tab.title)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(active ? .white : inactiveColor)
        .animation(nil, value: selection)
    }
    .padding(.vertical, 4)
  }
}
