@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct PhoneNumberServiceTests {
  private let sessionId = "session_test_123"

  private func makeService(baseURL: URL) -> PhoneNumberService {
    PhoneNumberService(apiClient: createIsolatedMockAPIClient(baseURL: baseURL, protocolClass: IsolatedMockURLProtocol.self))
  }

  @Test
  func testCreate() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/phone_numbers")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<PhoneNumber>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["phone_number"] == "+1234567890")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).create(phoneNumber: "+1234567890", sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func testDelete() async throws {
    let phoneNumber = PhoneNumber.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/phone_numbers/\(phoneNumber.id)")

    try registerIsolatedStub(
      url: originalURL,
      method: .delete,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<DeletedObject>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).delete(phoneNumberId: phoneNumber.id, sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func testPrepareVerification() async throws {
    let phoneNumber = PhoneNumber.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/phone_numbers/\(phoneNumber.id)/prepare_verification")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<PhoneNumber>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "phone_code")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).prepareVerification(phoneNumberId: phoneNumber.id, sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func testAttemptVerification() async throws {
    let phoneNumber = PhoneNumber.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/phone_numbers/\(phoneNumber.id)/attempt_verification")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<PhoneNumber>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["code"] == "123456")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).attemptVerification(
      phoneNumberId: phoneNumber.id,
      code: "123456",
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }

  @Test
  func testMakeDefaultSecondFactor() async throws {
    let phoneNumber = PhoneNumber.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/phone_numbers/\(phoneNumber.id)")

    try registerIsolatedStub(
      url: originalURL,
      method: .patch,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<PhoneNumber>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["default_second_factor"] == "1")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).makeDefaultSecondFactor(phoneNumberId: phoneNumber.id, sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func testSetReservedForSecondFactor() async throws {
    let phoneNumber = PhoneNumber.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/me/phone_numbers/\(phoneNumber.id)")

    try registerIsolatedStub(
      url: originalURL,
      method: .patch,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<PhoneNumber>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["reserved_for_second_factor"] == "1")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).setReservedForSecondFactor(
      phoneNumberId: phoneNumber.id,
      reserved: true,
      sessionId: sessionId
    )
    #expect(requestHandled.value)
  }
}
