import ConcurrencyExtras
import Factory
import Foundation
import Mocker
import Testing

@testable import Clerk

@Suite(.serialized) struct SignInSerializedTests {
  
  init() {
    Container.shared.reset()
  }
  
  @Test func testGet() async throws {
    let requestHandled = LockIsolated(false)
    let signIn = SignIn.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins/\(signIn.id)")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await signIn.get()
    #expect(requestHandled.value)
  }
  
  @Test func testGetWithRotatingTokenNonce() async throws {
    let requestHandled = LockIsolated(false)
    let signIn = SignIn.mock
    let nonce = UUID().uuidString
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins/\(signIn.id)")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url!.query()!.contains("rotating_token_nonce=\(nonce)"))
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await signIn.get(rotatingTokenNonce: nonce)
    #expect(requestHandled.value)
  }
  
}
