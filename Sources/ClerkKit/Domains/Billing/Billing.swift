//
//  Billing.swift
//  Clerk
//

import Foundation

/// Reads Clerk Billing data: Plans, Subscriptions, statements, payment attempts, and credits.
///
/// Access it through ``Clerk/billing``. Methods that read a payer's data take an optional `orgId`:
/// omit it for the signed-in user, or pass an Organization ID to read that Organization's data,
/// which requires the `org:sys_billing:read` Permission. Payment methods are read from
/// ``User/getPaymentMethods(page:pageSize:)`` and ``Organization/getPaymentMethods(page:pageSize:)``.
///
/// This is a beta API and may change.
@MainActor
public struct Billing {
  private let billingService: BillingServiceProtocol

  init(billingService: BillingServiceProtocol) {
    self.billingService = billingService
  }

  /// Lists your publicly visible Plans.
  ///
  /// - Parameters:
  ///   - payerType: Whether to list user Plans or Organization Plans. Defaults to `.user`.
  ///   - orgId: The Organization to fetch Plans for. Populates each Plan's available prices for
  ///     that Organization.
  ///   - minSeats: The minimum number of seats the returned Plans need to support.
  ///   - page: The 1-based page number to fetch. Defaults to `1`.
  ///   - pageSize: The maximum number of Plans to return per page. Defaults to `20`.
  public func getPlans(
    for payerType: ForPayerType = .user,
    orgId: String? = nil,
    minSeats: Int? = nil,
    page: Int = 1,
    pageSize: Int = 20
  ) async throws -> ClerkPaginatedResponse<BillingPlan> {
    try await billingService.getPlans(
      params: GetPlansParams(for: payerType, orgId: orgId, minSeats: minSeats, page: page, pageSize: pageSize)
    )
  }

  /// Gets a Plan by ID.
  public func getPlan(id: String) async throws -> BillingPlan {
    try await billingService.getPlan(params: GetPlanParams(id: id))
  }

  /// Gets the Subscription of the signed-in user, or of the Organization with `orgId`.
  public func getSubscription(orgId: String? = nil) async throws -> BillingSubscription {
    try await billingService.getSubscription(params: GetSubscriptionParams(orgId: orgId))
  }

  /// Lists the statements of the signed-in user, or of the Organization with `orgId`.
  ///
  /// - Parameters:
  ///   - orgId: The Organization to read. Omit for the signed-in user.
  ///   - page: The 1-based page number to fetch. Defaults to `1`.
  ///   - pageSize: The maximum number of statements to return per page. Defaults to `20`.
  public func getStatements(
    orgId: String? = nil,
    page: Int = 1,
    pageSize: Int = 20
  ) async throws -> ClerkPaginatedResponse<BillingStatement> {
    try await billingService.getStatements(params: GetStatementsParams(orgId: orgId, page: page, pageSize: pageSize))
  }

  /// Gets a statement by ID.
  public func getStatement(id: String, orgId: String? = nil) async throws -> BillingStatement {
    try await billingService.getStatement(params: GetStatementParams(id: id, orgId: orgId))
  }

  /// Lists the payment attempts of the signed-in user, or of the Organization with `orgId`.
  ///
  /// - Parameters:
  ///   - orgId: The Organization to read. Omit for the signed-in user.
  ///   - page: The 1-based page number to fetch. Defaults to `1`.
  ///   - pageSize: The maximum number of payment attempts to return per page. Defaults to `20`.
  public func getPaymentAttempts(
    orgId: String? = nil,
    page: Int = 1,
    pageSize: Int = 20
  ) async throws -> ClerkPaginatedResponse<BillingPayment> {
    try await billingService.getPaymentAttempts(
      params: GetPaymentAttemptsParams(orgId: orgId, page: page, pageSize: pageSize)
    )
  }

  /// Gets a payment attempt by ID.
  public func getPaymentAttempt(id: String, orgId: String? = nil) async throws -> BillingPayment {
    try await billingService.getPaymentAttempt(params: GetPaymentAttemptParams(id: id, orgId: orgId))
  }

  /// Gets the credit balance of the signed-in user, or of the Organization with `orgId`.
  public func getCreditBalance(orgId: String? = nil) async throws -> BillingCreditBalance {
    try await billingService.getCreditBalance(params: GetCreditBalanceParams(orgId: orgId))
  }

  /// Gets every credit ledger entry of the signed-in user, or of the Organization with `orgId`.
  public func getCreditHistory(orgId: String? = nil) async throws -> ClerkPaginatedResponse<BillingCreditLedger> {
    try await billingService.getCreditHistory(params: GetCreditHistoryParams(orgId: orgId))
  }
}
