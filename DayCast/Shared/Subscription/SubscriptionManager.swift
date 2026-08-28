import Foundation
import StoreKit

/// StoreKit 2 subscription state for DayCast Pro.
@MainActor
@Observable
final class SubscriptionManager {
  static let shared = SubscriptionManager()

  private(set) var products: [Product] = []
  private(set) var isPro = false
  /// Yearly extras (Future radar, Live Activity, Pro widgets). Monthly is not this.
  private(set) var isYearly = false
  /// Apple-signed proof of entitlement, sent to the Grok proxy on every AI call.
  /// The proxy verifies it against Apple's root, so nothing else here is trusted.
  private(set) var proTransactionJWS: String?
  private(set) var isLoadingProducts = false
  private(set) var purchaseInFlight = false
  private(set) var lastErrorMessage: String?

  private var updatesTask: Task<Void, Never>?

  private init() {
    // Split App Group flags: monthly keeps AI on cold launch; yearly extras
    // stay off until StoreKit confirms the yearly product (no monthly flash).
    let defaults = WidgetAppGroup.userDefaults
    isPro = defaults?.bool(forKey: WidgetDataStore.isProKey) ?? false
    isYearly = defaults?.bool(forKey: WidgetDataStore.isYearlyKey) ?? false
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
      products = try await Product.products(for: DayCastProProducts.all)
        .sorted { $0.price < $1.price }
    } catch {
      lastErrorMessage = error.localizedDescription
      products = []
    }
  }

  func refreshEntitlements() async {
    var productIDs: Set<String> = []
    var yearlyJWS: String?
    var monthlyJWS: String?

    for await result in Transaction.currentEntitlements {
      guard case .verified(let transaction) = result else { continue }
      guard DayCastProProducts.all.contains(transaction.productID) else { continue }
      guard transaction.revocationDate == nil else { continue }
      productIDs.insert(transaction.productID)
      // The JWS, not the transaction id: the proxy needs something only Apple
      // can produce, and `originalID` is a guessable integer. Prefer yearly.
      if transaction.productID == DayCastProProducts.yearly {
        yearlyJWS = result.jwsRepresentation
      } else if monthlyJWS == nil {
        monthlyJWS = result.jwsRepresentation
      }
    }

    let resolved = DayCastProProducts.resolvedEntitlement(productIDs: productIDs)
    isPro = resolved.isPro
    isYearly = resolved.isYearly
    proTransactionJWS = yearlyJWS ?? monthlyJWS
    syncFlagsToAppGroup(isPro: resolved.isPro, isYearly: resolved.isYearly)
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
        lastErrorMessage = "No active DayCast Pro subscription found."
      }
    } catch {
      lastErrorMessage = error.localizedDescription
    }
  }

  func reportError(_ message: String) {
    lastErrorMessage = message
  }

  var monthlyProduct: Product? {
    products.first { $0.id == DayCastProProducts.monthly }
  }

  var yearlyProduct: Product? {
    products.first { $0.id == DayCastProProducts.yearly }
  }

  private func syncFlagsToAppGroup(isPro: Bool, isYearly: Bool) {
    let defaults = WidgetAppGroup.userDefaults
    defaults?.set(isPro, forKey: WidgetDataStore.isProKey)
    defaults?.set(isYearly, forKey: WidgetDataStore.isYearlyKey)
  }
}
