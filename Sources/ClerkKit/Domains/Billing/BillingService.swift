//
//  BillingService.swift
//  Clerk
//

import Foundation

protocol BillingServiceProtocol: Sendable {
  @MainActor func getPlans() async throws -> ClerkPaginatedResponse<BillingPlan>
  @MainActor func getSubscriptionItems() async throws -> ClerkPaginatedResponse<BillingSubscriptionItem>
  @MainActor func preflightStorePurchase(store: BillingStore, productId: String, purchaseOptionId: String?) async throws -> BillingStorePurchasePreflight
  @MainActor func createStorePurchase(store: BillingStore, payload: String) async throws -> BillingSubscriptionItem
}

/// The server's verdict on whether a store purchase may proceed.
///
/// Returned by `POST /v1/me/billing/store_purchases/preflight`, which checks every
/// Clerk-owned condition that can reject a purchase before the store payment sheet opens.
/// Conditions that fail are surfaced as thrown errors; an active subscription managed by
/// the same store is not a conflict, because purchasing another product there is a plan change.
package struct BillingStorePurchasePreflight: Codable, Equatable {
  /// Whether the purchase may proceed to the store payment sheet.
  package var allowed: Bool

  package init(allowed: Bool) {
    self.allowed = allowed
  }
}

final class BillingService: BillingServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func getPlans() async throws -> ClerkPaginatedResponse<BillingPlan> {
    let request = Request<ClerkPaginatedResponse<BillingPlan>>(
      path: "/v1/billing/plans",
      method: .get,
      query: [("payer_type", value: "user")]
    )

    return try await apiClient.send(request).value
  }

  @MainActor
  func getSubscriptionItems() async throws -> ClerkPaginatedResponse<BillingSubscriptionItem> {
    let request = Request<ClientResponse<ClerkPaginatedResponse<BillingSubscriptionItem>>>(
      path: "/v1/me/billing/subscription_items",
      method: .get,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func preflightStorePurchase(store: BillingStore, productId: String, purchaseOptionId: String?) async throws -> BillingStorePurchasePreflight {
    var body: [String: String] = [
      "store": store.rawValue,
      "product_id": productId,
    ]
    if let purchaseOptionId {
      body["purchase_option_id"] = purchaseOptionId
    }

    let request = Request<ClientResponse<BillingStorePurchasePreflight>>(
      path: "/v1/me/billing/store_purchases/preflight",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: body
    )

    do {
      return try await apiClient.send(request).value.response
    } catch let error as ClerkAPIError {
      if let billingError = ClerkBillingError(apiError: error) {
        throw billingError
      }
      throw error
    }
  }

  @MainActor
  func createStorePurchase(store: BillingStore, payload: String) async throws -> BillingSubscriptionItem {
    let request = Request<ClientResponse<BillingSubscriptionItem>>(
      path: "/v1/me/billing/store_purchases",
      method: .post,
      query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
      body: [
        "store": store.rawValue,
        "payload": payload,
      ]
    )

    do {
      return try await apiClient.send(request).value.response
    } catch let error as ClerkAPIError {
      if let billingError = ClerkBillingError(apiError: error) {
        throw billingError
      }
      throw error
    }
  }
}
