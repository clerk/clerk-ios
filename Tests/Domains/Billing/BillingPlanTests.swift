@testable import ClerkKit
import Foundation
import Testing

struct BillingPlanTests {
  @Test
  func decodesPlanWithStoreProducts() throws {
    let json = """
    {
      "id": "cplan_123",
      "name": "Pro",
      "slug": "pro",
      "description": "The Pro plan.",
      "fee": {
        "amount": 999,
        "amount_formatted": "9.99",
        "currency": "USD",
        "currency_symbol": "$"
      },
      "annual_fee": {
        "amount": 9999,
        "amount_formatted": "99.99",
        "currency": "USD",
        "currency_symbol": "$"
      },
      "annual_monthly_fee": null,
      "is_default": false,
      "is_recurring": true,
      "has_base_fee": true,
      "for_payer_type": "user",
      "publicly_visible": true,
      "avatar_url": null,
      "free_trial_days": null,
      "free_trial_enabled": false,
      "features": [
        {
          "id": "feature_1",
          "name": "Unlimited Widgets",
          "slug": "unlimited-widgets",
          "description": null,
          "avatar_url": null
        }
      ],
      "store_products": [
        {
          "store": "apple",
          "product_id": "com.acme.pro.monthly",
          "period": "month"
        },
        {
          "store": "apple",
          "product_id": "com.acme.pro.annual",
          "period": "annual"
        },
        {
          "store": "google",
          "product_id": "acme_pro_monthly",
          "period": "month"
        }
      ]
    }
    """

    let plan = try JSONDecoder.clerkDecoder.decode(BillingPlan.self, from: Data(json.utf8))

    #expect(plan.id == "cplan_123")
    #expect(plan.name == "Pro")
    #expect(plan.slug == "pro")
    #expect(plan.fee?.amount == 999)
    #expect(plan.fee?.amountFormatted == "9.99")
    #expect(plan.fee?.currency == "USD")
    #expect(plan.annualFee?.amount == 9999)
    #expect(plan.annualMonthlyFee == nil)
    #expect(plan.isRecurring == true)
    #expect(plan.forPayerType == "user")
    #expect(plan.features?.count == 1)
    #expect(plan.features?.first?.slug == "unlimited-widgets")
    #expect(plan.storeProducts?.count == 3)
  }

  @Test
  func decodesPlanWithoutStoreProducts() throws {
    let json = """
    {
      "id": "cplan_123",
      "name": "Free",
      "slug": "free"
    }
    """

    let plan = try JSONDecoder.clerkDecoder.decode(BillingPlan.self, from: Data(json.utf8))

    #expect(plan.id == "cplan_123")
    #expect(plan.storeProducts == nil)
    #expect(plan.storeProductId(for: .apple, period: .month) == nil)
  }

  @Test
  func storeProductLookupMatchesStoreAndPeriod() {
    let plan = BillingPlan.mock

    #expect(plan.storeProductId(for: .apple, period: .month) == "com.example.pro.monthly")
    #expect(plan.storeProductId(for: .apple, period: .annual) == "com.example.pro.annual")
    #expect(plan.storeProductId(for: .google, period: .month) == nil)
  }

  @Test
  func decodesUnknownStoreAndPeriodValues() throws {
    let json = """
    {
      "store": "amazon",
      "product_id": "acme_pro",
      "period": "week"
    }
    """

    let storeProduct = try JSONDecoder.clerkDecoder.decode(BillingPlanStoreProduct.self, from: Data(json.utf8))

    #expect(storeProduct.store == .unknown("amazon"))
    #expect(storeProduct.period == .unknown("week"))
  }
}
