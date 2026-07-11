@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

/// Tests for the client-side purchase flow in `Billing`.
///
/// The purchase preflight runs before the App Store payment sheet opens: an active
/// subscription managed by another payment processor fails fast with
/// `ClerkBillingError.alreadySubscribed`, while an active App Store-managed subscription
/// is not a conflict (purchasing another product in the same subscription group is a
/// plan change) and the flow proceeds to StoreKit.
@MainActor
@Suite(.serialized)
struct BillingPurchaseTests {
  init() {
    configureClerkForTesting()
  }

  private func makeBilling(preflight: @escaping (BillingStore, String, String?) async throws -> BillingStorePurchasePreflight) -> Billing {
    let mockService = MockBillingService()
    mockService.preflightStorePurchaseHandler = preflight
    return Billing(billingService: mockService)
  }

  @Test
  func purchaseFailsFastWhenActiveSubscriptionIsStripeManaged() async throws {
    Clerk.shared.client = .mock

    let preflightCalled = LockIsolated(false)
    let billing = makeBilling { store, productId, purchaseOptionId in
      preflightCalled.setValue(true)
      #expect(store == .apple)
      #expect(productId == "com.example.pro.monthly")
      #expect(purchaseOptionId == nil)
      throw ClerkBillingError.alreadySubscribed(via: "stripe")
    }

    await #expect(throws: ClerkBillingError.alreadySubscribed(via: "stripe")) {
      try await billing.purchase(plan: .mock, productId: "com.example.pro.monthly")
    }
    #expect(preflightCalled.value)
  }

  @Test
  func purchaseFailsFastWhenActiveSubscriptionIsGoogleManaged() async throws {
    Clerk.shared.client = .mock

    let billing = makeBilling { _, _, _ in
      throw ClerkBillingError.alreadySubscribed(via: "google")
    }

    await #expect(throws: ClerkBillingError.alreadySubscribed(via: "google")) {
      try await billing.purchase(plan: .mock, productId: "com.example.pro.monthly")
    }
  }

  @Test
  func purchaseProceedsToStoreKitWhenPreflightAllows() async throws {
    Clerk.shared.client = .mock

    // An active App Store-managed subscription is allowed by the preflight: purchasing
    // another product in the same subscription group is a plan change.
    let preflightCalled = LockIsolated(false)
    let billing = makeBilling { _, _, _ in
      preflightCalled.setValue(true)
      return BillingStorePurchasePreflight(allowed: true)
    }

    do {
      _ = try await billing.purchase(plan: .mock, productId: "com.example.pro.monthly")
      Issue.record("Expected the purchase to fail loading products in the test environment")
    } catch {
      // The flow proceeded past the preflight into StoreKit, which cannot load App Store
      // products in the unit test environment. The important part is that no
      // already-subscribed error blocked the plan change.
      #expect((error as? ClerkBillingError) != ClerkBillingError.alreadySubscribed(via: "apple"))
    }
    #expect(preflightCalled.value)
  }

  @Test
  func purchaseRequiresSignedInUser() async throws {
    Clerk.shared.client = .mockSignedOut

    let preflightCalled = LockIsolated(false)
    let billing = makeBilling { _, _, _ in
      preflightCalled.setValue(true)
      return BillingStorePurchasePreflight(allowed: true)
    }

    await #expect(throws: ClerkBillingError.notSignedIn) {
      try await billing.purchase(plan: .mock)
    }
    #expect(!preflightCalled.value)
  }
}
