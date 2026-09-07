@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct BillingTests {
  init() {
    configureClerkForTesting()
  }

  private let decoder = JSONDecoder.clerkDecoder

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
    #expect(plan.features?.map(\.slug) == ["sso"])
    #expect(plan.unitPrices?.first?.name == "seats")
    #expect(plan.unitPrices?.first?.tiers.first?.startsAtBlock == 1)
    #expect(plan.availablePrices?.first?.id == "price_1")
    #expect(plan.freeTrialDays == 14)
    #expect(plan.freeTrialEnabled == true)
  }

  @Test
  func billingPlanUnitPriceTierRequiresId() {
    let stripped = planJSON.replacingOccurrences(of: "\"id\": \"tier_1\",", with: "")
    #expect(throws: DecodingError.self) {
      try decoder.decode(BillingPlan.self, from: Data(stripped.utf8))
    }
  }

  @Test
  func decodesBillingPlanDefaultsMissingFeaturesAndTrial() throws {
    let json = Data(
      """
      {
        "object": "commerce_plan",
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
    #expect(plan.features == nil)
    #expect(plan.freeTrialDays == nil)
    #expect(plan.freeTrialEnabled == nil)
  }

  @Test
  func decodesBillingSubscriptionWithSeatsCreditsAndDiscounts() throws {
    let subscription = try decoder.decode(BillingSubscription.self, from: Data(subscriptionJSON.utf8))
    let item = try #require(subscription.subscriptionItems?.first)
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
  func billingSubscriptionRequiresActiveAt() {
    let json = subscriptionJSON.replacingOccurrences(of: "\"active_at\": 1700000000000", with: "\"active_at\": null")
    #expect(throws: DecodingError.self) {
      try decoder.decode(BillingSubscription.self, from: Data(json.utf8))
    }
  }

  @Test
  func decodesBillingStatementWithTotals() throws {
    let statement = try decoder.decode(BillingStatement.self, from: Data(statementJSON.utf8))
    #expect(statement.status == .open)
    #expect(statement.totals.subtotal.amount == 1000)
    #expect(statement.totals.grandTotal.amountFormatted == "10.00")
    #expect(statement.totals.taxTotal.currency == "USD")
    #expect(statement.groups.first?.items.first?.id == "pay_1")
    #expect(statement.groups.first?.id == "grp_1")
  }

  @Test
  func billingStatementGroupRequiresId() {
    let json = """
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
          "timestamp": 1700000000000,
          "items": [\(paymentJSON)]
        }
      ]
    }
    """
    #expect(throws: DecodingError.self) {
      try decoder.decode(BillingStatement.self, from: Data(json.utf8))
    }
  }

  @Test
  func billingPaymentRequiresNestedSubscriptionItemTimestamps() {
    let stripped = paymentJSON
      .replacingOccurrences(of: "\"price_id\": \"price_1\",", with: "")
      .replacingOccurrences(of: "\"created_at\": 1700000000000,", with: "")
      .replacingOccurrences(of: "\"period_start\": 1700000000000,", with: "")
    #expect(throws: DecodingError.self) {
      try decoder.decode(BillingPayment.self, from: Data(stripped.utf8))
    }
  }

  @Test
  func decodesBillingPaymentWhenNestedSubscriptionItemSendsEpochTimestamps() throws {
    let epoch = paymentJSON
      .replacingOccurrences(of: "\"created_at\": 1700000000000,", with: "\"created_at\": 0,")
      .replacingOccurrences(of: "\"period_start\": 1700000000000,", with: "\"period_start\": 0,")
    let payment = try decoder.decode(BillingPayment.self, from: Data(epoch.utf8))
    #expect(payment.subscriptionItem.createdAt == Date(timeIntervalSince1970: 0))
    #expect(payment.subscriptionItem.periodStart == 0)
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
  func decodesUnknownBillingEnumValuesWithoutFailingTheResource() throws {
    #expect(BillingSubscriptionStatus(rawValue: "canceled") == .unknown("canceled"))
    #expect(BillingSubscriptionStatus(rawValue: "canceled").rawValue == "canceled")
    #expect(BillingPaymentChargeType(rawValue: "price_transition") == .unknown("price_transition"))
    #expect(BillingPaymentChargeType(rawValue: "future_charge").rawValue == "future_charge")

    let unknownPaymentJSON = paymentJSON
      .replacingOccurrences(of: "\"charge_type\": \"recurring\"", with: "\"charge_type\": \"price_transition\"")
      .replacingOccurrences(of: "\"status\": \"paid\"", with: "\"status\": \"settled\"")
    let payment = try decoder.decode(BillingPayment.self, from: Data(unknownPaymentJSON.utf8))
    #expect(payment.chargeType == .unknown("price_transition"))
    #expect(payment.status == .unknown("settled"))
    #expect(payment.id == "pay_1")
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
          "object": "commerce_plan_unit_price_tier",
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
      "object": "commerce_price",
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
      "cycle_remaining_percent": 33
    },
    "payer": {
      "remaining_balance": \(moneyJSON),
      "applied_amount": \(moneyJSON)
    },
    "total": \(moneyJSON)
  },
  "applied_discount": {
    "object": "commerce_discount_redemption",
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
        "cycle_passed_percent": 33
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
      "object": "commerce_statement_group",
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
