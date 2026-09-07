//
//  Billing.swift
//  Clerk
//

import Foundation

@MainActor
public struct Billing {
  public func getPaymentAttempts(params: GetPaymentAttemptsParams) async throws -> ClerkPaginatedResponse<BillingPayment> {
    try await call(
      "getPaymentAttempts",
      pageArgs(orgId: params.orgId, initialPage: params.initialPage, pageSize: params.pageSize),
      as: ClerkPaginatedResponse<BillingPayment>.self
    )
  }

  public func getPaymentAttempt(params: GetPaymentAttemptParams) async throws -> BillingPayment {
    try await call("getPaymentAttempt", idArgs(params.id, orgId: params.orgId), as: BillingPayment.self)
  }

  public func getPlans(params: GetPlansParams? = nil) async throws -> ClerkPaginatedResponse<BillingPlan> {
    var args = pageArgs(orgId: params?.orgId, initialPage: params?.initialPage, pageSize: params?.pageSize)
    if let payer = params?.for {
      args["for"] = payer.rawValue
    }
    if let minSeats = params?.minSeats {
      args["minSeats"] = minSeats
    }
    return try await call("getPlans", args, as: ClerkPaginatedResponse<BillingPlan>.self)
  }

  public func getPlan(params: GetPlanParams) async throws -> BillingPlan {
    try await call("getPlan", ["id": params.id], as: BillingPlan.self)
  }

  public func getSubscription(params: GetSubscriptionParams) async throws -> BillingSubscription {
    try await call("getSubscription", orgArgs(params.orgId), as: BillingSubscription.self)
  }

  public func getStatements(params: GetStatementsParams) async throws -> ClerkPaginatedResponse<BillingStatement> {
    try await call(
      "getStatements",
      pageArgs(orgId: params.orgId, initialPage: params.initialPage, pageSize: params.pageSize),
      as: ClerkPaginatedResponse<BillingStatement>.self
    )
  }

  public func getStatement(params: GetStatementParams) async throws -> BillingStatement {
    try await call("getStatement", idArgs(params.id, orgId: params.orgId), as: BillingStatement.self)
  }

  public func getCreditBalance(params: GetCreditBalanceParams) async throws -> BillingCreditBalance {
    try await call("getCreditBalance", orgArgs(params.orgId), as: BillingCreditBalance.self)
  }

  public func getCreditHistory(params: GetCreditHistoryParams) async throws -> ClerkPaginatedResponse<BillingCreditLedger> {
    try await call("getCreditHistory", orgArgs(params.orgId), as: ClerkPaginatedResponse<BillingCreditLedger>.self)
  }

  private func call<T: Decodable>(_ method: String, _ args: [String: Any], as type: T.Type) async throws -> T {
    try await Clerk.callResourceSteps(
      .billing,
      [["method": method, "args": args]],
      as: type
    )
  }

  private func orgArgs(_ orgId: String?) -> [String: Any] {
    var args: [String: Any] = [:]
    if let orgId {
      args["orgId"] = orgId
    }
    return args
  }

  private func idArgs(_ id: String, orgId: String?) -> [String: Any] {
    var args = orgArgs(orgId)
    args["id"] = id
    return args
  }

  private func pageArgs(orgId: String?, initialPage: Int?, pageSize: Int?) -> [String: Any] {
    var args = orgArgs(orgId)
    if let initialPage {
      args["initialPage"] = initialPage
    }
    if let pageSize {
      args["pageSize"] = pageSize
    }
    return args
  }
}

func paymentMethodArgs(_ params: GetPaymentMethodsParams?) -> [String: Any] {
  var args: [String: Any] = [:]
  if let initialPage = params?.initialPage {
    args["initialPage"] = initialPage
  }
  if let pageSize = params?.pageSize {
    args["pageSize"] = pageSize
  }
  return args
}
