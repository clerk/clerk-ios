import ConcurrencyExtras
import FactoryKit
import Foundation
import Mocker
import Testing

@testable import ClerkKit

// Any test that accesses Container.shared or performs networking
// should be placed in the serialized tests below

struct SignInTests {

  @Test @MainActor func testAuthenticateWithRedirectStrategyParams() {
    let enterpriseSSO = SignIn.AuthenticateWithRedirectStrategy.enterpriseSSO(identifier: "user@email.com")
    #expect(enterpriseSSO.signInStrategy.params.strategy == "enterprise_sso")
    #expect(enterpriseSSO.signInStrategy.params.identifier == "user@email.com")

    let oauth = SignIn.AuthenticateWithRedirectStrategy.oauth(provider: .google)
    #expect(oauth.signInStrategy.params.strategy == "oauth_google")
  }

  @Test func testNeedsTransferToSignUp() {
    let transferableSignIn1 = SignIn(
      id: "1",
      status: .needsFirstFactor,
      supportedIdentifiers: [],
      identifier: nil,
      supportedFirstFactors: nil,
      supportedSecondFactors: nil,
      firstFactorVerification: .init(
        status: .transferable,
        strategy: nil,
        attempts: nil,
        expireAt: nil,
        error: nil,
        externalVerificationRedirectUrl: nil,
        nonce: nil
      ),
      secondFactorVerification: nil,
      userData: nil,
      createdSessionId: nil
    )

    #expect(transferableSignIn1.needsTransferToSignUp)

    let transferableSignIn2 = SignIn(
      id: "1",
      status: .needsFirstFactor,
      supportedIdentifiers: [],
      identifier: nil,
      supportedFirstFactors: nil,
      supportedSecondFactors: nil,
      firstFactorVerification: nil,
      secondFactorVerification: .init(
        status: .transferable,
        strategy: nil,
        attempts: nil,
        expireAt: nil,
        error: nil,
        externalVerificationRedirectUrl: nil,
        nonce: nil
      ),
      userData: nil,
      createdSessionId: nil
    )

    #expect(transferableSignIn2.needsTransferToSignUp)
  }

}

@Suite(.serialized) struct SignInSerializedTests {

  init() {
    Container.shared.reset()
  }

  @Test(
    "All create strategies",
    arguments: [
      SignIn.CreateStrategy.enterpriseSSO(identifier: "user@email.com"),
      .idToken(provider: .apple, idToken: "token"),
      .identifier("user@email.com", password: "password"),
      .identifier("user@email.com", password: "password", strategy: .emailCode()),
      .oauth(provider: .google),
      .passkey,
      .ticket("ticket"),
      .transfer,
      .none
    ])
  @MainActor
  func testCreateRequest(strategy: SignIn.CreateStrategy) async throws {
    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody["strategy"] == strategy.params.strategy)
      #expect(request.urlEncodedFormBody["identifier"] == strategy.params.identifier)
      #expect(request.urlEncodedFormBody["password"] == strategy.params.password)
      #expect(request.urlEncodedFormBody["ticket"] == strategy.params.ticket)
      #expect(request.urlEncodedFormBody["token"] == strategy.params.token)
      #expect(request.urlEncodedFormBody["redirect_url"] == strategy.params.redirectUrl)
      if let transfer = strategy.params.transfer {
        #expect(request.urlEncodedFormBody["transfer"] == String(describing: NSNumber(booleanLiteral: transfer)))
      }
      #expect(request.urlEncodedFormBody["oidc_prompt"] == strategy.params.oidcPrompt)
      #expect(request.urlEncodedFormBody["oidc_login_hint"] == strategy.params.oidcLoginHint)
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await SignIn.create(strategy: strategy)
    #expect(requestHandled.value)
  }

  @Test func testCreateRawRequest() async throws {
    let requestHandled = LockIsolated(false)
    let params = [
      "strategy": "email_code",
      "identifier": "user@email.com",
      "password": "password",
      "ticket": "ticket",
      "token": "token",
      "redirect_url": "url",
      "transfer": String(describing: NSNumber(booleanLiteral: true)),
      "oidc_prompt": "prompt",
      "oidc_login_hint": "hint"
    ]
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody["strategy"] == params["strategy"])
      #expect(request.urlEncodedFormBody["identifier"] == params["identifier"])
      #expect(request.urlEncodedFormBody["password"] == params["password"])
      #expect(request.urlEncodedFormBody["ticket"] == params["ticket"])
      #expect(request.urlEncodedFormBody["token"] == params["token"])
      #expect(request.urlEncodedFormBody["redirect_url"] == params["redirect_url"])
      #expect(request.urlEncodedFormBody["transfer"] == params["transfer"])
      #expect(request.urlEncodedFormBody["oidc_prompt"] == params["oidc_prompt"])
      #expect(request.urlEncodedFormBody["oidc_login_hint"] == params["oidc_login_hint"])
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await SignIn.create(params)
    #expect(requestHandled.value)
  }

  @Test func testResetPasswordRequest() async throws {
    let requestHandled = LockIsolated(false)
    let signIn = SignIn.mock
    let params = SignIn.ResetPasswordParams(password: "password", signOutOfOtherSessions: true)
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins/\(signIn.id)/reset_password")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody["password"] == params.password)
      if let signOutOfOtherSession = params.signOutOfOtherSessions {
        #expect(request.urlEncodedFormBody["sign_out_of_other_sessions"] == String(describing: NSNumber(booleanLiteral: signOutOfOtherSession)))
      }
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await signIn.resetPassword(params)
    #expect(requestHandled.value)
  }

  @Test(
    "All prepare first factor strategies",
    arguments: [
      SignIn.PrepareFirstFactorStrategy.emailCode(),
      .emailCode(emailAddressId: "1"),
      .oauth(provider: .google),
      .enterpriseSSO(),
      .passkey,
      .phoneCode(),
      .phoneCode(phoneNumberId: "1"),
      .resetPasswordEmailCode(emailAddressId: "1"),
      .resetPasswordPhoneCode(phoneNumberId: "1")
    ])
  @MainActor
  func testPrepareFirstFactorRequest(strategy: SignIn.PrepareFirstFactorStrategy) async throws {
    let requestHandled = LockIsolated(false)
    let signIn = SignIn.mock
    let params = strategy.params(signIn: signIn)
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins/\(signIn.id)/prepare_first_factor")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody["strategy"] == params.strategy)
      #expect(request.urlEncodedFormBody["email_address_id"] == params.emailAddressId)
      #expect(request.urlEncodedFormBody["phone_number_id"] == params.phoneNumberId)
      #expect(request.urlEncodedFormBody["redirect_url"] == params.redirectUrl)
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await signIn.prepareFirstFactor(strategy: strategy)
    #expect(requestHandled.value)
  }

  @Test(
    "All attempt first factor strategies",
    arguments: [
      SignIn.AttemptFirstFactorStrategy.emailCode(code: "emailcode"),
      .passkey(publicKeyCredential: "credential"),
      .password(password: "password"),
      .phoneCode(code: "phonecode"),
      .resetPasswordEmailCode(code: "resetemailcode"),
      .resetPasswordPhoneCode(code: "resetphonecode")
    ])
  func testAttemptFirstFactorRequest(strategy: SignIn.AttemptFirstFactorStrategy) async throws {
    let requestHandled = LockIsolated(false)
    let signIn = SignIn.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins/\(signIn.id)/attempt_first_factor")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody["strategy"] == strategy.params.strategy)
      #expect(request.urlEncodedFormBody["code"] == strategy.params.code)
      #expect(request.urlEncodedFormBody["password"] == strategy.params.password)
      #expect(request.urlEncodedFormBody["public_key_credential"] == strategy.params.publicKeyCredential)
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await signIn.attemptFirstFactor(strategy: strategy)
    #expect(requestHandled.value)
  }

  @Test(
    "All prepare second factor strategies",
    arguments: [
      SignIn.PrepareSecondFactorStrategy.phoneCode
    ])
  func testPrepareFirstFactorRequest(strategy: SignIn.PrepareSecondFactorStrategy) async throws {
    let requestHandled = LockIsolated(false)
    let signIn = SignIn.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins/\(signIn.id)/prepare_second_factor")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody["strategy"] == strategy.params.strategy)
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await signIn.prepareSecondFactor(strategy: strategy)
    #expect(requestHandled.value)
  }

  @Test(
    "All attempt second factor strategies",
    arguments: [
      SignIn.AttemptSecondFactorStrategy.backupCode(code: "backupcode"),
      .phoneCode(code: "phonecode"),
      .totp(code: "totpcode")
    ])
  func testAttemptSecondFactorRequest(strategy: SignIn.AttemptSecondFactorStrategy) async throws {
    let requestHandled = LockIsolated(false)
    let signIn = SignIn.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins/\(signIn.id)/attempt_second_factor")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody["strategy"] == strategy.params.strategy)
      #expect(request.urlEncodedFormBody["code"] == strategy.params.code)
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await signIn.attemptSecondFactor(strategy: strategy)
    #expect(requestHandled.value)
  }

  @Test(arguments: [nil, UUID().uuidString])
  func testGetRequest(rotatingTokenNonce: String?) async throws {
    let requestHandled = LockIsolated(false)
    let signIn = SignIn.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins/\(signIn.id)")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      if let rotatingTokenNonce {
        #expect(request.url!.query()!.contains("rotating_token_nonce=\(rotatingTokenNonce)"))
      }
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await signIn.get(rotatingTokenNonce: rotatingTokenNonce)
    #expect(requestHandled.value)
  }

  @Test func testHandleTransferFlow() async throws {
    // Transferable
    let transferableSignIn = SignIn(
      id: "1",
      status: .needsFirstFactor,
      supportedIdentifiers: [],
      identifier: nil,
      supportedFirstFactors: nil,
      supportedSecondFactors: nil,
      firstFactorVerification: .init(
        status: .transferable,
        strategy: nil,
        attempts: nil,
        expireAt: nil,
        error: nil,
        externalVerificationRedirectUrl: nil,
        nonce: nil
      ),
      secondFactorVerification: nil,
      userData: nil,
      createdSessionId: nil
    )

    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ups")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody["transfer"] == String(describing: NSNumber(booleanLiteral: true)))
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await transferableSignIn.handleTransferFlow()
    #expect(requestHandled.value)
  }

  @Test func handleOAuthCallbackUrlWithoutNonce() async throws {
    let nonTransferableSignIn = SignIn.mock
    let result = try await nonTransferableSignIn.handleTransferFlow()
    if case .signIn(let signIn) = result {
      #expect(signIn == .mock)
    } else {
      Issue.record("A signup was returned. Expected a sign in.")
    }
  }

  @Test func handleOAuthCallbackUrlWithNonce() async throws {
    let signIn = SignIn.mock
    let nonce = UUID().uuidString

    var components = URLComponents(url: mockBaseUrl.appending(path: "/v1/client/sign_ins/\(signIn.id)"), resolvingAgainstBaseURL: true)!
    components.queryItems = [.init(name: "rotating_token_nonce", value: nonce), .init(name: "_is_native", value: "true")]
    let callbackUrl = components.url!

    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins/\(signIn.id)")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url!.query()!.contains("rotating_token_nonce=\(nonce)"))
      requestHandled.setValue(true)
    }
    mock.register()
    let result = try await signIn.handleOAuthCallbackUrl(callbackUrl)
    if case .signIn(let signIn) = result {
      #expect(signIn == .mock)
    } else {
      Issue.record("A signup was returned. Expected a sign in.")
    }
    #expect(requestHandled.value)
  }

  @Test func handleOAuthCallbackUrlForTransferFlow() async throws {
    let signIn = SignIn(
      id: "1",
      status: .needsFirstFactor,
      supportedIdentifiers: [],
      identifier: nil,
      supportedFirstFactors: nil,
      supportedSecondFactors: nil,
      firstFactorVerification: .init(
        status: .transferable,
        strategy: nil,
        attempts: nil,
        expireAt: nil,
        error: nil,
        externalVerificationRedirectUrl: nil,
        nonce: nil
      ),
      secondFactorVerification: nil,
      userData: nil,
      createdSessionId: nil
    )

    let components = URLComponents(url: mockBaseUrl.appending(path: "/v1/client/sign_ins/\(signIn.id)"), resolvingAgainstBaseURL: true)!
    let callbackUrl = components.url!

    let signInRequestHandled = LockIsolated(false)
    let signInUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins/\(signIn.id)")
    var mockSignIn = Mock(
      url: signInUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>(response: signIn, client: .mock))
      ])
    mockSignIn.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      signInRequestHandled.setValue(true)
    }
    mockSignIn.register()

    let signUpRequestHandled = LockIsolated(false)
    let signUpUrl = mockBaseUrl.appending(path: "/v1/client/sign_ups")
    var mockSignUp = Mock(
      url: signUpUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
      ])
    mockSignUp.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody["transfer"] == String(describing: NSNumber(booleanLiteral: true)))
      #expect(request.urlEncodedFormBody["locale"] == LocaleUtils.userLocale())
      signUpRequestHandled.setValue(true)
    }
    mockSignUp.register()

    _ = try await signIn.handleOAuthCallbackUrl(callbackUrl)
    #expect(signInRequestHandled.value)
    #expect(signUpRequestHandled.value)
  }

}
