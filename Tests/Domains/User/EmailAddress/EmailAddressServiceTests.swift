@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct EmailAddressServiceTests {
  private let sessionId = "session_test_123"

  private func makeService(baseURL: URL) -> EmailAddressService {
    EmailAddressService(apiClient: createIsolatedMockAPIClient(baseURL: baseURL, protocolClass: IsolatedMockURLProtocol.self))
  }

  @Test
  func testCreate() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/email_addresses")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<EmailAddress>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["email_address"] == "test@example.com")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).create(email: "test@example.com", sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func testPrepareVerification() async throws {
    let emailAddress = EmailAddress.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/email_addresses/\(emailAddress.id)/prepare_verification")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<EmailAddress>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "email_code")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).prepareVerification(
      emailAddressId: emailAddress.id,
      strategy: .emailCode,
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func testAttemptVerification() async throws {
    let emailAddress = EmailAddress.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/email_addresses/\(emailAddress.id)/attempt_verification")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<EmailAddress>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["code"] == "123456")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).attemptVerification(
      emailAddressId: emailAddress.id,
      strategy: .emailCode(code: "123456"),
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func testDestroy() async throws {
    let emailAddress = EmailAddress.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/email_addresses/\(emailAddress.id)")

    try registerIsolatedStub(
      url: originalURL,
      method: .delete,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).destroy(emailAddressId: emailAddress.id, sessionId: sessionId)
    #expect(requestHandled.value)
  }
}
