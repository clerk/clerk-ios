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
          "purchase_option_id": null
        },
        {
          "store": "apple",
          "product_id": "com.acme.pro.annual",
          "purchase_option_id": null
        },
        {
          "store": "google",
          "product_id": "acme_pro",
          "purchase_option_id": "monthly"
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
    #expect(plan.storeProducts(for: .apple).map(\.productId) == ["com.acme.pro.monthly", "com.acme.pro.annual"])
    #expect(plan.storeProducts(for: .google).first?.purchaseOptionId == "monthly")
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
    #expect(plan.storeProducts(for: .apple).isEmpty)
  }

  @Test
  func resolveStoreProductReturnsSingleMappedProduct() throws {
    let plan = BillingPlan(
      id: "cplan_123",
      name: "Pro",
      slug: "pro",
      storeProducts: [
        BillingPlanStoreProduct(store: .apple, productId: "com.acme.pro.monthly"),
        BillingPlanStoreProduct(store: .google, productId: "acme_pro", purchaseOptionId: "monthly"),
      ]
    )

    let storeProduct = try plan.resolveStoreProduct(for: .apple)

    #expect(storeProduct.productId == "com.acme.pro.monthly")
  }

  @Test
  func resolveStoreProductSelectsByProductId() throws {
    let plan = BillingPlan.mock

    let storeProduct = try plan.resolveStoreProduct(for: .apple, productId: "com.example.pro.annual")

    #expect(storeProduct.productId == "com.example.pro.annual")
  }

  @Test
  func resolveStoreProductThrowsWhenNoProductIsMapped() {
    let plan = BillingPlan(id: "cplan_123", name: "Free", slug: "free")

    #expect(throws: ClerkBillingError.storeProductNotConfigured(planId: "cplan_123", productId: nil)) {
      try plan.resolveStoreProduct(for: .apple)
    }
  }

  @Test
  func resolveStoreProductThrowsWhenRequestedProductIsNotMapped() {
    let plan = BillingPlan.mock

    #expect(throws: ClerkBillingError.storeProductNotConfigured(planId: plan.id, productId: "com.example.other")) {
      try plan.resolveStoreProduct(for: .apple, productId: "com.example.other")
    }
  }

  @Test
  func resolveStoreProductThrowsWhenMultipleProductsAreMapped() {
    let plan = BillingPlan.mock

    #expect(
      throws: ClerkBillingError.ambiguousStoreProduct(
        planId: plan.id,
        productIds: ["com.example.pro.monthly", "com.example.pro.annual"]
      )
    ) {
      try plan.resolveStoreProduct(for: .apple)
    }
  }

  @Test
  func decodesUnknownStoreValues() throws {
    let json = """
    {
      "store": "amazon",
      "product_id": "acme_pro",
      "purchase_option_id": null
    }
    """

    let storeProduct = try JSONDecoder.clerkDecoder.decode(BillingPlanStoreProduct.self, from: Data(json.utf8))

    #expect(storeProduct.store == .unknown("amazon"))
    #expect(storeProduct.purchaseOptionId == nil)
  }
}
