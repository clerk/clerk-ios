@testable import ClerkKit
import Foundation
import Testing

struct BillingSubscriptionItemTests {
  @Test
  func decodesStoreManagedSubscriptionItem() throws {
    let json = """
    {
      "id": "csi_123",
      "status": "active",
      "plan": {
        "id": "cplan_123",
        "name": "Pro",
        "slug": "pro"
      },
      "plan_id": "cplan_123",
      "plan_period": "month",
      "price_id": "cprice_123",
      "managed_by": "apple",
      "store_product_id": "com.acme.pro.monthly",
      "created_at": 1717200000000,
      "period_start": 1717200000000,
      "period_end": 1719878400000,
      "canceled_at": null,
      "past_due_at": null,
      "is_free_trial": false
    }
    """

    let item = try JSONDecoder.clerkDecoder.decode(BillingSubscriptionItem.self, from: Data(json.utf8))

    #expect(item.id == "csi_123")
    #expect(item.status == .active)
    #expect(item.plan?.id == "cplan_123")
    #expect(item.planId == "cplan_123")
    #expect(item.planPeriod == .month)
    #expect(item.priceId == "cprice_123")
    #expect(item.managedBy == .apple)
    #expect(item.isStoreManaged)
    #expect(item.storeProductId == "com.acme.pro.monthly")
    #expect(item.periodStart == Date(timeIntervalSince1970: 1_717_200_000))
    #expect(item.periodEnd == Date(timeIntervalSince1970: 1_719_878_400))
    #expect(item.canceledAt == nil)
    #expect(item.isFreeTrial == false)
  }

  @Test
  func managedByDefaultsToClerkWhenMissing() throws {
    let json = """
    {
      "id": "csi_123",
      "status": "active"
    }
    """

    let item = try JSONDecoder.clerkDecoder.decode(BillingSubscriptionItem.self, from: Data(json.utf8))

    #expect(item.managedBy == .clerk)
    #expect(!item.isStoreManaged)
  }

  @Test
  func decodesCanceledStatusAndCanceledAt() throws {
    let json = """
    {
      "id": "csi_123",
      "status": "canceled",
      "managed_by": "google",
      "canceled_at": 1717200000000
    }
    """

    let item = try JSONDecoder.clerkDecoder.decode(BillingSubscriptionItem.self, from: Data(json.utf8))

    #expect(item.status == .canceled)
    #expect(item.managedBy == .google)
    #expect(item.isStoreManaged)
    #expect(item.canceledAt == Date(timeIntervalSince1970: 1_717_200_000))
  }

  @Test
  func decodesUnknownStatusAndManagedBy() throws {
    let json = """
    {
      "id": "csi_123",
      "status": "paused",
      "managed_by": "amazon"
    }
    """

    let item = try JSONDecoder.clerkDecoder.decode(BillingSubscriptionItem.self, from: Data(json.utf8))

    #expect(item.status == .unknown("paused"))
    #expect(item.managedBy == .unknown("amazon"))
    #expect(!item.isStoreManaged)
  }
}
