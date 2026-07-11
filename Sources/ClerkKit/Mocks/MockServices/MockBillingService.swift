//
//  MockBillingService.swift
//  Clerk
//

import Foundation

/// Mock implementation of `BillingServiceProtocol` for testing and previews.
///
/// Allows customizing behavior through handler closures.
/// Returns default mock values if handlers are not provided.
package final class MockBillingService: BillingServiceProtocol {
  /// Custom handler for the `getPlans()` method.
  package nonisolated(unsafe) var getPlansHandler: (() async throws -> ClerkPaginatedResponse<BillingPlan>)?

  /// Custom handler for the `getSubscriptionItems()` method.
  package nonisolated(unsafe) var getSubscriptionItemsHandler: (() async throws -> ClerkPaginatedResponse<BillingSubscriptionItem>)?

  /// Custom handler for the `preflightStorePurchase(store:productId:purchaseOptionId:)` method.
  package nonisolated(unsafe) var preflightStorePurchaseHandler: ((BillingStore, String, String?) async throws -> BillingStorePurchasePreflight)?

  /// Custom handler for the `createStorePurchase(store:payload:)` method.
  package nonisolated(unsafe) var createStorePurchaseHandler: ((BillingStore, String) async throws -> BillingSubscriptionItem)?

  package init() {}

  @MainActor
  package func getPlans() async throws -> ClerkPaginatedResponse<BillingPlan> {
    if let handler = getPlansHandler {
      return try await handler()
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  package func getSubscriptionItems() async throws -> ClerkPaginatedResponse<BillingSubscriptionItem> {
    if let handler = getSubscriptionItemsHandler {
      return try await handler()
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  package func preflightStorePurchase(store: BillingStore, productId: String, purchaseOptionId: String?) async throws -> BillingStorePurchasePreflight {
    if let handler = preflightStorePurchaseHandler {
      return try await handler(store, productId, purchaseOptionId)
    }
    return BillingStorePurchasePreflight(allowed: true)
  }

  @MainActor
  package func createStorePurchase(store: BillingStore, payload: String) async throws -> BillingSubscriptionItem {
    if let handler = createStorePurchaseHandler {
      return try await handler(store, payload)
    }
    return .mock
  }
}
