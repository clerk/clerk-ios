import ConcurrencyExtras
import FactoryKit
import Foundation
import Mocker
import Testing

@testable import ClerkKit

@Suite(.serialized) final class SerializedPasskeyTests {

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

  @Test func testUpdate() async throws {
    let requestHandled = LockIsolated(false)
    let passkey = Passkey.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/passkeys/\(passkey.id)")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Passkey>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      #expect(request.urlEncodedFormBody["name"] == "new")
      requestHandled.setValue(true)
    }
    mock.register()
    try await passkey.update(name: "new")
    #expect(requestHandled.value)
  }

  @Test func testAttemptVerification() async throws {
    let requestHandled = LockIsolated(false)
    let passkey = Passkey.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/passkeys/\(passkey.id)/attempt_verification")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Passkey>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url!.query()!.contains("_clerk_session_id"))
      #expect(request.urlEncodedFormBody["strategy"] == "passkey")
      #expect(request.urlEncodedFormBody["public_key_credential"] == "credential")
      requestHandled.setValue(true)
    }
    mock.register()
    try await passkey.attemptVerification(credential: "credential")
    #expect(requestHandled.value)
  }

  @Test func testDelete() async throws {
    let requestHandled = LockIsolated(false)
    let passkey = Passkey.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/me/passkeys/\(passkey.id)")
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
    try await passkey.delete()
    #expect(requestHandled.value)
  }

}
