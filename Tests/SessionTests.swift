import FactoryTesting
import Foundation
import Mocker
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct SessionTests {

  init() {
    configureClerkForTesting()
  }

  @Test(.container)
  func testRevoke() async throws {
    let session = Session.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/sessions/\(session.id)/revoke")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Session>(response: session, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await session.revoke()
    #expect(requestHandled.value)
  }
}
