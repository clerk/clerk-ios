@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct PasskeyServiceTests {
  private let sessionId = "session_test_123"

  private func makeService(baseURL: URL) -> PasskeyService {
    PasskeyService(apiClient: createIsolatedMockAPIClient(baseURL: baseURL, protocolClass: IsolatedMockURLProtocol.self))
  }

  @Test
  func testCreate() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/passkeys")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<Passkey>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).create(sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func testUpdate() async throws {
    let passkey = Passkey.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/passkeys/\(passkey.id)")

    try registerIsolatedStub(
      url: originalURL,
      method: .patch,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<Passkey>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["name"] == "New Name")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).update(passkeyId: passkey.id, name: "New Name", sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func testAttemptVerification() async throws {
    let passkey = Passkey.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/passkeys/\(passkey.id)/attempt_verification")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<Passkey>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "passkey")
      #expect(request.urlEncodedFormBody!["public_key_credential"] == "mock_credential")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).attemptVerification(
      passkeyId: passkey.id,
      credential: "mock_credential",
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func testDelete() async throws {
    let passkey = Passkey.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/passkeys/\(passkey.id)")

    try registerIsolatedStub(
      url: originalURL,
      method: .delete,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).delete(passkeyId: passkey.id, sessionId: sessionId)
    #expect(requestHandled.value)
  }
}
