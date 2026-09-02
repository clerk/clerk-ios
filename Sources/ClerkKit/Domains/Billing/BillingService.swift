//
//  BillingService.swift
//  Clerk
//

import Foundation

protocol BillingServiceProtocol: Sendable {
  @MainActor func getPaymentAttempts(params: GetPaymentAttemptsParams) async throws -> ClerkPaginatedResponse<BillingPayment>
  @MainActor func getPaymentAttempt(params: GetPaymentAttemptParams) async throws -> BillingPayment
  @MainActor func getPlans(params: GetPlansParams?) async throws -> ClerkPaginatedResponse<BillingPlan>
  @MainActor func getPlan(params: GetPlanParams) async throws -> BillingPlan
  @MainActor func getSubscription(params: GetSubscriptionParams) async throws -> BillingSubscription
  @MainActor func getStatements(params: GetStatementsParams) async throws -> ClerkPaginatedResponse<BillingStatement>
  @MainActor func getStatement(params: GetStatementParams) async throws -> BillingStatement
  @MainActor func getCreditBalance(params: GetCreditBalanceParams) async throws -> BillingCreditBalance
  @MainActor func getCreditHistory(params: GetCreditHistoryParams) async throws -> ClerkPaginatedResponse<BillingCreditLedger>
  @MainActor func getPaymentMethods(params: GetPaymentMethodsParams?, orgId: String?) async throws -> ClerkPaginatedResponse<BillingPaymentMethod>
}

final class BillingService: BillingServiceProtocol {
  private let apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  @MainActor
  func getPaymentAttempts(params: GetPaymentAttemptsParams) async throws -> ClerkPaginatedResponse<BillingPayment> {
    let request = Request<ClerkPaginatedResponse<BillingPayment>>(
      path: Self.path("/payment_attempts", orgId: params.orgId),
      method: .get,
      query: sessionQuery() + paginationQuery(initialPage: params.initialPage, pageSize: params.pageSize)
    )

    return try await apiClient.send(request).value
  }

  @MainActor
  func getPaymentAttempt(params: GetPaymentAttemptParams) async throws -> BillingPayment {
    let request = Request<BillingPayment>(
      path: Self.path("/payment_attempts/\(params.id)", orgId: params.orgId),
      method: .get,
      query: sessionQuery()
    )

    return try await apiClient.send(request).value
  }

  @MainActor
  func getPlans(params: GetPlansParams?) async throws -> ClerkPaginatedResponse<BillingPlan> {
    var query = sessionQuery()
    query.append(("payer_type", value: params?.for == .organization ? "org" : "user"))
    if let orgId = params?.orgId {
      query.append(("org_id", value: orgId))
    }
    if let minSeats = params?.minSeats {
      query.append(("min_seats", value: String(minSeats)))
    }
    query += paginationQuery(initialPage: params?.initialPage, pageSize: params?.pageSize)

    let request = Request<ClerkPaginatedResponse<BillingPlan>>(
      path: "/v1/billing/plans",
      method: .get,
      query: query
    )

    return try await apiClient.send(request).value
  }

  @MainActor
  func getPlan(params: GetPlanParams) async throws -> BillingPlan {
    let request = Request<BillingPlan>(
      path: "/v1/billing/plans/\(params.id)",
      method: .get,
      query: sessionQuery()
    )

    return try await apiClient.send(request).value
  }

  @MainActor
  func getSubscription(params: GetSubscriptionParams) async throws -> BillingSubscription {
    let request = Request<ClientResponse<BillingSubscription>>(
      path: Self.path("/subscription", orgId: params.orgId),
      method: .get,
      query: sessionQuery()
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func getStatements(params: GetStatementsParams) async throws -> ClerkPaginatedResponse<BillingStatement> {
    let request = Request<ClientResponse<ClerkPaginatedResponse<BillingStatement>>>(
      path: Self.path("/statements", orgId: params.orgId),
      method: .get,
      query: sessionQuery() + paginationQuery(initialPage: params.initialPage, pageSize: params.pageSize)
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func getStatement(params: GetStatementParams) async throws -> BillingStatement {
    let request = Request<ClientResponse<BillingStatement>>(
      path: Self.path("/statements/\(params.id)", orgId: params.orgId),
      method: .get,
      query: sessionQuery()
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func getCreditBalance(params: GetCreditBalanceParams) async throws -> BillingCreditBalance {
    let request = Request<ClientResponse<BillingCreditBalance>>(
      path: Self.path("/credits", orgId: params.orgId),
      method: .get,
      query: sessionQuery()
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func getCreditHistory(params: GetCreditHistoryParams) async throws -> ClerkPaginatedResponse<BillingCreditLedger> {
    let request = Request<ClientResponse<ClerkPaginatedResponse<BillingCreditLedger>>>(
      path: Self.path("/credits/history", orgId: params.orgId),
      method: .get,
      query: sessionQuery()
    )

    return try await apiClient.send(request).value.response
  }

  @MainActor
  func getPaymentMethods(params: GetPaymentMethodsParams?, orgId: String?) async throws -> ClerkPaginatedResponse<BillingPaymentMethod> {
    let request = Request<ClientResponse<ClerkPaginatedResponse<BillingPaymentMethod>>>(
      path: Self.path("/payment_methods", orgId: orgId),
      method: .get,
      query: sessionQuery() + paginationQuery(initialPage: params?.initialPage, pageSize: params?.pageSize)
    )

    return try await apiClient.send(request).value.response
  }

  static func path(_ subPath: String, orgId: String?) -> String {
    let prefix = if let orgId, !orgId.isEmpty {
      "/v1/organizations/\(orgId)"
    } else {
      "/v1/me"
    }
    return "\(prefix)/billing\(subPath)"
  }

  @MainActor
  private func sessionQuery() -> [(String, String?)] {
    [("_clerk_session_id", value: Clerk.shared.session?.id)]
  }

  private func paginationQuery(initialPage: Int?, pageSize: Int?) -> [(String, String?)] {
    let resolvedPageSize = pageSize ?? 10
    let resolvedInitialPage = initialPage ?? 1
    return [
      ("limit", value: String(resolvedPageSize)),
      ("offset", value: String((resolvedInitialPage - 1) * resolvedPageSize)),
    ]
  }
}
