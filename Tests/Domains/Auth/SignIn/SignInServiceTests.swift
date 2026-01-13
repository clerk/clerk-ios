import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct SignInServiceTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func createWithIdentifier() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["identifier"] == "test@example.com")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.signInService.create(params: .init(identifier: "test@example.com"))
    #expect(requestHandled.value)
  }

  @Test
  func createWithOAuth() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins")!
    let expectedRedirectUrl = Clerk.shared.options.redirectConfig.redirectUrl

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
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

    _ = try await Clerk.shared.dependencies.signInService.create(params: .init(
      strategy: .oauth(.google),
      redirectUrl: expectedRedirectUrl
    ))
    #expect(requestHandled.value)
  }

  @Test
  func createWithEnterpriseSSO() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins")!
    let expectedRedirectUrl = Clerk.shared.options.redirectConfig.redirectUrl

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "enterprise_sso")
      #expect(request.urlEncodedFormBody!["identifier"] == "user@enterprise.com")
      #expect(request.urlEncodedFormBody!["redirect_url"] == expectedRedirectUrl)
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.signInService.create(params: .init(
      identifier: "user@enterprise.com",
      strategy: .enterpriseSSO,
      redirectUrl: expectedRedirectUrl
    ))
    #expect(requestHandled.value)
  }

  @Test
  func createWithIdToken() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
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

    _ = try await Clerk.shared.dependencies.signInService.create(params: .init(
      strategy: .idToken(.apple),
      token: "mock_id_token"
    ))
    #expect(requestHandled.value)
  }

  @Test
  func createWithPasskey() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "passkey")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.signInService.create(params: .init(strategy: .passkey))
    #expect(requestHandled.value)
  }

  @Test
  func createWithTicket() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
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

    _ = try await Clerk.shared.dependencies.signInService.create(params: .init(
      strategy: .ticket,
      ticket: "mock_ticket_value"
    ))
    #expect(requestHandled.value)
  }

  @Test
  func createWithTransfer() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["transfer"] == "1")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    // Transfer is an internal parameter not exposed in public API, so we test the service directly
    _ = try await Clerk.shared.dependencies.signInService.create(params: .init(transfer: true))
    #expect(requestHandled.value)
  }

  @Test
  func createWithNone() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["locale"] != nil)
      requestHandled.setValue(true)
    }
    mock.register()

    // Empty create is not exposed in public API, so we test the service directly
    _ = try await Clerk.shared.dependencies.signInService.create(params: .init())
    #expect(requestHandled.value)
  }

  @Test
  func testResetPassword() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/reset_password")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["password"] == "newPassword123")
      #expect(request.urlEncodedFormBody!["sign_out_of_other_sessions"] == "1")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.signInService.resetPassword(
      signInId: signIn.id,
      params: .init(password: "newPassword123", signOutOfOtherSessions: true)
    )
    #expect(requestHandled.value)
  }

  @Test
  func prepareFirstFactorEmailCode() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/prepare_first_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "email_code")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.signInService.prepareFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .emailCode)
    )
    #expect(requestHandled.value)
  }

  @Test
  func prepareFirstFactorPhoneCode() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/prepare_first_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "phone_code")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.signInService.prepareFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .phoneCode)
    )
    #expect(requestHandled.value)
  }

  @Test
  func prepareFirstFactorPasskey() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/prepare_first_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "passkey")
      requestHandled.setValue(true)
    }
    mock.register()

    // Passkey prepare requires getting credential first, so we test the service directly for this unit test
    _ = try await Clerk.shared.dependencies.signInService.prepareFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .passkey)
    )
    #expect(requestHandled.value)
  }

  @Test
  func attemptFirstFactorPassword() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/attempt_first_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "password")
      #expect(request.urlEncodedFormBody!["password"] == "password123")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.signInService.attemptFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .password, password: "password123")
    )
    #expect(requestHandled.value)
  }

  @Test
  func attemptFirstFactorEmailCode() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/attempt_first_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "email_code")
      #expect(request.urlEncodedFormBody!["code"] == "123456")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.signInService.attemptFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .emailCode, code: "123456")
    )
    #expect(requestHandled.value)
  }

  @Test
  func attemptFirstFactorPhoneCode() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/attempt_first_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "phone_code")
      #expect(request.urlEncodedFormBody!["code"] == "654321")
      requestHandled.setValue(true)
    }
    mock.register()

    // verifyCode() infers strategy from firstFactorVerification state, which is hard to control in unit tests
    // For this test that specifically verifies phone_code parameters, we use the service directly
    _ = try await Clerk.shared.dependencies.signInService.attemptFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .phoneCode, code: "654321")
    )
    #expect(requestHandled.value)
  }

  @Test
  func attemptFirstFactorPasskey() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/attempt_first_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "passkey")
      #expect(request.urlEncodedFormBody!["public_key_credential"] == "mock_credential")
      requestHandled.setValue(true)
    }
    mock.register()

    // Passkey attempt requires getting credential first, so we test the service directly for this unit test
    _ = try await Clerk.shared.dependencies.signInService.attemptFirstFactor(
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
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/attempt_first_factor")!
    let mockIdToken = "mock_apple_id_token"

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "oauth_token_apple")
      #expect(request.urlEncodedFormBody!["token"] == mockIdToken)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.signInService.attemptFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .idToken(.apple), token: mockIdToken)
    )
    #expect(requestHandled.value)
  }
  #endif

  @Test
  func prepareSecondFactor() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/prepare_second_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "phone_code")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.signInService.prepareSecondFactor(
      signInId: signIn.id,
      params: .init(strategy: .phoneCode)
    )
    #expect(requestHandled.value)
  }

  @Test
  func attemptSecondFactorPhoneCode() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/attempt_second_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "phone_code")
      #expect(request.urlEncodedFormBody!["code"] == "123456")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.signInService.attemptSecondFactor(
      signInId: signIn.id,
      params: .init(strategy: .phoneCode, code: "123456")
    )
    #expect(requestHandled.value)
  }

  @Test
  func attemptSecondFactorTotp() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/attempt_second_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "totp")
      #expect(request.urlEncodedFormBody!["code"] == "654321")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.signInService.attemptSecondFactor(
      signInId: signIn.id,
      params: .init(strategy: .totp, code: "654321")
    )
    #expect(requestHandled.value)
  }

  @Test
  func attemptSecondFactorBackupCode() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)/attempt_second_factor")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody!["strategy"] == "backup_code")
      #expect(request.urlEncodedFormBody!["code"] == "backup123")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.signInService.attemptSecondFactor(
      signInId: signIn.id,
      params: .init(strategy: .backupCode, code: "backup123")
    )
    #expect(requestHandled.value)
  }

  @Test
  func testGet() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.signInService.get(
      signInId: signIn.id,
      params: .init()
    )
    #expect(requestHandled.value)
  }

  @Test
  func getWithRotatingTokenNonce() async throws {
    let signIn = SignIn.mock
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sign_ins/\(signIn.id)")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock)),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.query?.contains("rotating_token_nonce=test_nonce") == true)
      requestHandled.setValue(true)
    }
    mock.register()

    _ = try await Clerk.shared.dependencies.signInService.get(
      signInId: signIn.id,
      params: .init(rotatingTokenNonce: "test_nonce")
    )
    #expect(requestHandled.value)
  }
}
