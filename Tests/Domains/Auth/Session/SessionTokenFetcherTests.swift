import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct SessionTokenFetcherTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func fetchToken() async throws {
    let session = Session.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/tokens")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(TokenResource.mock),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await SessionTokenFetcher.shared.fetchToken(session, options: .init(skipCache: true))
    #expect(requestHandled.value)
  }

  @Test
  func fetchTokenWithTemplate() async throws {
    let session = Session.mock
    let template = "firebase"
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(session.id)/tokens/\(template)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(TokenResource.mock),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await SessionTokenFetcher.shared.fetchToken(session, options: .init(template: template, skipCache: true))
    #expect(requestHandled.value)
  }
}
