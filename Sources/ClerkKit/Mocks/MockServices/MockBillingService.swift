//
//  MockBillingService.swift
//  Clerk
//

import Foundation

package final class MockBillingService: BillingServiceProtocol {
  package nonisolated(unsafe) var getPaymentAttemptsHandler: ((GetPaymentAttemptsParams) async throws -> ClerkPaginatedResponse<BillingPayment>)?
  package nonisolated(unsafe) var getPaymentAttemptHandler: ((GetPaymentAttemptParams) async throws -> BillingPayment)?
  package nonisolated(unsafe) var getPlansHandler: ((GetPlansParams?) async throws -> ClerkPaginatedResponse<BillingPlan>)?
  package nonisolated(unsafe) var getPlanHandler: ((GetPlanParams) async throws -> BillingPlan)?
  package nonisolated(unsafe) var getSubscriptionHandler: ((GetSubscriptionParams) async throws -> BillingSubscription)?
  package nonisolated(unsafe) var getStatementsHandler: ((GetStatementsParams) async throws -> ClerkPaginatedResponse<BillingStatement>)?
  package nonisolated(unsafe) var getStatementHandler: ((GetStatementParams) async throws -> BillingStatement)?
  package nonisolated(unsafe) var getCreditBalanceHandler: ((GetCreditBalanceParams) async throws -> BillingCreditBalance)?
  package nonisolated(unsafe) var getCreditHistoryHandler: ((GetCreditHistoryParams) async throws -> ClerkPaginatedResponse<BillingCreditLedger>)?
  package nonisolated(unsafe) var getPaymentMethodsHandler: ((GetPaymentMethodsParams?, String?) async throws -> ClerkPaginatedResponse<BillingPaymentMethod>)?

  package init(
    getPaymentAttempts: ((GetPaymentAttemptsParams) async throws -> ClerkPaginatedResponse<BillingPayment>)? = nil,
    getPaymentAttempt: ((GetPaymentAttemptParams) async throws -> BillingPayment)? = nil,
    getPlans: ((GetPlansParams?) async throws -> ClerkPaginatedResponse<BillingPlan>)? = nil,
    getPlan: ((GetPlanParams) async throws -> BillingPlan)? = nil,
    getSubscription: ((GetSubscriptionParams) async throws -> BillingSubscription)? = nil,
    getStatements: ((GetStatementsParams) async throws -> ClerkPaginatedResponse<BillingStatement>)? = nil,
    getStatement: ((GetStatementParams) async throws -> BillingStatement)? = nil,
    getCreditBalance: ((GetCreditBalanceParams) async throws -> BillingCreditBalance)? = nil,
    getCreditHistory: ((GetCreditHistoryParams) async throws -> ClerkPaginatedResponse<BillingCreditLedger>)? = nil,
    getPaymentMethods: ((GetPaymentMethodsParams?, String?) async throws -> ClerkPaginatedResponse<BillingPaymentMethod>)? = nil
  ) {
    getPaymentAttemptsHandler = getPaymentAttempts
    getPaymentAttemptHandler = getPaymentAttempt
    getPlansHandler = getPlans
    getPlanHandler = getPlan
    getSubscriptionHandler = getSubscription
    getStatementsHandler = getStatements
    getStatementHandler = getStatement
    getCreditBalanceHandler = getCreditBalance
    getCreditHistoryHandler = getCreditHistory
    getPaymentMethodsHandler = getPaymentMethods
  }

  @MainActor
  package func getPaymentAttempts(params: GetPaymentAttemptsParams) async throws -> ClerkPaginatedResponse<BillingPayment> {
    if let getPaymentAttemptsHandler {
      return try await getPaymentAttemptsHandler(params)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  package func getPaymentAttempt(params: GetPaymentAttemptParams) async throws -> BillingPayment {
    if let getPaymentAttemptHandler {
      return try await getPaymentAttemptHandler(params)
    }
    return .mock
  }

  @MainActor
  package func getPlans(params: GetPlansParams?) async throws -> ClerkPaginatedResponse<BillingPlan> {
    if let getPlansHandler {
      return try await getPlansHandler(params)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  package func getPlan(params: GetPlanParams) async throws -> BillingPlan {
    if let getPlanHandler {
      return try await getPlanHandler(params)
    }
    return .mock
  }

  @MainActor
  package func getSubscription(params: GetSubscriptionParams) async throws -> BillingSubscription {
    if let getSubscriptionHandler {
      return try await getSubscriptionHandler(params)
    }
    return .mock
  }

  @MainActor
  package func getStatements(params: GetStatementsParams) async throws -> ClerkPaginatedResponse<BillingStatement> {
    if let getStatementsHandler {
      return try await getStatementsHandler(params)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  package func getStatement(params: GetStatementParams) async throws -> BillingStatement {
    if let getStatementHandler {
      return try await getStatementHandler(params)
    }
    return .mock
  }

  @MainActor
  package func getCreditBalance(params: GetCreditBalanceParams) async throws -> BillingCreditBalance {
    if let getCreditBalanceHandler {
      return try await getCreditBalanceHandler(params)
    }
    return .mock
  }

  @MainActor
  package func getCreditHistory(params: GetCreditHistoryParams) async throws -> ClerkPaginatedResponse<BillingCreditLedger> {
    if let getCreditHistoryHandler {
      return try await getCreditHistoryHandler(params)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }

  @MainActor
  package func getPaymentMethods(params: GetPaymentMethodsParams?, orgId: String?) async throws -> ClerkPaginatedResponse<BillingPaymentMethod> {
    if let getPaymentMethodsHandler {
      return try await getPaymentMethodsHandler(params, orgId)
    }
    return ClerkPaginatedResponse(data: [.mock], totalCount: 1)
  }
}
