import Foundation
import StoreKit

/// StoreKit 2 subscription state for GrokCast Pro.
@MainActor
@Observable
final class SubscriptionManager {
  static let shared = SubscriptionManager()

  private(set) var products: [Product] = []
  private(set) var isPro = false
  private(set) var proAuthToken: String?
  private(set) var isLoadingProducts = false
  private(set) var purchaseInFlight = false
  private(set) var lastErrorMessage: String?

  private var updatesTask: Task<Void, Never>?

  private init() {
    // Hydrate from the last-known entitlement so Pro users aren't paywalled during
    // the cold-launch window before StoreKit's entitlement check completes.
    // refreshEntitlements() corrects this within seconds if the subscription lapsed.
    isPro = WidgetAppGroup.userDefaults?.bool(forKey: WidgetDataStore.isProKey) ?? false
  }

  func start() async {
    guard updatesTask == nil else {
      await refreshEntitlements()
      return
    }
    updatesTask = Task { [weak self] in
      guard let self else { return }
      for await result in Transaction.updates {
        if case .verified(let transaction) = result {
          await transaction.finish()
          await self.refreshEntitlements()
        }
      }
    }
    // Entitlements gate features (paywall, widget brief) — resolve them before the
    // slower product-catalog load instead of after it.
    await refreshEntitlements()
    await loadProducts()
  }

  func loadProducts() async {
    isLoadingProducts = true
    defer { isLoadingProducts = false }
    do {
      products = try await Product.products(for: GrokCastProProducts.all)
        .sorted { $0.price < $1.price }
    } catch {
      lastErrorMessage = error.localizedDescription
      products = []
    }
  }

  func refreshEntitlements() async {
    var active = false
    var token: String?

    for await result in Transaction.currentEntitlements {
      guard case .verified(let transaction) = result else { continue }
      guard GrokCastProProducts.all.contains(transaction.productID) else { continue }
      if transaction.revocationDate == nil {
        active = true
        token = String(transaction.originalID)
        break
      }
    }

    isPro = active
    proAuthToken = token
    syncProFlagToAppGroup(active)
  }

  func purchase(_ product: Product) async throws {
    purchaseInFlight = true
    lastErrorMessage = nil
    defer { purchaseInFlight = false }

    let result = try await product.purchase()
    switch result {
    case .success(let verification):
      if case .verified(let transaction) = verification {
        await transaction.finish()
        await refreshEntitlements()
      }
    case .userCancelled:
      break
    case .pending:
      lastErrorMessage = "Purchase is pending approval."
    @unknown default:
      break
    }
  }

  func restorePurchases() async {
    purchaseInFlight = true
    lastErrorMessage = nil
    defer { purchaseInFlight = false }
    do {
      try await AppStore.sync()
      await refreshEntitlements()
      if !isPro {
        lastErrorMessage = "No active GrokCast Pro subscription found."
      }
    } catch {
      lastErrorMessage = error.localizedDescription
    }
  }

  func reportError(_ message: String) {
    lastErrorMessage = message
  }

  var monthlyProduct: Product? {
    products.first { $0.id == GrokCastProProducts.monthly }
  }

  var yearlyProduct: Product? {
    products.first { $0.id == GrokCastProProducts.yearly }
  }

  private func syncProFlagToAppGroup(_ isPro: Bool) {
    WidgetAppGroup.userDefaults?.set(isPro, forKey: WidgetDataStore.isProKey)
  }
}
