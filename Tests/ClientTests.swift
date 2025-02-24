import Testing
import Foundation
import Mocker

@testable import Clerk
@testable import Factory
@testable import Get

@Suite(.serialized) struct ClientTests {
  
  init() {
    Container.shared.reset()
  }
  
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
  
  @Test func testClientGet() async throws {
    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/client")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Client>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url!.path() == "/v1/client")
      requestHandled.setValue(true)
    }
    mock.register()
    try await Client.get()
    #expect(requestHandled.value)
  }
}
