//
//  Billing.swift
//  Clerk
//

import Foundation

@MainActor
public struct Billing {
  private let billingService: BillingServiceProtocol

  init(billingService: BillingServiceProtocol) {
    self.billingService = billingService
  }

  public func getPaymentAttempts(params: GetPaymentAttemptsParams) async throws -> ClerkPaginatedResponse<BillingPayment> {
    try await billingService.getPaymentAttempts(params: params)
  }

  public func getPaymentAttempt(params: GetPaymentAttemptParams) async throws -> BillingPayment {
    try await billingService.getPaymentAttempt(params: params)
  }

  public func getPlans(params: GetPlansParams? = nil) async throws -> ClerkPaginatedResponse<BillingPlan> {
    try await billingService.getPlans(params: params)
  }

  public func getPlan(params: GetPlanParams) async throws -> BillingPlan {
    try await billingService.getPlan(params: params)
  }

  public func getSubscription(params: GetSubscriptionParams) async throws -> BillingSubscription {
    try await billingService.getSubscription(params: params)
  }

  public func getStatements(params: GetStatementsParams) async throws -> ClerkPaginatedResponse<BillingStatement> {
    try await billingService.getStatements(params: params)
  }

  public func getStatement(params: GetStatementParams) async throws -> BillingStatement {
    try await billingService.getStatement(params: params)
  }

  public func getCreditBalance(params: GetCreditBalanceParams) async throws -> BillingCreditBalance {
    try await billingService.getCreditBalance(params: params)
  }

  public func getCreditHistory(params: GetCreditHistoryParams) async throws -> ClerkPaginatedResponse<BillingCreditLedger> {
    try await billingService.getCreditHistory(params: params)
  }
}
