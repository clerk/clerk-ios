import FactoryTesting
import Foundation
import Mocker
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct SignInTests {

  init() {
    configureClerkForTesting()
  }

  @Test(.container)
  func testCreateWithIdentifier() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["identifier"] == "test@example.com")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignIn.create(strategy: .identifier("test@example.com"))
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testCreateWithOAuth() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins")!
    let expectedRedirectUrl = Clerk.shared.options.redirectConfig.redirectUrl

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_google")
      #expect(request.urlEncodedFormBody!["redirect_url"] == expectedRedirectUrl)
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignIn.create(strategy: .oauth(provider: .google))
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testCreateWithOAuthExplicitRedirectUrl() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins")!
    let explicitRedirectUrl = "custom://redirect"

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_google")
      #expect(request.urlEncodedFormBody!["redirect_url"] == explicitRedirectUrl)
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignIn.create(strategy: .oauth(provider: .google, redirectUrl: explicitRedirectUrl))
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testCreateWithEnterpriseSSO() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins")!
    let expectedRedirectUrl = Clerk.shared.options.redirectConfig.redirectUrl

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "enterprise_sso")
      #expect(request.urlEncodedFormBody!["identifier"] == "user@enterprise.com")
      #expect(request.urlEncodedFormBody!["redirect_url"] == expectedRedirectUrl)
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignIn.create(strategy: .enterpriseSSO(identifier: "user@enterprise.com"))
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testCreateWithEnterpriseSSOExplicitRedirectUrl() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins")!
    let explicitRedirectUrl = "custom://enterprise-redirect"

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "enterprise_sso")
      #expect(request.urlEncodedFormBody!["identifier"] == "user@enterprise.com")
      #expect(request.urlEncodedFormBody!["redirect_url"] == explicitRedirectUrl)
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignIn.create(strategy: .enterpriseSSO(identifier: "user@enterprise.com", redirectUrl: explicitRedirectUrl))
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testCreateWithIdToken() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_token_apple")
      #expect(request.urlEncodedFormBody!["token"] == "mock_id_token")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignIn.create(strategy: .idToken(provider: .apple, idToken: "mock_id_token"))
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testCreateWithPasskey() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "passkey")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignIn.create(strategy: .passkey)
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testCreateWithTicket() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "ticket")
      #expect(request.urlEncodedFormBody!["ticket"] == "mock_ticket_value")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignIn.create(strategy: .ticket("mock_ticket_value"))
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testCreateWithTransfer() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["transfer"] == "1")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignIn.create(strategy: .transfer)
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testCreateWithNone() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    try await SignIn.create(strategy: .none)
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testResetPassword() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/reset_password")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["password"] == "newPassword123")
      #expect(request.urlEncodedFormBody!["sign_out_of_other_sessions"] == "1")
      requestHandled.setValue(true)
    }
    mock.register()

    try await signIn.resetPassword(.init(password: "newPassword123", signOutOfOtherSessions: true))
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testPrepareFirstFactorEmailCode() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/prepare_first_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "email_code")
      requestHandled.setValue(true)
    }
    mock.register()

    try await signIn.prepareFirstFactor(strategy: .emailCode())
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testPrepareFirstFactorPhoneCode() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/prepare_first_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "phone_code")
      requestHandled.setValue(true)
    }
    mock.register()

    try await signIn.prepareFirstFactor(strategy: .phoneCode())
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testPrepareFirstFactorPasskey() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/prepare_first_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "passkey")
      requestHandled.setValue(true)
    }
    mock.register()

    try await signIn.prepareFirstFactor(strategy: .passkey)
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testAttemptFirstFactorPassword() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/attempt_first_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "password")
      #expect(request.urlEncodedFormBody!["password"] == "password123")
      requestHandled.setValue(true)
    }
    mock.register()

    try await signIn.attemptFirstFactor(strategy: .password(password: "password123"))
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testAttemptFirstFactorEmailCode() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/attempt_first_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "email_code")
      #expect(request.urlEncodedFormBody!["code"] == "123456")
      requestHandled.setValue(true)
    }
    mock.register()

    try await signIn.attemptFirstFactor(strategy: .emailCode(code: "123456"))
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testAttemptFirstFactorPhoneCode() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/attempt_first_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "phone_code")
      #expect(request.urlEncodedFormBody!["code"] == "654321")
      requestHandled.setValue(true)
    }
    mock.register()

    try await signIn.attemptFirstFactor(strategy: .phoneCode(code: "654321"))
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testAttemptFirstFactorPasskey() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/attempt_first_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "passkey")
      #expect(request.urlEncodedFormBody!["public_key_credential"] == "mock_credential")
      requestHandled.setValue(true)
    }
    mock.register()

    try await signIn.attemptFirstFactor(strategy: .passkey(publicKeyCredential: "mock_credential"))
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testPrepareSecondFactor() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/prepare_second_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "phone_code")
      requestHandled.setValue(true)
    }
    mock.register()

    try await signIn.prepareSecondFactor(strategy: .phoneCode)
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testAttemptSecondFactorPhoneCode() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/attempt_second_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "phone_code")
      #expect(request.urlEncodedFormBody!["code"] == "123456")
      requestHandled.setValue(true)
    }
    mock.register()

    try await signIn.attemptSecondFactor(strategy: .phoneCode(code: "123456"))
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testAttemptSecondFactorTotp() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/attempt_second_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "totp")
      #expect(request.urlEncodedFormBody!["code"] == "654321")
      requestHandled.setValue(true)
    }
    mock.register()

    try await signIn.attemptSecondFactor(strategy: .totp(code: "654321"))
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testAttemptSecondFactorBackupCode() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/attempt_second_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "backup_code")
      #expect(request.urlEncodedFormBody!["code"] == "backup123")
      requestHandled.setValue(true)
    }
    mock.register()

    try await signIn.attemptSecondFactor(strategy: .backupCode(code: "backup123"))
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testGet() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await signIn.get()
    #expect(requestHandled.value)
  }

  @Test(.container)
  func testGetWithRotatingTokenNonce() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("rotating_token_nonce=test_nonce") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await signIn.get(rotatingTokenNonce: "test_nonce")
    #expect(requestHandled.value)
  }
}
