//
//  BillingAPI.swift
//  Clerk
//

import Foundation

package enum BillingAPI {
  package static func getPaymentAttempts(params: GetPaymentAttemptsParams) -> Request<ClerkPaginatedResponse<BillingPayment>> {
    Request(
      path: path("/payment_attempts", orgId: params.orgId),
      method: .get,
      scopedToActiveSession: true,
      query: paginationQuery(page: params.page, pageSize: params.pageSize)
    )
  }

  package static func getPaymentAttempt(params: GetPaymentAttemptParams) -> Request<BillingPayment> {
    Request(
      path: path("/payment_attempts/\(params.id)", orgId: params.orgId),
      method: .get,
      scopedToActiveSession: true
    )
  }

  package static func getPlans(params: GetPlansParams) -> Request<ClerkPaginatedResponse<BillingPlan>> {
    var query: [(String, String?)] = []
    query.append(("payer_type", value: params.for == .organization ? "org" : "user"))
    if let orgId = params.orgId {
      query.append(("org_id", value: orgId))
    }
    if let minSeats = params.minSeats {
      query.append(("min_seats", value: String(minSeats)))
    }
    query += paginationQuery(page: params.page, pageSize: params.pageSize)

    return Request(
      path: "/v1/billing/plans",
      method: .get,
      scopedToActiveSession: true,
      query: query
    )
  }

  package static func getPlan(params: GetPlanParams) -> Request<BillingPlan> {
    Request(
      path: "/v1/billing/plans/\(params.id)",
      method: .get,
      scopedToActiveSession: true
    )
  }

  package static func getSubscription(params: GetSubscriptionParams) -> Request<ClientResponse<BillingSubscription>> {
    Request(
      path: path("/subscription", orgId: params.orgId),
      method: .get,
      scopedToActiveSession: true
    )
  }

  package static func getStatements(params: GetStatementsParams) -> Request<ClientResponse<ClerkPaginatedResponse<BillingStatement>>> {
    Request(
      path: path("/statements", orgId: params.orgId),
      method: .get,
      scopedToActiveSession: true,
      query: paginationQuery(page: params.page, pageSize: params.pageSize)
    )
  }

  package static func getStatement(params: GetStatementParams) -> Request<ClientResponse<BillingStatement>> {
    Request(
      path: path("/statements/\(params.id)", orgId: params.orgId),
      method: .get,
      scopedToActiveSession: true
    )
  }

  package static func getCreditBalance(params: GetCreditBalanceParams) -> Request<ClientResponse<BillingCreditBalance>> {
    Request(
      path: path("/credits", orgId: params.orgId),
      method: .get,
      scopedToActiveSession: true
    )
  }

  package static func getCreditHistory(params: GetCreditHistoryParams) -> Request<ClientResponse<ClerkPaginatedResponse<BillingCreditLedger>>> {
    Request(
      path: path("/credits/history", orgId: params.orgId),
      method: .get,
      scopedToActiveSession: true,
      query: paginationQuery(page: params.page, pageSize: params.pageSize)
    )
  }

  package static func getPaymentMethods(
    params: GetPaymentMethodsParams,
    orgId: String?
  ) -> Request<ClientResponse<ClerkPaginatedResponse<BillingPaymentMethod>>> {
    Request(
      path: path("/payment_methods", orgId: orgId),
      method: .get,
      scopedToActiveSession: true,
      query: paginationQuery(page: params.page, pageSize: params.pageSize)
    )
  }

  private static func path(_ subPath: String, orgId: String?) -> String {
    let prefix = if let orgId, !orgId.isEmpty {
      "/v1/organizations/\(orgId)"
    } else {
      "/v1/me"
    }
    return "\(prefix)/billing\(subPath)"
  }

  private static func paginationQuery(page: Int, pageSize: Int) -> [(String, String?)] {
    [
      ("limit", value: String(pageSize)),
      ("offset", value: String(max(page - 1, 0) * pageSize)),
    ]
  }
}
