import SwiftUI
import UIKit

extension View {
  /// Hide the system `TabView` bar so only `CompactTabBar` is visible on iPhone.
  func hidesSystemTabBar() -> some View {
    toolbar(.hidden, for: .tabBar)
      .toolbarBackground(.hidden, for: .tabBar)
  }
}

/// Walks up to the hosting `UITabBarController` and hides its bar.
/// SwiftUI `.toolbar(.hidden, for: .tabBar)` is ignored by `sidebarAdaptable`
/// and by the iOS 26 glass tab bar.
struct SystemTabBarHider: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> SystemTabBarHiderController {
    SystemTabBarHiderController()
  }

  func updateUIViewController(_ uiViewController: SystemTabBarHiderController, context: Context) {
    uiViewController.hideSystemTabBar()
  }
}

final class SystemTabBarHiderController: UIViewController {
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    hideSystemTabBar()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    hideSystemTabBar()
  }

  func hideSystemTabBar() {
    guard let tab = enclosingTabBarController() else { return }
    tab.tabBar.isHidden = true
    tab.tabBar.alpha = 0
    tab.tabBar.isUserInteractionEnabled = false
  }

  private func enclosingTabBarController() -> UITabBarController? {
    var current: UIViewController? = parent ?? self
    while let controller = current {
      if let tab = controller as? UITabBarController { return tab }
      current = controller.parent
    }
    return view.window?.rootViewController.flatMap(findTabBar(in:))
  }

  private func findTabBar(in root: UIViewController) -> UITabBarController? {
    if let tab = root as? UITabBarController { return tab }
    for child in root.children {
      if let tab = findTabBar(in: child) { return tab }
    }
    if let presented = root.presentedViewController {
      return findTabBar(in: presented)
    }
    return nil
  }
}

extension View {
  /// iOS 26 glass still paints an opaque nav even when SwiftUI asks for
  /// material. Hide the fill and clear the UIKit appearances so a sky
  /// behind the stack can show through.
  func weatherShowsThroughNavigationBar() -> some View {
    toolbarBackground(.hidden, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
      .background { TransparentNavigationBar() }
  }
}

/// Makes the enclosing `UINavigationBar` a clear glass so Today’s weather
/// plate can paint under the status bar and title.
struct TransparentNavigationBar: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> TransparentNavigationBarController {
    TransparentNavigationBarController()
  }

  func updateUIViewController(
    _ uiViewController: TransparentNavigationBarController, context: Context
  ) {
    uiViewController.clearNavigationBar()
  }
}

final class TransparentNavigationBarController: UIViewController {
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    clearNavigationBar()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    clearNavigationBar()
  }

  func clearNavigationBar() {
    guard let bar = enclosingNavigationController()?.navigationBar else { return }
    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.backgroundColor = .clear
    appearance.backgroundEffect = nil
    appearance.shadowColor = .clear
    appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
    bar.standardAppearance = appearance
    bar.scrollEdgeAppearance = appearance
    bar.compactAppearance = appearance
    bar.compactScrollEdgeAppearance = appearance
    bar.isTranslucent = true
    bar.backgroundColor = .clear
  }

  private func enclosingNavigationController() -> UINavigationController? {
    var current: UIViewController? = parent ?? self
    while let controller = current {
      if let nav = controller as? UINavigationController { return nav }
      if let nav = controller.navigationController { return nav }
      current = controller.parent
    }
    return nil
  }
}

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
    case .alerts: AlertsHonesty.tabSymbolIdle
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

  /// Compact `TabView` may only have these five pages. Extra destinations
  /// (Storm Spotter, Locations, Settings) share the More page so UIKit
  /// never installs its own More navigation stack and back button.
  static func primary(for tab: WeatherStore.Tab) -> CompactTab {
    switch tab {
    case .today: .today
    case .forecast: .forecast
    case .radar: .radar
    case .alerts: .alerts
    case .grok, .locations, .settings: .more
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
  @Environment(WeatherStore.self) private var store
  @Environment(SevereWeatherStore.self) private var severeStore
  @Binding var selection: WeatherStore.Tab
  @Binding var showMoreHub: Bool
  private let tabs = CompactTab.allCases

  private(set) var pillCornerRadius: CGFloat
  private(set) var animation: Animation
  private(set) var activeColor: Color
  private(set) var inactiveColor: Color
  private(set) var backgroundMaterial: Material

  init(
    selection: Binding<WeatherStore.Tab>,
    showMoreHub: Binding<Bool>,
    namespace: Namespace.ID,
    pillCornerRadius: CGFloat = 12,
    animation: Animation = .easeInOut(duration: 0.2),
    activeColor: Color = DesignTokens.Palette.textPrimary,
    inactiveColor: Color = DesignTokens.Palette.textTertiary,
    backgroundMaterial: Material = .bar
  ) {
    _selection = selection
    _showMoreHub = showMoreHub
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
            showMoreHub = true
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
        .accessibilityLabel(accessibilityLabel(for: tab))
        .accessibilityValue(accessibilityValue(for: tab))
        .accessibilityHint(tab == .more ? "Opens Locations, Settings, and Storm Spotter" : "")
        .accessibilityIdentifier(DayCastAccessibility.Tabs.item(tab))
        .frame(maxWidth: .infinity)
      }
    }
    .padding(.top, 8)
    .padding(.bottom, 6)
    .background {
      DesignTokens.Palette.bgSecondary
        .ignoresSafeArea(edges: .bottom)
    }
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color.white.opacity(0.14))
        .frame(height: 0.5)
    }
    .ignoresSafeArea(.keyboard)
  }

  private var alertsChrome: AlertsHonesty.Chrome {
    let locID = store.currentLocation?.id.uuidString
    let hasSPC =
      locID != nil
      && severeStore.context.locationID == locID
      && severeStore.context.hasSPCContent
    return AlertsHonesty.chrome(
      nwsAlertCount: store.displayableActiveAlerts.count,
      hasSevereProducts: hasSPC
    )
  }

  private func iconName(for tab: CompactTab) -> String {
    tab == .alerts ? alertsChrome.tabSymbolName : tab.icon
  }

  private func accessibilityLabel(for tab: CompactTab) -> String {
    tab == .alerts ? alertsChrome.tabAccessibilityLabel : tab.title
  }

  private func accessibilityValue(for tab: CompactTab) -> String {
    guard tab == .alerts else { return "" }
    return alertsChrome.tabAccessibilityValue ?? ""
  }

  private func tabContent(for tab: CompactTab) -> some View {
    let active = tab.isSelected(for: selection)
    return VStack(spacing: 3) {
      ZStack {
        if active {
          RoundedRectangle(cornerRadius: pillCornerRadius)
            .fill(DesignTokens.Palette.accent)
            .matchedGeometryEffect(id: "pill", in: namespace)
            .frame(width: 40, height: 28)
        }
        Image(systemName: iconName(for: tab))
          .font(DesignTokens.Typography.symbol(20))
          .foregroundStyle(active ? activeColor : inactiveColor)
          .accessibilityHidden(true)
      }
      .frame(height: 28)
      Text(tab.title)
        .font(DesignTokens.Typography.micro())
        .foregroundStyle(active ? DesignTokens.Palette.textPrimary : inactiveColor)
        .accessibilityHidden(true)
    }
    .padding(.vertical, 4)
  }
}
