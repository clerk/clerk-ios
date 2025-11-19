import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct SignUpTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func createWithStandard() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ups")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["email_address"] == "test@example.com")
      #expect(request.urlEncodedFormBody!["password"] == "password123")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignUp.create(strategy: .standard(emailAddress: "test@example.com", password: "password123"))
    #expect(requestHandled.value)
  }

  @Test
  func createWithOAuth() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ups")!
    let expectedRedirectUrl = Clerk.shared.options.redirectConfig.redirectUrl

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_google")
      #expect(request.urlEncodedFormBody!["redirect_url"] == expectedRedirectUrl)
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignUp.create(strategy: .oauth(provider: .google))
    #expect(requestHandled.value)
  }

  @Test
  func createWithOAuthExplicitRedirectUrl() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ups")!
    let explicitRedirectUrl = "custom://redirect"

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_google")
      #expect(request.urlEncodedFormBody!["redirect_url"] == explicitRedirectUrl)
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignUp.create(strategy: .oauth(provider: .google, redirectUrl: explicitRedirectUrl))
    #expect(requestHandled.value)
  }

  @Test
  func createWithEnterpriseSSO() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ups")!
    let expectedRedirectUrl = Clerk.shared.options.redirectConfig.redirectUrl

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "enterprise_sso")
      #expect(request.urlEncodedFormBody!["email_address"] == "user@enterprise.com")
      #expect(request.urlEncodedFormBody!["redirect_url"] == expectedRedirectUrl)
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignUp.create(strategy: .enterpriseSSO(identifier: "user@enterprise.com"))
    #expect(requestHandled.value)
  }

  @Test
  func createWithEnterpriseSSOExplicitRedirectUrl() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ups")!
    let explicitRedirectUrl = "custom://enterprise-redirect"

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "enterprise_sso")
      #expect(request.urlEncodedFormBody!["email_address"] == "user@enterprise.com")
      #expect(request.urlEncodedFormBody!["redirect_url"] == explicitRedirectUrl)
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignUp.create(strategy: .enterpriseSSO(identifier: "user@enterprise.com", redirectUrl: explicitRedirectUrl))
    #expect(requestHandled.value)
  }

  @Test
  func createWithIdToken() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ups")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_token_apple")
      #expect(request.urlEncodedFormBody!["token"] == "mock_id_token")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignUp.create(strategy: .idToken(provider: .apple, idToken: "mock_id_token"))
    #expect(requestHandled.value)
  }

  @Test
  func createWithTicket() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ups")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "ticket")
      #expect(request.urlEncodedFormBody!["ticket"] == "mock_ticket_value")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignUp.create(strategy: .ticket("mock_ticket_value"))
    #expect(requestHandled.value)
  }

  @Test
  func createWithTransfer() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ups")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["transfer"] == "1")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignUp.create(strategy: .transfer)
    #expect(requestHandled.value)
  }

  @Test
  func createWithNone() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ups")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignUp.create(strategy: .none)
    #expect(requestHandled.value)
  }

  @Test
  func testUpdate() async throws {
    let signUp = SignUp.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ups/\(signUp.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody!["first_name"] == "John")
      #expect(request.urlEncodedFormBody!["last_name"] == "Doe")
      requestHandled.setValue(true)
    }
    mock.register()

    try await signUp.update(params: .init(firstName: "John", lastName: "Doe"))
    #expect(requestHandled.value)
  }

  @Test
  func prepareVerificationEmailCode() async throws {
    let signUp = SignUp.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ups/\(signUp.id)/prepare_verification")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "email_code")
      requestHandled.setValue(true)
    }
    mock.register()

    try await signUp.prepareVerification(strategy: .emailCode)
    #expect(requestHandled.value)
  }

  @Test
  func prepareVerificationPhoneCode() async throws {
    let signUp = SignUp.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ups/\(signUp.id)/prepare_verification")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "phone_code")
      requestHandled.setValue(true)
    }
    mock.register()

    try await signUp.prepareVerification(strategy: .phoneCode)
    #expect(requestHandled.value)
  }

  @Test
  func attemptVerificationEmailCode() async throws {
    let signUp = SignUp.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ups/\(signUp.id)/attempt_verification")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "email_code")
      #expect(request.urlEncodedFormBody!["code"] == "123456")
      requestHandled.setValue(true)
    }
    mock.register()

    try await signUp.attemptVerification(strategy: .emailCode(code: "123456"))
    #expect(requestHandled.value)
  }

  @Test
  func attemptVerificationPhoneCode() async throws {
    let signUp = SignUp.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ups/\(signUp.id)/attempt_verification")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "phone_code")
      #expect(request.urlEncodedFormBody!["code"] == "654321")
      requestHandled.setValue(true)
    }
    mock.register()

    try await signUp.attemptVerification(strategy: .phoneCode(code: "654321"))
    #expect(requestHandled.value)
  }

  @Test
  func testGet() async throws {
    let signUp = SignUp.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ups/\(signUp.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await signUp.get()
    #expect(requestHandled.value)
  }

  @Test
  func getWithRotatingTokenNonce() async throws {
    let signUp = SignUp.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ups/\(signUp.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("rotating_token_nonce=test_nonce") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await signUp.get(rotatingTokenNonce: "test_nonce")
    #expect(requestHandled.value)
  }
}
