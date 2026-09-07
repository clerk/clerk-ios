import ClerkSnapshots
import Foundation

extension Billing {
  public func getPaymentAttempts(params: ClerkKit.GetPaymentAttemptsParams) async throws -> ClerkPaginatedResponse<BillingPayment> {
    try await Clerk.js(
      .billing,
      BillingJSCall.getPaymentAttempts(
        ClerkSnapshots.GetPaymentAttemptsParams(
          initialPage: params.initialPage,
          pageSize: params.pageSize,
          orgId: params.orgId
        )
      ),
      as: ClerkPaginatedResponse<BillingPayment>.self
    )
  }

  public func getPaymentAttempt(params: ClerkKit.GetPaymentAttemptParams) async throws -> BillingPayment {
    try await Clerk.js(
      .billing,
      BillingJSCall.getPaymentAttempt(
        ClerkSnapshots.GetPaymentAttemptParams(
          id: params.id,
          initialPage: params.initialPage,
          pageSize: params.pageSize,
          orgId: params.orgId
        )
      ),
      as: BillingPayment.self
    )
  }

  public func getPlans(params: ClerkKit.GetPlansParams? = nil) async throws -> ClerkPaginatedResponse<BillingPlan> {
    try await Clerk.js(
      .billing,
      BillingJSCall.getPlans(
        params.map {
          ClerkSnapshots.GetPlansParams(
            initialPage: $0.initialPage,
            pageSize: $0.pageSize,
            for: $0.for.map(plansFor(from:)),
            orgId: $0.orgId,
            minSeats: $0.minSeats
          )
        }
      ),
      as: ClerkPaginatedResponse<BillingPlan>.self
    )
  }

  public func getPlan(params: ClerkKit.GetPlanParams) async throws -> BillingPlan {
    try await Clerk.js(
      .billing,
      BillingJSCall.getPlan(ClerkSnapshots.GetPlanParams(id: params.id)),
      as: BillingPlan.self
    )
  }

  public func getSubscription(params: ClerkKit.GetSubscriptionParams) async throws -> BillingSubscription {
    try await Clerk.js(
      .billing,
      BillingJSCall.getSubscription(ClerkSnapshots.GetSubscriptionParams(orgId: params.orgId)),
      as: BillingSubscription.self
    )
  }

  public func getStatements(params: ClerkKit.GetStatementsParams) async throws -> ClerkPaginatedResponse<BillingStatement> {
    try await Clerk.js(
      .billing,
      BillingJSCall.getStatements(
        ClerkSnapshots.GetStatementsParams(
          initialPage: params.initialPage,
          pageSize: params.pageSize,
          orgId: params.orgId
        )
      ),
      as: ClerkPaginatedResponse<BillingStatement>.self
    )
  }

  public func getStatement(params: ClerkKit.GetStatementParams) async throws -> BillingStatement {
    try await Clerk.js(
      .billing,
      BillingJSCall.getStatement(
        ClerkSnapshots.GetStatementParams(
          id: params.id,
          initialPage: params.initialPage,
          pageSize: params.pageSize,
          orgId: params.orgId
        )
      ),
      as: BillingStatement.self
    )
  }

  public func getCreditBalance(params: ClerkKit.GetCreditBalanceParams) async throws -> BillingCreditBalance {
    try await Clerk.js(
      .billing,
      BillingJSCall.getCreditBalance(ClerkSnapshots.GetCreditBalanceParams(orgId: params.orgId)),
      as: BillingCreditBalance.self
    )
  }

  public func getCreditHistory(params: ClerkKit.GetCreditHistoryParams) async throws -> ClerkPaginatedResponse<BillingCreditLedger> {
    try await Clerk.js(
      .billing,
      BillingJSCall.getCreditHistory(ClerkSnapshots.GetCreditHistoryParams(orgId: params.orgId)),
      as: ClerkPaginatedResponse<BillingCreditLedger>.self
    )
  }

  private func plansFor(from payer: ForPayerType) -> GetPlansParamsFor {
    switch payer {
    case .organization:
      .organization
    case .user:
      .user
    }
  }
}
