import FactoryTesting
import Foundation
import Mocker
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct PasskeyTests {

  init() {
    configureClerkForTesting()
  }

  @Test(.container)
  func testCreate() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/passkeys")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Passkey>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Passkey.create()
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testUpdate() async throws {
    let passkey = Passkey.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/passkeys/\(passkey.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Passkey>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["name"] == "New Name")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await passkey.update(name: "New Name")
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testAttemptVerification() async throws {
    let passkey = Passkey.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/passkeys/\(passkey.id)/attempt_verification")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<Passkey>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "passkey")
      #expect(request.urlEncodedFormBody!["public_key_credential"] == "mock_credential")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await passkey.attemptVerification(credential: "mock_credential")
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testDelete() async throws {
    let passkey = Passkey.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/me/passkeys/\(passkey.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await passkey.delete()
    #expect(requestHandled.value)
  }
}
