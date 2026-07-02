//
//  BillingService.swift
//  Clerk
//

import Foundation

protocol BillingServiceProtocol: Sendable {
  @MainActor func getPlans() async throws -> ClerkPaginatedResponse<BillingPlan>
  @MainActor func getSubscriptionItems() async throws -> ClerkPaginatedResponse<BillingSubscriptionItem>
  @MainActor func createStorePurchase(store: BillingStore, payload: String) async throws -> BillingSubscriptionItem
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
