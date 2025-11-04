import FactoryTesting
import Foundation
import Mocker
import Testing

@testable import ClerkKit

@MainActor
@Suite
struct SignInTests {

  init() {
    configureClerkForTesting()
  }

  @Test(.container)
  func testCreateWithIdentifier() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["identifier"] == "test@example.com")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignIn.create(strategy: .identifier("test@example.com"))
    #expect(requestHandled.value)
  }
}
