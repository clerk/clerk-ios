@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct SignInServiceFirstFactorTests {
  private func makeService(baseURL: URL) -> SignInService {
    SignInService(apiClient: createIsolatedMockAPIClient(baseURL: baseURL, protocolClass: IsolatedMockURLProtocol.self))
  }

  @Test
  func testResetPassword() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins/\(signIn.id)/reset_password")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["password"] == "newPassword123")
      #expect(request.urlEncodedFormBody!["sign_out_of_other_sessions"] == "1")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).resetPassword(
      signInId: signIn.id,
      params: .init(password: "newPassword123", signOutOfOtherSessions: true)
    )
    #expect(requestHandled.value)
  }

  @Test
  func prepareFirstFactorEmailCode() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins/\(signIn.id)/prepare_first_factor")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "email_code")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).prepareFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .emailCode)
    )
    #expect(requestHandled.value)
  }

  @Test
  func prepareFirstFactorPhoneCode() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins/\(signIn.id)/prepare_first_factor")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "phone_code")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).prepareFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .phoneCode)
    )
    #expect(requestHandled.value)
  }

  @Test
  func prepareFirstFactorPasskey() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins/\(signIn.id)/prepare_first_factor")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "passkey")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).prepareFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .passkey)
    )
    #expect(requestHandled.value)
  }

  @Test
  func attemptFirstFactorPassword() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins/\(signIn.id)/attempt_first_factor")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "password")
      #expect(request.urlEncodedFormBody!["password"] == "password123")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).attemptFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .password, password: "password123")
    )
    #expect(requestHandled.value)
  }

  @Test
  func attemptFirstFactorEmailCode() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins/\(signIn.id)/attempt_first_factor")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "email_code")
      #expect(request.urlEncodedFormBody!["code"] == "123456")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).attemptFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .emailCode, code: "123456")
    )
    #expect(requestHandled.value)
  }

  @Test
  func attemptFirstFactorPhoneCode() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins/\(signIn.id)/attempt_first_factor")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "phone_code")
      #expect(request.urlEncodedFormBody!["code"] == "654321")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).attemptFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .phoneCode, code: "654321")
    )
    #expect(requestHandled.value)
  }

  @Test
  func attemptFirstFactorPasskey() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins/\(signIn.id)/attempt_first_factor")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "passkey")
      #expect(request.urlEncodedFormBody!["public_key_credential"] == "mock_credential")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).attemptFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .passkey, publicKeyCredential: "mock_credential")
    )
    #expect(requestHandled.value)
  }

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @Test
  func attemptFirstFactorIdToken() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ins/\(signIn.id)/attempt_first_factor")
    let mockIdToken = "mock_apple_id_token"

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_token_apple")
      #expect(request.urlEncodedFormBody!["token"] == mockIdToken)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).attemptFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .idToken(.apple), token: mockIdToken)
    )
    #expect(requestHandled.value)
  }
  #endif
}
