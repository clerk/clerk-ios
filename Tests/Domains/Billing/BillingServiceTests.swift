@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct BillingServiceTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func getPlansRequestsUserPlans() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/billing/plans")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(ClerkPaginatedResponse<BillingPlan>(data: [.mock], totalCount: 1)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("payer_type=user") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    let plans = try await Clerk.shared.dependencies.billingService.getPlans()

    #expect(requestHandled.value)
    #expect(plans.data.count == 1)
    #expect(plans.data.first?.id == BillingPlan.mock.id)
    #expect(plans.data.first?.storeProductId(for: .apple, period: .month) == "com.example.pro.monthly")
  }

  @Test
  func getSubscriptionItemsRequestsUserItems() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/billing/subscription_items")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(
          ClientResponse<ClerkPaginatedResponse<BillingSubscriptionItem>>(
            response: ClerkPaginatedResponse(data: [.mock], totalCount: 1),
            client: nil
          )
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    mock.register()

    let items = try await Clerk.shared.dependencies.billingService.getSubscriptionItems()

    #expect(requestHandled.value)
    #expect(items.data.count == 1)
    #expect(items.data.first?.id == BillingSubscriptionItem.mock.id)
    #expect(items.data.first?.managedBy == .apple)
  }

  @Test
  func createStorePurchaseSendsStoreAndPayload() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/billing/store_purchases")!

    var mock = try Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          ClientResponse<BillingSubscriptionItem>(response: .mock, client: nil)
        ),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { @Sendable request in
      #expect(request.httpMethod == "POST")
      let body = request.urlEncodedFormBody
      #expect(body?["store"] == "apple")
      #expect(body?["payload"] == "signed-jws-transaction")
      requestHandled.setValue(true)
    }
    mock.register()

    let item = try await Clerk.shared.dependencies.billingService.createStorePurchase(
      store: .apple,
      payload: "signed-jws-transaction"
    )

    #expect(requestHandled.value)
    #expect(item.id == BillingSubscriptionItem.mock.id)
  }

  @Test
  func createStorePurchaseMapsAlreadySubscribedError() async throws {
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/billing/store_purchases")!

    let errorJSON = """
    {
      "errors": [
        {
          "code": "already_subscribed",
          "message": "Already subscribed",
          "long_message": "The user already has an active subscription to this plan.",
          "meta": {
            "already_subscribed_via": "stripe"
          }
        }
      ],
      "clerk_trace_id": "trace_1"
    }
    """

    let mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 422,
      data: [
        .post: Data(errorJSON.utf8),
      ]
    )
    mock.register()

    await #expect(throws: ClerkBillingError.alreadySubscribed(via: "stripe")) {
      try await Clerk.shared.dependencies.billingService.createStorePurchase(
        store: .apple,
        payload: "signed-jws-transaction"
      )
    }
  }

  @Test
  func createStorePurchaseRethrowsOtherAPIErrors() async throws {
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/billing/store_purchases")!

    let errorJSON = """
    {
      "errors": [
        {
          "code": "store_transaction_invalid",
          "message": "Invalid transaction"
        }
      ],
      "clerk_trace_id": "trace_1"
    }
    """

    let mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 422,
      data: [
        .post: Data(errorJSON.utf8),
      ]
    )
    mock.register()

    do {
      _ = try await Clerk.shared.dependencies.billingService.createStorePurchase(
        store: .apple,
        payload: "signed-jws-transaction"
      )
      Issue.record("Expected an error to be thrown")
    } catch let error as ClerkAPIError {
      #expect(error.code == "store_transaction_invalid")
    }
  }
}
