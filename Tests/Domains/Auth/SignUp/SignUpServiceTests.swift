@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.tags(.networking, .unit))
struct SignUpServiceTests {
  private let redirectUrl = "clerk://callback"

  private func makeService(baseURL: URL) -> SignUpService {
    SignUpService(apiClient: createIsolatedMockAPIClient(baseURL: baseURL, protocolClass: IsolatedMockURLProtocol.self))
  }

  @Test
  func createWithStandard() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ups")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["email_address"] == "test@example.com")
      #expect(request.urlEncodedFormBody!["password"] == "password123")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).create(params: .init(
      emailAddress: "test@example.com",
      password: "password123"
    ))
    #expect(requestHandled.value)
  }

  @Test
  func createWithOAuth() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ups")
    let expectedRedirectUrl = redirectUrl

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_google")
      #expect(request.urlEncodedFormBody!["redirect_url"] == expectedRedirectUrl)
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).create(params: .init(
      strategy: .oauth(.google),
      redirectUrl: expectedRedirectUrl
    ))
    #expect(requestHandled.value)
  }

  @Test
  func createWithEnterpriseSSO() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ups")
    let expectedRedirectUrl = redirectUrl

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "enterprise_sso")
      #expect(request.urlEncodedFormBody!["email_address"] == "user@enterprise.com")
      #expect(request.urlEncodedFormBody!["redirect_url"] == expectedRedirectUrl)
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).create(params: .init(
      emailAddress: "user@enterprise.com",
      strategy: .enterpriseSSO,
      redirectUrl: expectedRedirectUrl
    ))
    #expect(requestHandled.value)
  }

  @Test
  func createWithIdToken() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ups")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_token_apple")
      #expect(request.urlEncodedFormBody!["token"] == "mock_id_token")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).create(params: .init(
      strategy: .idToken(.apple),
      token: "mock_id_token"
    ))
    #expect(requestHandled.value)
  }

  @Test
  func createWithTicket() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ups")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "ticket")
      #expect(request.urlEncodedFormBody!["ticket"] == "mock_ticket_value")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).create(params: .init(
      ticket: "mock_ticket_value",
      strategy: .ticket
    ))
    #expect(requestHandled.value)
  }

  @Test
  func createWithTransfer() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ups")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["transfer"] == "1")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).create(params: .init(transfer: true))
    #expect(requestHandled.value)
  }

  @Test
  func createWithNone() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ups")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).create(params: .init())
    #expect(requestHandled.value)
  }

  @Test
  func createWithUnsafeMetadataObjectEncodesMetadataAsJSONString() async throws {
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ups")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["unsafe_metadata"] == "{\"token\":\"some-value\"}")
      #expect(request.urlEncodedFormBody!["unsafe_metadata[token]"] == nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).create(
      params: .init(unsafeMetadata: ["token": "some-value"])
    )
    #expect(requestHandled.value)
  }

  @Test
  func testUpdate() async throws {
    let signUp = SignUp.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ups/\(signUp.id)")

    try registerIsolatedStub(
      url: originalURL,
      method: .patch,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["first_name"] == "John")
      #expect(request.urlEncodedFormBody!["last_name"] == "Doe")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).update(
      signUpId: signUp.id,
      params: .init(firstName: "John", lastName: "Doe")
    )
    #expect(requestHandled.value)
  }

  @Test
  func updateWithUnsafeMetadataObjectEncodesMetadataAsJSONString() async throws {
    let signUp = SignUp.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ups/\(signUp.id)")

    try registerIsolatedStub(
      url: originalURL,
      method: .patch,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["unsafe_metadata"] == "{\"token\":\"some-value\"}")
      #expect(request.urlEncodedFormBody!["unsafe_metadata[token]"] == nil)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).update(
      signUpId: signUp.id,
      params: .init(unsafeMetadata: ["token": "some-value"])
    )
    #expect(requestHandled.value)
  }

  @Test
  func prepareVerificationEmailCode() async throws {
    let signUp = SignUp.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ups/\(signUp.id)/prepare_verification")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "email_code")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).prepareVerification(
      signUpId: signUp.id,
      params: .init(strategy: .emailCode)
    )
    #expect(requestHandled.value)
  }

  @Test
  func prepareVerificationPhoneCode() async throws {
    let signUp = SignUp.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ups/\(signUp.id)/prepare_verification")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "phone_code")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).prepareVerification(
      signUpId: signUp.id,
      params: .init(strategy: .phoneCode)
    )
    #expect(requestHandled.value)
  }

  @Test
  func attemptVerificationEmailCode() async throws {
    let signUp = SignUp.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ups/\(signUp.id)/attempt_verification")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "email_code")
      #expect(request.urlEncodedFormBody!["code"] == "123456")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).attemptVerification(
      signUpId: signUp.id,
      params: .init(strategy: .emailCode, code: "123456")
    )
    #expect(requestHandled.value)
  }

  @Test
  func attemptVerificationPhoneCode() async throws {
    let signUp = SignUp.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ups/\(signUp.id)/attempt_verification")

    try registerIsolatedStub(
      url: originalURL,
      method: .post,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "phone_code")
      #expect(request.urlEncodedFormBody!["code"] == "654321")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).attemptVerification(
      signUpId: signUp.id,
      params: .init(strategy: .phoneCode, code: "654321")
    )
    #expect(requestHandled.value)
  }

  @Test
  func testGet() async throws {
    let signUp = SignUp.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ups/\(signUp.id)")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).get(
      signUpId: signUp.id,
      params: .init()
    )
    #expect(requestHandled.value)
  }

  @Test
  func getWithRotatingTokenNonce() async throws {
    let signUp = SignUp.mock
    let requestHandled = LockIsolated(false)
    let baseURL = makeIsolatedMockBaseURL()
    let originalURL = baseURL.appendingPathComponent("v1/client/sign_ups/\(signUp.id)")

    try registerIsolatedStub(
      url: originalURL,
      method: .get,
      data: JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
    ) { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("rotating_token_nonce=test_nonce") == true)
      requestHandled.setValue(true)
    }
    defer { removeIsolatedStub(for: originalURL) }

    _ = try await makeService(baseURL: baseURL).get(
      signUpId: signUp.id,
      params: .init(rotatingTokenNonce: "test_nonce")
    )
    #expect(requestHandled.value)
  }
}
