//
//  Billing.swift
//  Clerk
//

import Foundation
import StoreKit
#if os(visionOS)
import UIKit
#endif

/// The main entry point for billing operations in the Clerk SDK.
///
/// Access this via `clerk.billing` to fetch the plan catalog, purchase plans through the
/// App Store with StoreKit 2, and inspect the current user's subscription items.
///
/// ```swift
/// let plans = try await clerk.billing.plans()
/// let item = try await clerk.billing.purchase(plan: plans[0], period: .month)
/// ```
///
/// Call ``startObservingTransactionUpdates()`` early in your app's lifecycle so that
/// out-of-band transactions (renewals, Ask to Buy approvals, promo code redemptions)
/// are registered with Clerk as they arrive.
@MainActor
public struct Billing {
  private let billingService: BillingServiceProtocol

  /// Task that listens for out-of-band StoreKit transaction updates.
  private static var transactionUpdatesTask: Task<Void, Never>?

  init(billingService: BillingServiceProtocol) {
    self.billingService = billingService
  }

  // MARK: - Catalog

  /// Retrieves the billing plans available to users of the instance.
  ///
  /// Each plan includes the store product identifiers mapped to it in the Clerk Dashboard,
  /// so the returned plans can be passed directly to ``products(for:)`` or ``purchase(plan:period:)``.
  ///
  /// - Returns: The available ``BillingPlan`` objects.
  public func plans() async throws -> [BillingPlan] {
    try await billingService.getPlans().data
  }

  /// Retrieves the current user's subscription items.
  ///
  /// - Returns: The user's ``BillingSubscriptionItem`` objects.
  public func subscriptionItems() async throws -> [BillingSubscriptionItem] {
    try await billingService.getSubscriptionItems().data
  }

  /// Loads the StoreKit products mapped to the given plans.
  ///
  /// - Parameter plans: The plans to load App Store products for.
  /// - Returns: The StoreKit `Product` objects for every App Store product mapped to the plans.
  public func products(for plans: [BillingPlan]) async throws -> [Product] {
    let productIds = plans.flatMap { plan in
      (plan.storeProducts ?? [])
        .filter { $0.store == .apple }
        .map(\.productId)
    }

    guard !productIds.isEmpty else { return [] }
    return try await Product.products(for: productIds)
  }

  // MARK: - Purchasing

  #if !os(visionOS)
  /// Purchases a plan through the App Store using StoreKit 2.
  ///
  /// The purchase is stamped with an `appAccountToken` derived from the current Clerk user
  /// (see ``appAccountToken(forUserId:)``), the signed transaction is registered with Clerk,
  /// and the session token is refreshed so new feature claims are available immediately.
  /// The StoreKit transaction is finished only after Clerk accepts it.
  ///
  /// - Parameters:
  ///   - plan: The plan to purchase. Must have an App Store product mapped for `period`.
  ///   - period: The billing period to purchase. Defaults to `.month`.
  /// - Returns: The ``BillingSubscriptionItem`` created or activated by the purchase.
  /// - Throws: ``ClerkBillingError`` for purchase-flow failures, or ``ClerkAPIError`` if Clerk rejects the transaction.
  @discardableResult
  public func purchase(plan: BillingPlan, period: BillingPlanPeriod = .month) async throws -> BillingSubscriptionItem {
    let (product, appAccountToken) = try await preparePurchase(plan: plan, period: period)
    let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])
    return try await handlePurchaseResult(result)
  }
  #else
  /// Purchases a plan through the App Store using StoreKit 2.
  ///
  /// The purchase is stamped with an `appAccountToken` derived from the current Clerk user
  /// (see ``appAccountToken(forUserId:)``), the signed transaction is registered with Clerk,
  /// and the session token is refreshed so new feature claims are available immediately.
  /// The StoreKit transaction is finished only after Clerk accepts it.
  ///
  /// - Parameters:
  ///   - plan: The plan to purchase. Must have an App Store product mapped for `period`.
  ///   - period: The billing period to purchase. Defaults to `.month`.
  ///   - scene: The scene to display the purchase confirmation UI in.
  /// - Returns: The ``BillingSubscriptionItem`` created or activated by the purchase.
  /// - Throws: ``ClerkBillingError`` for purchase-flow failures, or ``ClerkAPIError`` if Clerk rejects the transaction.
  @discardableResult
  public func purchase(plan: BillingPlan, period: BillingPlanPeriod = .month, confirmIn scene: UIScene) async throws -> BillingSubscriptionItem {
    let (product, appAccountToken) = try await preparePurchase(plan: plan, period: period)
    let result = try await product.purchase(confirmIn: scene, options: [.appAccountToken(appAccountToken)])
    return try await handlePurchaseResult(result)
  }
  #endif

  /// Registers the user's current App Store entitlements with Clerk.
  ///
  /// Iterates `Transaction.currentEntitlements` and registers each verified auto-renewable
  /// subscription through the same endpoint used for purchases. Registration is idempotent
  /// server-side, so this is safe to call after reinstalls, on new devices, or from a
  /// "Restore Purchases" button.
  ///
  /// - Returns: The ``BillingSubscriptionItem`` objects for the registered entitlements.
  @discardableResult
  public func restorePurchases() async throws -> [BillingSubscriptionItem] {
    guard Clerk.shared.user != nil else {
      throw ClerkBillingError.notSignedIn
    }

    var items: [BillingSubscriptionItem] = []

    for await entitlement in Transaction.currentEntitlements {
      guard
        case .verified(let transaction) = entitlement,
        transaction.productType == .autoRenewable
      else {
        continue
      }

      let item = try await billingService.createStorePurchase(store: .apple, payload: entitlement.jwsRepresentation)
      items.append(item)
    }

    if !items.isEmpty {
      await Self.refreshSessionToken()
    }

    return items
  }

  // MARK: - Transaction Updates

  /// Starts observing `Transaction.updates` for out-of-band StoreKit transactions.
  ///
  /// Renewals completed while the app was backgrounded, Ask to Buy approvals, and promo code
  /// redemptions arrive through `Transaction.updates` rather than the purchase flow. Each
  /// verified transaction is registered with Clerk (idempotent server-side) and finished once
  /// Clerk accepts it. Transactions received while no user is signed in are left unfinished
  /// and are redelivered by StoreKit on the next launch.
  ///
  /// Call this once, early in your app's lifecycle. Calling it again while observation is
  /// active has no effect.
  public func startObservingTransactionUpdates() {
    guard Self.transactionUpdatesTask == nil else { return }

    Self.transactionUpdatesTask = Task {
      for await update in Transaction.updates {
        await Self.handle(transactionUpdate: update)
      }
    }
  }

  /// Stops observing `Transaction.updates`.
  public func stopObservingTransactionUpdates() {
    Self.transactionUpdatesTask?.cancel()
    Self.transactionUpdatesTask = nil
  }

  // MARK: - App Account Token

  /// The fixed namespace used to derive `appAccountToken` values from Clerk user IDs.
  static let appAccountTokenNamespace = UUID(uuidString: "44adf70c-c536-4bb6-b3fb-1c965c25e307")!

  /// Returns the deterministic `appAccountToken` for a Clerk user.
  ///
  /// The token is a name-based version 5 UUID (RFC 4122, SHA-1) computed over the raw Clerk
  /// user ID (for example `user_2abc...`) using the fixed namespace
  /// `44adf70c-c536-4bb6-b3fb-1c965c25e307`. The derivation is stable: the same user always
  /// produces the same token, on every device and after reinstalls. Clerk's backend performs
  /// the same derivation to verify that a submitted App Store transaction belongs to the
  /// session user.
  ///
  /// - Parameter userId: The Clerk user ID to derive the token from.
  /// - Returns: The `appAccountToken` UUID for the user.
  public static func appAccountToken(forUserId userId: String) -> UUID {
    UUID(v5Namespace: appAccountTokenNamespace, name: userId)
  }

  // MARK: - Private Helpers

  /// Resolves the StoreKit product and app account token for a purchase.
  private func preparePurchase(plan: BillingPlan, period: BillingPlanPeriod) async throws -> (Product, UUID) {
    guard let user = Clerk.shared.user else {
      throw ClerkBillingError.notSignedIn
    }

    guard let productId = plan.storeProductId(for: .apple, period: period) else {
      throw ClerkBillingError.storeProductNotConfigured(planId: plan.id, period: period)
    }

    guard let product = try await Product.products(for: [productId]).first else {
      throw ClerkBillingError.productNotFound(productId: productId)
    }

    return (product, Self.appAccountToken(forUserId: user.id))
  }

  /// Verifies a purchase result, registers it with Clerk, and finishes the transaction.
  private func handlePurchaseResult(_ result: Product.PurchaseResult) async throws -> BillingSubscriptionItem {
    switch result {
    case .success(let verification):
      guard case .verified(let transaction) = verification else {
        throw ClerkBillingError.verificationFailed
      }

      let item = try await billingService.createStorePurchase(store: .apple, payload: verification.jwsRepresentation)
      await transaction.finish()
      await Self.refreshSessionToken()
      return item
    case .userCancelled:
      throw ClerkBillingError.purchaseCancelled
    case .pending:
      throw ClerkBillingError.purchasePending
    @unknown default:
      throw ClerkClientError(message: "Unknown StoreKit purchase result.")
    }
  }

  /// Registers an out-of-band transaction update with Clerk.
  private static func handle(transactionUpdate verification: VerificationResult<Transaction>) async {
    guard case .verified(let transaction) = verification else { return }
    guard transaction.productType == .autoRenewable else { return }
    guard Clerk.shared.user != nil else { return }

    do {
      _ = try await Clerk.shared.dependencies.billingService.createStorePurchase(
        store: .apple,
        payload: verification.jwsRepresentation
      )
      await transaction.finish()
      await refreshSessionToken()
    } catch {
      ClerkLogger.logError(error, message: "Failed to register StoreKit transaction with Clerk")
    }
  }

  /// Forces a session token refresh so entitlement (`fea`) claims from a new subscription are live immediately.
  private static func refreshSessionToken() async {
    _ = try? await Clerk.shared.session?.getToken(.init(skipCache: true))
  }
}
