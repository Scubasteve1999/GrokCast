import Foundation

/// App Store subscription product identifiers for DayCast Pro.
enum DayCastProProducts {
  static let monthly = "com.scubasteve1999.DayCast.pro.monthly"
  static let yearly = "com.scubasteve1999.DayCast.pro.yearly"

  static let all: Set<String> = [monthly, yearly]

  /// Yearly wins when both product ids are entitled.
  static func resolvedEntitlement(productIDs: Set<String>) -> (isPro: Bool, isYearly: Bool) {
    let paid = productIDs.intersection(all)
    return (isPro: !paid.isEmpty, isYearly: paid.contains(yearly))
  }
}

/// Row / subscribe copy from the product id. ASC displayName is “DayCast Pro” for both.
enum PaywallPeriodCopy {
  enum Period: Equatable {
    case monthly
    case yearly
    case unknown
  }

  static func period(forProductID id: String) -> Period {
    switch id {
    case DayCastProProducts.monthly: return .monthly
    case DayCastProProducts.yearly: return .yearly
    default: return .unknown
    }
  }

  /// Title on the plan row. Not StoreKit `displayName`.
  static func title(forProductID id: String) -> String? {
    switch period(forProductID: id) {
    case .monthly: return "Monthly"
    case .yearly: return "Yearly"
    case .unknown: return nil
    }
  }

  static func billedLine(forProductID id: String) -> String? {
    switch period(forProductID: id) {
    case .monthly: return "Billed monthly"
    case .yearly: return "Billed yearly"
    case .unknown: return nil
    }
  }

  static let monthlyInclusion = "AI and unlimited locations. Billed monthly."
  static let yearlyInclusion =
    "AI, locations, Future radar, widgets, Live Activity. Billed yearly."
  static let liveActivityRequiresYearly = "Requires Yearly"
  static let liveActivityActiveSubtitle = "Lock Screen score + Next 2 Hours"

  /// Inclusion line from the product id. Never StoreKit `description` — ASC is the same for both.
  static func subtitle(productID: String) -> String {
    switch period(forProductID: productID) {
    case .monthly: return monthlyInclusion
    case .yearly: return yearlyInclusion
    case .unknown: return ""
    }
  }

  static func subscribeTitle(productID: String, displayPrice: String) -> String {
    switch period(forProductID: productID) {
    case .monthly: return "Subscribe monthly — \(displayPrice)"
    case .yearly: return "Subscribe yearly — \(displayPrice)"
    case .unknown: return "Subscribe — \(displayPrice)"
    }
  }

  /// Honest leftover vs 12 × monthly. Caller formats with StoreKit `priceFormatStyle`.
  static func savingsLine(
    monthlyPrice: Decimal,
    yearlyPrice: Decimal,
    formattedSavings: String
  ) -> String? {
    let saved = monthlyPrice * 12 - yearlyPrice
    guard saved > 0 else { return nil }
    return "Save \(formattedSavings) vs 12 months"
  }
}
