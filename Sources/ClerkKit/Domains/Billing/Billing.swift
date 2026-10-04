//
//  Billing.swift
//  Clerk
//

import Foundation

/// Reads Clerk Billing data: Plans, Subscriptions, statements, payment attempts, and credits.
///
/// Methods that read a payer's data take an optional `orgId`: omit it for the signed-in user, or pass
/// an Organization ID to read that Organization's data, which requires the `org:sys_billing:read`
/// Permission.
@MainActor
public struct Billing {
  private let transport: any APITransport

  init(transport: any APITransport) {
    self.transport = transport
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
    try await transport.send(BillingAPI.getPlans(
      params: GetPlansParams(for: payerType, orgId: orgId, minSeats: minSeats, page: page, pageSize: pageSize)
    )).value
  }

  /// Gets a Plan by ID.
  public func getPlan(id: String) async throws -> BillingPlan {
    try await transport.send(BillingAPI.getPlan(params: GetPlanParams(id: id))).value
  }

  /// Gets the Subscription of the signed-in user, or of the Organization with `orgId`.
  public func getSubscription(orgId: String? = nil) async throws -> BillingSubscription {
    try await transport.send(BillingAPI.getSubscription(params: GetSubscriptionParams(orgId: orgId))).value.response
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
    try await transport.send(BillingAPI.getStatements(params: GetStatementsParams(orgId: orgId, page: page, pageSize: pageSize))).value.response
  }

  /// Gets a statement by ID.
  public func getStatement(id: String, orgId: String? = nil) async throws -> BillingStatement {
    try await transport.send(BillingAPI.getStatement(params: GetStatementParams(id: id, orgId: orgId))).value.response
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
    try await transport.send(BillingAPI.getPaymentAttempts(
      params: GetPaymentAttemptsParams(orgId: orgId, page: page, pageSize: pageSize)
    )).value
  }

  /// Gets a payment attempt by ID.
  public func getPaymentAttempt(id: String, orgId: String? = nil) async throws -> BillingPayment {
    try await transport.send(BillingAPI.getPaymentAttempt(params: GetPaymentAttemptParams(id: id, orgId: orgId))).value
  }

  /// Gets the credit balance of the signed-in user, or of the Organization with `orgId`.
  public func getCreditBalance(orgId: String? = nil) async throws -> BillingCreditBalance {
    try await transport.send(BillingAPI.getCreditBalance(params: GetCreditBalanceParams(orgId: orgId))).value.response
  }

  /// Lists the credit ledger entries of the signed-in user, or of the Organization with `orgId`.
  ///
  /// - Parameters:
  ///   - orgId: The Organization to read. Omit for the signed-in user.
  ///   - page: The 1-based page number to fetch. Defaults to `1`.
  ///   - pageSize: The maximum number of entries to return per page. Defaults to `20`.
  public func getCreditHistory(
    orgId: String? = nil,
    page: Int = 1,
    pageSize: Int = 20
  ) async throws -> ClerkPaginatedResponse<BillingCreditLedger> {
    try await transport.send(BillingAPI.getCreditHistory(
      params: GetCreditHistoryParams(orgId: orgId, page: page, pageSize: pageSize)
    )).value.response
  }
}
