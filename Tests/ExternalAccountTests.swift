import ConcurrencyExtras
import FactoryKit
import Foundation
import Mocker
import Testing

@testable import ClerkKit

// Any test that accesses Container.shared or performs networking
// should be placed in the serialized tests below

@Suite(.serialized) final class ExternalAccountSerializedTests {

  init() {
    Container.shared.clerk.register { @MainActor in
      let clerk = Clerk()
      clerk.client = .mock
      return clerk
    }
  }

  deinit {
    Container.shared.reset()
  }

  @Test func testDestroyRequest() async throws {
    let requestHandled = LockIsolated(false)
    let externalAccount = ExternalAccount.mockUnverified
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/external_accounts/\(externalAccount.id)")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      requestHandled.setValue(true)
    }
    mock.register()
    try await externalAccount.destroy()
    #expect(requestHandled.value)
  }

}
