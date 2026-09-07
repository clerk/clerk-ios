//
//  Billing.swift
//  Clerk
//

import Foundation

@MainActor
public struct Billing {
  public func getPaymentAttempts(params: GetPaymentAttemptsParams) async throws -> ClerkPaginatedResponse<BillingPayment> {
    try await Clerk.getBillingPaymentAttempts(
      orgId: params.orgId,
      initialPage: params.initialPage,
      pageSize: params.pageSize
    )
  }

  public func getPaymentAttempt(params: GetPaymentAttemptParams) async throws -> BillingPayment {
    try await Clerk.getBillingPaymentAttempt(
      id: params.id,
      orgId: params.orgId,
      initialPage: params.initialPage,
      pageSize: params.pageSize
    )
  }

  public func getPlans(params: GetPlansParams? = nil) async throws -> ClerkPaginatedResponse<BillingPlan> {
    try await Clerk.getBillingPlans(params)
  }

  public func getPlan(params: GetPlanParams) async throws -> BillingPlan {
    try await Clerk.getBillingPlan(id: params.id)
  }

  public func getSubscription(params: GetSubscriptionParams) async throws -> BillingSubscription {
    try await Clerk.getBillingSubscription(orgId: params.orgId)
  }

  public func getStatements(params: GetStatementsParams) async throws -> ClerkPaginatedResponse<BillingStatement> {
    try await Clerk.getBillingStatements(
      orgId: params.orgId,
      initialPage: params.initialPage,
      pageSize: params.pageSize
    )
  }

  public func getStatement(params: GetStatementParams) async throws -> BillingStatement {
    try await Clerk.getBillingStatement(
      id: params.id,
      orgId: params.orgId,
      initialPage: params.initialPage,
      pageSize: params.pageSize
    )
  }

  public func getCreditBalance(params: GetCreditBalanceParams) async throws -> BillingCreditBalance {
    try await Clerk.getBillingCreditBalance(orgId: params.orgId)
  }

  public func getCreditHistory(params: GetCreditHistoryParams) async throws -> ClerkPaginatedResponse<BillingCreditLedger> {
    try await Clerk.getBillingCreditHistory(orgId: params.orgId)
  }
}
