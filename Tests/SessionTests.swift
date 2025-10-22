import ConcurrencyExtras
import FactoryKit
import Foundation
import Mocker
import Testing

@testable import ClerkKit

// Any test that accesses Container.shared or performs networking
// should be placed in the serialized tests below

@Suite struct SessionTests {

  @Test func testTokenCacheKeyWithoutTemplate() {
    let session = Session.mock
    #expect(session.tokenCacheKey(template: nil) == session.id)
  }

  @Test func testTokenCacheKeyWithTemplate() {
    let session = Session.mock
    #expect(session.tokenCacheKey(template: "supabase") == "\(session.id)-supabase")
  }

  @Test func testGetTokenOptionsExpirationBuffer() {
    let options = Session.GetTokenOptions(expirationBuffer: 120)
    #expect(options.expirationBuffer == 60)
  }

  @Test func testGetTokenOptionsDefaults() {
    let options = Session.GetTokenOptions()
    #expect(options.template == nil)
    #expect(options.expirationBuffer == 10)
    #expect(options.skipCache == false)
  }

  @Test func testGetTokenOptionsCustomValues() {
    let options = Session.GetTokenOptions(
      template: "firebase",
      expirationBuffer: 30,
      skipCache: true
    )
    #expect(options.template == "firebase")
    #expect(options.expirationBuffer == 30)
    #expect(options.skipCache == true)
  }
}

@Suite(.serialized) final class SessionSerializedTests {

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

  @MainActor
  @Test func testRevokeRequest() async throws {
    let requestHandled = LockIsolated(false)
    let session = Session.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/sessions/\(session.id)/revoke")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Session>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      requestHandled.setValue(true)
    }
    mock.register()
    try await session.revoke()
    #expect(requestHandled.value)
  }

  @MainActor
  @Test func testFetchTokenRequestWithoutTemplate() async throws {
    let requestHandled = LockIsolated(false)
    let session = Session.mock
    let originalUrl = mockBaseUrl.appending(path: "v1/client/sessions/\(session.id)/tokens")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(TokenResource.mock)
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()
    try await session.getToken()
    #expect(requestHandled.value)
  }

  @MainActor
  @Test func testFetchTokenRequestWithTemplate() async throws {
    let requestHandled = LockIsolated(false)
    let session = Session.mock
    let originalUrl = mockBaseUrl.appending(path: "v1/client/sessions/\(session.id)/tokens/supabase")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(TokenResource.mock)
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()
    try await session.getToken(.init(template: "supabase"))
    #expect(requestHandled.value)
  }

  @MainActor
  @Test func testFetchTokenStoresTokenInCache() async throws {
    let token = try await Session.mock.getToken()
    #expect(token == .mock)

    let cacheKey = Session.mock.tokenCacheKey(template: nil)
    let tokenFromCache = await SessionTokensCache.shared.getToken(cacheKey: cacheKey)
    #expect(tokenFromCache == .mock)
  }
}
