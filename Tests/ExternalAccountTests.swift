//
//  ExternalAccountTests.swift
//  Clerk
//
//  Created by Mike Pitre on 2/26/25.
//

import ConcurrencyExtras
import Factory
import Foundation
import Mocker
import Testing

@testable import Clerk

// Any test that accesses Container.shared or performs networking
// should be placed in the serialized tests below

@Suite(.serialized) struct ExternalAccountSerializedTests {
  
  @Test func testReauthorizeThrowsWhenVerificationIsMissing() async throws {
    let service = Container.shared.externalAccountService()
    await #expect(throws: Error.self, performing: {
      _ = try await service.reauthorize("1", nil, false)
    })
  }
  
  @Test func testDestroyRequest() async throws {
    let requestHandled = LockIsolated(false)
    let externalAccount = ExternalAccount.mockUnverified
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/external_accounts/\(externalAccount.id)")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      #expect(request.url!.path() == "/v1/me/external_accounts/\(externalAccount.id)")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      requestHandled.setValue(true)
    }
    mock.register()
    try await externalAccount.destroy()
    #expect(requestHandled.value)
  }
  
}
