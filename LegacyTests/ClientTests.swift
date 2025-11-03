import ConcurrencyExtras
import FactoryKit
import Foundation
import Mocker
import Testing

@testable import ClerkKit

// Any test that accesses Container.shared or performs networking
// should be placed in the serialized tests below

struct ClientTests {

  @Test func testActiveSessions() {
  let client = Client(
    id: "1",
    signIn: nil,
    signUp: nil,
    sessions: [.mock, .mock, .mockExpired],
    lastActiveSessionId: "1",
    updatedAt: Date(timeIntervalSinceReferenceDate: 1234567890)
  )

  #expect(client.activeSessions.count == 2)
  }

}

@Suite(.serialized) struct ClientSerializedTests {

  init() {
  TestContainer.reset()
  }

  @Test func testGet() async throws {
  let requestHandled = LockIsolated(false)
  let originalUrl = mockBaseUrl.appending(path: "/v1/client")
  var mock = Mock(
    url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
    data: [
    .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Client>(response: .mock, client: .mock))
    ])
  mock.onRequestHandler = OnRequestHandler { request in
    #expect(request.httpMethod == "GET")
    requestHandled.setValue(true)
  }
  mock.register()
  try await Client.get()
  #expect(requestHandled.value)
  }
}
