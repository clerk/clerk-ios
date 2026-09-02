@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct BillingTests {
  init() {
    configureClerkForTesting()
  }

  private let decoder = JSONDecoder.clerkDecoder

  @Test
  func billingGetMethodsAreCallable() async throws {
    // Omitted write APIs from clerk-js BillingNamespace / BillingPayerMethods:
    // startCheckout, updateCheckout, initializePaymentMethod, addPaymentMethod,
    // cancel, remove, makeDefault
    let service = MockBillingService()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      billingService: service
    )

    _ = try await Clerk.shared.billing.getPaymentAttempts(params: .init())
    _ = try await Clerk.shared.billing.getPaymentAttempt(params: .init(id: "pay_1"))
    _ = try await Clerk.shared.billing.getPlans()
    _ = try await Clerk.shared.billing.getPlan(params: .init(id: "plan_1"))
    _ = try await Clerk.shared.billing.getSubscription(params: .init())
    _ = try await Clerk.shared.billing.getStatements(params: .init())
    _ = try await Clerk.shared.billing.getStatement(params: .init(id: "stmt_1"))
    _ = try await Clerk.shared.billing.getCreditBalance(params: .init())
    _ = try await Clerk.shared.billing.getCreditHistory(params: .init())
    _ = try await User.mock.getPaymentMethods()
    _ = try await Organization.mock.getPaymentMethods()
  }

  @Test
  func getPlansMapsOrganizationPayerTypeAndPagination() async throws {
    let requestHandled = LockIsolated(false)
    var mock = try Mock(
      url: URL(string: mockBaseUrl.absoluteString + "/v1/billing/plans")!,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(ClerkPaginatedResponse(data: [BillingPlan.mock], totalCount: 1)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("_clerk_session_id") == true)
      #expect(request.url?.queryParam(named: "payer_type") == "org")
      #expect(request.url?.queryParam(named: "org_id") == "org_123")
      #expect(request.url?.queryParam(named: "min_seats") == "5")
      #expect(request.url?.queryParam(named: "limit") == "10")
      #expect(request.url?.queryParam(named: "offset") == "20")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.billing.getPlans(
      params: .init(
        for: .organization,
        orgId: "org_123",
        minSeats: 5,
        initialPage: 3,
        pageSize: 10
      )
    )
    #expect(requestHandled.value)
  }

  @Test
  func getPlansDefaultsToUserPayerTypeAndFirstPage() async throws {
    let requestHandled = LockIsolated(false)
    var mock = try Mock(
      url: URL(string: mockBaseUrl.absoluteString + "/v1/billing/plans")!,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(ClerkPaginatedResponse(data: [BillingPlan.mock], totalCount: 1)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.url?.queryParam(named: "payer_type") == "user")
      #expect(request.url?.queryParam(named: "org_id") == nil)
      #expect(request.url?.queryParam(named: "min_seats") == nil)
      #expect(request.url?.queryParam(named: "limit") == "10")
      #expect(request.url?.queryParam(named: "offset") == "0")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.billing.getPlans()
    #expect(requestHandled.value)
  }

  @Test
  func userAndOrganizationUseDistinctBillingPathPrefixes() async throws {
    try await assertGET(
      path: "/v1/me/billing/subscription",
      body: encodeClientResponse(BillingSubscription.mock)
    ) {
      _ = try await Clerk.shared.billing.getSubscription(params: .init())
    }

    try await assertGET(
      path: "/v1/organizations/org_123/billing/subscription",
      body: encodeClientResponse(BillingSubscription.mock)
    ) {
      _ = try await Clerk.shared.billing.getSubscription(params: .init(orgId: "org_123"))
    }

    try await assertGET(
      path: "/v1/me/billing/statements",
      body: encodeClientResponse(ClerkPaginatedResponse(data: [BillingStatement.mock], totalCount: 1))
    ) {
      _ = try await Clerk.shared.billing.getStatements(params: .init())
    }

    try await assertGET(
      path: "/v1/organizations/org_123/billing/statements",
      body: encodeClientResponse(ClerkPaginatedResponse(data: [BillingStatement.mock], totalCount: 1))
    ) {
      _ = try await Clerk.shared.billing.getStatements(params: .init(orgId: "org_123"))
    }

    try await assertGET(
      path: "/v1/me/billing/payment_attempts",
      body: JSONEncoder.clerkEncoder.encode(ClerkPaginatedResponse(data: [BillingPayment.mock], totalCount: 1))
    ) {
      _ = try await Clerk.shared.billing.getPaymentAttempts(params: .init())
    }

    try await assertGET(
      path: "/v1/organizations/org_123/billing/payment_attempts",
      body: JSONEncoder.clerkEncoder.encode(ClerkPaginatedResponse(data: [BillingPayment.mock], totalCount: 1))
    ) {
      _ = try await Clerk.shared.billing.getPaymentAttempts(params: .init(orgId: "org_123"))
    }

    try await assertGET(
      path: "/v1/me/billing/credits",
      body: encodeClientResponse(BillingCreditBalance.mock)
    ) {
      _ = try await Clerk.shared.billing.getCreditBalance(params: .init())
    }

    try await assertGET(
      path: "/v1/organizations/org_123/billing/credits",
      body: encodeClientResponse(BillingCreditBalance.mock)
    ) {
      _ = try await Clerk.shared.billing.getCreditBalance(params: .init(orgId: "org_123"))
    }

    try await assertGET(
      path: "/v1/me/billing/payment_methods",
      body: encodeClientResponse(ClerkPaginatedResponse(data: [BillingPaymentMethod.mock], totalCount: 1))
    ) {
      _ = try await User.mock.getPaymentMethods()
    }

    try await assertGET(
      path: "/v1/organizations/\(Organization.mock.id)/billing/payment_methods",
      body: encodeClientResponse(ClerkPaginatedResponse(data: [BillingPaymentMethod.mock], totalCount: 1))
    ) {
      _ = try await Organization.mock.getPaymentMethods()
    }
  }

  @Test
  func getCreditHistoryOmitsPagination() async throws {
    let requestHandled = LockIsolated(false)
    var mock = try Mock(
      url: URL(string: mockBaseUrl.absoluteString + "/v1/me/billing/credits/history")!,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .get: encodeClientResponse(ClerkPaginatedResponse(data: [BillingCreditLedger.mock], totalCount: 1)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.url?.queryParam(named: "limit") == nil)
      #expect(request.url?.queryParam(named: "offset") == nil)
      #expect(request.url?.query?.contains("_clerk_session_id") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.billing.getCreditHistory(params: .init())
    #expect(requestHandled.value)
  }

  @Test
  func decodesFeature() throws {
    let feature = try decoder.decode(Feature.self, from: Data(featureJSON.utf8))
    #expect(feature.id == "feat_1")
    #expect(feature.name == "SSO")
    #expect(feature.description == "Single sign-on")
    #expect(feature.slug == "sso")
    #expect(feature.avatarUrl == nil)
  }

  @Test
  func decodesBillingMoneyAmount() throws {
    let money = try decoder.decode(BillingMoneyAmount.self, from: Data(moneyJSON.utf8))
    #expect(money.amount == 1000)
    #expect(money.amountFormatted == "10.00")
    #expect(money.currency == "USD")
    #expect(money.currencySymbol == "$")
  }

  @Test
  func decodesBillingPlanWithFeaturesUnitPricesAndAvailablePrices() throws {
    let plan = try decoder.decode(BillingPlan.self, from: Data(planJSON.utf8))
    #expect(plan.id == "plan_1")
    #expect(plan.fee?.amount == 1000)
    #expect(plan.annualFee?.amountFormatted == "10.00")
    #expect(plan.features.map(\.slug) == ["sso"])
    #expect(plan.unitPrices?.first?.name == "seats")
    #expect(plan.unitPrices?.first?.tiers.first?.startsAtBlock == 1)
    #expect(plan.availablePrices?.first?.id == "price_1")
    #expect(plan.freeTrialDays == 14)
    #expect(plan.freeTrialEnabled)
  }

  @Test
  func decodesBillingPlanDefaultsMissingFeaturesAndTrial() throws {
    let json = Data(
      """
      {
        "id": "plan_free",
        "name": "Free",
        "fee": null,
        "annual_fee": null,
        "annual_monthly_fee": null,
        "description": null,
        "is_default": true,
        "is_recurring": true,
        "has_base_fee": false,
        "for_payer_type": "user",
        "publicly_visible": true,
        "slug": "free",
        "avatar_url": null
      }
      """.utf8
    )

    let plan = try decoder.decode(BillingPlan.self, from: json)
    #expect(plan.features.isEmpty)
    #expect(plan.freeTrialDays == nil)
    #expect(!plan.freeTrialEnabled)
  }

  @Test
  func decodesBillingSubscriptionWithSeatsCreditsAndDiscounts() throws {
    let subscription = try decoder.decode(BillingSubscription.self, from: Data(subscriptionJSON.utf8))
    let item = try #require(subscription.subscriptionItems.first)
    #expect(subscription.status == .active)
    #expect(item.seats?.quantity == 5)
    #expect(item.seats?.tiers?.first?.total.amount == 1000)
    #expect(item.credits?.proration?.cycleDaysRemaining == 10)
    #expect(item.appliedDiscount?.source == .promoCode)
    #expect(item.appliedDiscount?.percentOff == 20)
    #expect(item.credit?.amount.currencySymbol == "$")
    #expect(item.isFreeTrial == false)
  }

  @Test
  func decodesBillingStatementWithTotals() throws {
    let statement = try decoder.decode(BillingStatement.self, from: Data(statementJSON.utf8))
    #expect(statement.status == .open)
    #expect(statement.totals.subtotal.amount == 1000)
    #expect(statement.totals.grandTotal.amountFormatted == "10.00")
    #expect(statement.totals.taxTotal.currency == "USD")
    #expect(statement.groups.first?.items.first?.id == "pay_1")
  }

  @Test
  func decodesBillingPaymentWithTotals() throws {
    let payment = try decoder.decode(BillingPayment.self, from: Data(paymentJSON.utf8))
    #expect(payment.status == .paid)
    #expect(payment.chargeType == .recurring)
    #expect(payment.totals?.grandTotal.amount == 1000)
    #expect(payment.totals?.discounts?.proration?.cycleDaysPassed == 10)
    #expect(payment.totals?.perUnitTotals?.first?.name == "seats")
    #expect(payment.paymentMethod?.last4 == "4242")
  }

  @Test
  func decodesBillingPaymentMethod() throws {
    let method = try decoder.decode(BillingPaymentMethod.self, from: Data(paymentMethodJSON.utf8))
    #expect(method.id == "pm_1")
    #expect(method.last4 == "4242")
    #expect(method.cardType == "visa")
    #expect(method.status == .active)
    #expect(method.expiryMonth == 12)
  }

  @Test
  func decodesBillingCreditBalance() throws {
    let balance = try decoder.decode(BillingCreditBalance.self, from: Data(creditBalanceJSON.utf8))
    #expect(balance.balance?.amount == 1000)
  }

  @Test
  func decodesBillingCreditLedger() throws {
    let ledger = try decoder.decode(BillingCreditLedger.self, from: Data(creditLedgerJSON.utf8))
    #expect(ledger.id == "led_1")
    #expect(ledger.sourceType == "payment")
    #expect(ledger.sourceId == "pay_1")
    #expect(ledger.amount.currencySymbol == "$")
  }

  @Test
  func rawEnvelopesDecodePlansAndPaymentAttempts() async throws {
    try await assertGET(
      path: "/v1/billing/plans",
      body: JSONEncoder.clerkEncoder.encode(ClerkPaginatedResponse(data: [BillingPlan.mock], totalCount: 2))
    ) {
      let plans = try await Clerk.shared.billing.getPlans()
      #expect(plans.data.count == 1)
      #expect(plans.totalCount == 2)
    }

    try await assertGET(
      path: "/v1/billing/plans/plan_1",
      body: JSONEncoder.clerkEncoder.encode(BillingPlan.mock)
    ) {
      let plan = try await Clerk.shared.billing.getPlan(params: .init(id: "plan_1"))
      #expect(plan.id == BillingPlan.mock.id)
    }

    try await assertGET(
      path: "/v1/me/billing/payment_attempts",
      body: JSONEncoder.clerkEncoder.encode(ClerkPaginatedResponse(data: [BillingPayment.mock], totalCount: 1))
    ) {
      let payments = try await Clerk.shared.billing.getPaymentAttempts(params: .init())
      #expect(payments.data.first?.id == BillingPayment.mock.id)
    }

    try await assertGET(
      path: "/v1/me/billing/payment_attempts/pay_1",
      body: JSONEncoder.clerkEncoder.encode(BillingPayment.mock)
    ) {
      let payment = try await Clerk.shared.billing.getPaymentAttempt(params: .init(id: "pay_1"))
      #expect(payment.id == "pay_1")
    }
  }

  @Test
  func clientResponseEnvelopesDecodeSubscriptionStatementsCreditsAndPaymentMethods() async throws {
    try await assertGET(
      path: "/v1/me/billing/subscription",
      body: encodeClientResponse(BillingSubscription.mock)
    ) {
      let subscription = try await Clerk.shared.billing.getSubscription(params: .init())
      #expect(subscription.id == BillingSubscription.mock.id)
    }

    try await assertGET(
      path: "/v1/me/billing/statements",
      body: encodeClientResponse(ClerkPaginatedResponse(data: [BillingStatement.mock], totalCount: 1))
    ) {
      let statements = try await Clerk.shared.billing.getStatements(params: .init())
      #expect(statements.data.first?.totals.grandTotal.amount == 1000)
    }

    try await assertGET(
      path: "/v1/me/billing/statements/stmt_1",
      body: encodeClientResponse(BillingStatement.mock)
    ) {
      let statement = try await Clerk.shared.billing.getStatement(params: .init(id: "stmt_1"))
      #expect(statement.id == "stmt_1")
    }

    try await assertGET(
      path: "/v1/me/billing/credits",
      body: encodeClientResponse(BillingCreditBalance.mock)
    ) {
      let credits = try await Clerk.shared.billing.getCreditBalance(params: .init())
      #expect(credits.balance?.amount == 1000)
    }

    try await assertGET(
      path: "/v1/me/billing/credits/history",
      body: encodeClientResponse(ClerkPaginatedResponse(data: [BillingCreditLedger.mock], totalCount: 1))
    ) {
      let history = try await Clerk.shared.billing.getCreditHistory(params: .init())
      #expect(history.data.first?.id == "led_1")
    }

    try await assertGET(
      path: "/v1/me/billing/payment_methods",
      body: encodeClientResponse(ClerkPaginatedResponse(data: [BillingPaymentMethod.mock], totalCount: 1))
    ) {
      let methods = try await User.mock.getPaymentMethods()
      #expect(methods.data.first?.last4 == "4242")
    }
  }

  @Test
  func rawPlanBodyDoesNotDecodeClientResponseWrapper() throws {
    let wrapped = try? decoder.decode(
      BillingPlan.self,
      from: try encodeClientResponse(BillingPlan.mock)
    )
    #expect(wrapped == nil)
  }

  @Test
  func wrappedSubscriptionBodyDoesNotDecodeRawResource() throws {
    let raw = try? decoder.decode(
      ClientResponse<BillingSubscription>.self,
      from: try JSONEncoder.clerkEncoder.encode(BillingSubscription.mock)
    )
    #expect(raw == nil)
  }

  private func assertGET(
    path: String,
    body: Data,
    perform: () async throws -> Void
  ) async throws {
    let requestHandled = LockIsolated(false)
    var mock = Mock(
      url: URL(string: mockBaseUrl.absoluteString + path)!,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .get: body,
      ]
    )
    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("_clerk_session_id") == true)
      requestHandled.setValue(true)
    }
    mock.register()
    try await perform()
    #expect(requestHandled.value)
  }

  private func encodeClientResponse(_ response: some Codable & Sendable) throws -> Data {
    try JSONEncoder.clerkEncoder.encode(ClientResponse(response: response, client: .mock))
  }
}

private let moneyJSON = """
{
  "amount": 1000,
  "amount_formatted": "10.00",
  "currency": "USD",
  "currency_symbol": "$"
}
"""

private let featureJSON = """
{
  "object": "feature",
  "id": "feat_1",
  "name": "SSO",
  "description": "Single sign-on",
  "slug": "sso",
  "avatar_url": null
}
"""

private let planJSON = """
{
  "object": "commerce_plan",
  "id": "plan_1",
  "name": "Pro",
  "fee": \(moneyJSON),
  "annual_fee": \(moneyJSON),
  "annual_monthly_fee": \(moneyJSON),
  "description": "Pro plan",
  "is_default": false,
  "is_recurring": true,
  "has_base_fee": true,
  "for_payer_type": "org",
  "publicly_visible": true,
  "slug": "pro",
  "avatar_url": null,
  "features": [\(featureJSON)],
  "unit_prices": [
    {
      "name": "seats",
      "block_size": 1,
      "tiers": [
        {
          "id": "tier_1",
          "starts_at_block": 1,
          "ends_after_block": null,
          "fee_per_block": \(moneyJSON)
        }
      ]
    }
  ],
  "available_prices": [
    {
      "id": "price_1",
      "fee": \(moneyJSON),
      "annual_monthly_fee": \(moneyJSON),
      "is_default": true
    }
  ],
  "free_trial_days": 14,
  "free_trial_enabled": true
}
"""

private let paymentMethodJSON = """
{
  "object": "commerce_payment_method",
  "id": "pm_1",
  "last4": "4242",
  "payment_type": "card",
  "card_type": "visa",
  "is_default": true,
  "is_removable": true,
  "status": "active",
  "wallet_type": null,
  "expiry_year": 2030,
  "expiry_month": 12,
  "created_at": 1700000000000,
  "updated_at": 1700000000000
}
"""

private let subscriptionItemJSON = """
{
  "object": "commerce_subscription_item",
  "id": "si_1",
  "plan": \(planJSON),
  "plan_period": "month",
  "price_id": "price_1",
  "status": "active",
  "created_at": 1700000000000,
  "period_start": 1700000000000,
  "period_end": 1702592000000,
  "canceled_at": null,
  "past_due_at": null,
  "amount": \(moneyJSON),
  "credit": { "amount": \(moneyJSON) },
  "credits": {
    "proration": {
      "amount": \(moneyJSON),
      "cycle_days_remaining": 10,
      "cycle_days_total": 30,
      "cycle_remaining_percent": 0.33
    },
    "payer": {
      "remaining_balance": \(moneyJSON),
      "applied_amount": \(moneyJSON)
    },
    "total": \(moneyJSON)
  },
  "applied_discount": {
    "id": "red_1",
    "subscription_item_id": "si_1",
    "discount_id": "disc_1",
    "name": "Launch",
    "source": "promo_code",
    "promo_code": "LAUNCH",
    "effect": "percentage",
    "percent_off": 20,
    "cycles_remaining": 2,
    "cycles_applied": 1,
    "status": "active",
    "redeemed_at": 1700000000000,
    "redeemed_by": "user_1"
  },
  "seats": {
    "quantity": 5,
    "tiers": [
      {
        "quantity": 5,
        "fee_per_block": \(moneyJSON),
        "total": \(moneyJSON)
      }
    ]
  },
  "is_free_trial": false
}
"""

private let subscriptionJSON = """
{
  "object": "commerce_subscription",
  "id": "sub_1",
  "status": "active",
  "created_at": 1700000000000,
  "active_at": 1700000000000,
  "updated_at": 1700000000000,
  "past_due_at": null,
  "eligible_for_free_trial": false,
  "subscription_items": [\(subscriptionItemJSON)],
  "next_payment": {
    "amount": \(moneyJSON),
    "date": 1702592000000
  }
}
"""

private let paymentJSON = """
{
  "object": "commerce_payment",
  "id": "pay_1",
  "amount": \(moneyJSON),
  "paid_at": 1700000000000,
  "failed_at": null,
  "updated_at": 1700000000000,
  "payment_method": \(paymentMethodJSON),
  "subscription_item": \(subscriptionItemJSON),
  "charge_type": "recurring",
  "status": "paid",
  "totals": {
    "subtotal": \(moneyJSON),
    "grand_total": \(moneyJSON),
    "tax_total": \(moneyJSON),
    "base_fee": \(moneyJSON),
    "per_unit_totals": [
      {
        "name": "seats",
        "block_size": 1,
        "tiers": [
          {
            "quantity": 5,
            "fee_per_block": \(moneyJSON),
            "total": \(moneyJSON)
          }
        ]
      }
    ],
    "discounts": {
      "proration": {
        "amount": \(moneyJSON),
        "cycle_days_passed": 10,
        "cycle_days_total": 30,
        "cycle_passed_percent": 0.33
      },
      "discount": {
        "amount": \(moneyJSON),
        "discount_id": "disc_1",
        "name": "Launch",
        "effect": "percentage",
        "percent_off": 20,
        "promo_code": "LAUNCH",
        "cycles_remaining": 2
      },
      "total": \(moneyJSON)
    }
  }
}
"""

private let statementJSON = """
{
  "object": "commerce_statement",
  "id": "stmt_1",
  "status": "open",
  "timestamp": 1700000000000,
  "totals": {
    "subtotal": \(moneyJSON),
    "grand_total": \(moneyJSON),
    "tax_total": \(moneyJSON)
  },
  "groups": [
    {
      "id": "grp_1",
      "timestamp": 1700000000000,
      "items": [\(paymentJSON)]
    }
  ]
}
"""

private let creditBalanceJSON = """
{
  "object": "commerce_credit_balance",
  "balance": \(moneyJSON)
}
"""

private let creditLedgerJSON = """
{
  "object": "commerce_credit_ledger",
  "id": "led_1",
  "amount": \(moneyJSON),
  "source_type": "payment",
  "source_id": "pay_1",
  "created_at": 1700000000000
}
"""
