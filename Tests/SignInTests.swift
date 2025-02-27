import ConcurrencyExtras
import Factory
import Foundation
import Mocker
import Testing

@testable import Clerk

// Any test that accesses Container.shared or performs networking
// should be placed in the serialized tests below

struct SignInTest {
  
  @MainActor
  @Test func testAuthenticateWithRedirectStrategyParams() {
    let enterpriseSSO = SignIn.AuthenticateWithRedirectStrategy.enterpriseSSO(identifier: "user@email.com")
    #expect(enterpriseSSO.params.strategy == "enterprise_sso")
    #expect(enterpriseSSO.params.identifier == "user@email.com")
    
    let oauth = SignIn.AuthenticateWithRedirectStrategy.oauth(provider: .google)
    #expect(oauth.params.strategy == "oauth_google")
  }
  
}

@Suite(.serialized) struct SignInSerializedTests {
  
  init() {
    Container.shared.reset()
  }
  
  @MainActor
  @Test("All create strategies", arguments: [
    SignIn.CreateStrategy.enterpriseSSO(identifier: "user@email.com"),
    .idToken(provider: .apple, idToken: "token"),
    .identifier("user@email.com", password: "password", strategy: "email_code"),
    .oauth(provider: .google),
    .passkey,
    .ticket("ticket"),
    .transfer,
    .none
  ])
  func testCreateRequest(strategy: SignIn.CreateStrategy) async throws {
    let requestHandled = LockIsolated(false)
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>.init(response: .mock, client: .mock))
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
      "action_complete_redirect_url": "complete_url",
      "transfer": String(describing: NSNumber(booleanLiteral: true)),
      "oidc_prompt": "prompt",
      "oidc_login_hint": "hint"
    ]
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody["strategy"] == params["strategy"])
      #expect(request.urlEncodedFormBody["identifier"] == params["identifier"])
      #expect(request.urlEncodedFormBody["password"] == params["password"])
      #expect(request.urlEncodedFormBody["ticket"] == params["ticket"])
      #expect(request.urlEncodedFormBody["token"] == params["token"])
      #expect(request.urlEncodedFormBody["redirect_url"] == params["redirect_url"])
      #expect(request.urlEncodedFormBody["action_complete_redirect_url"] == params["action_complete_redirect_url"])
      #expect(request.urlEncodedFormBody["transfer"] == params["transfer"])
      #expect(request.urlEncodedFormBody["oidc_prompt"] == params["oidc_prompt"])
      #expect(request.urlEncodedFormBody["oidc_login_hint"] == params["oidc_login_hint"])
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await SignIn.create(params)
    #expect(requestHandled.value)
  }
  
  @MainActor
  @Test func testResetPasswordRequest() async throws {
    let requestHandled = LockIsolated(false)
    let signIn = SignIn.mock
    let params = SignIn.ResetPasswordParams(password: "password", signOutOfOtherSessions: true)
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins/\(signIn.id)/reset_password")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>.init(response: .mock, client: .mock))
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
  
  @MainActor
  @Test("All prepare first factor strategies", arguments: [
    SignIn.PrepareFirstFactorStrategy.emailCode(emailAddressId: "1"),
    .enterpriseSSO(),
    .passkey,
    .phoneCode(phoneNumberId: "1"),
    .resetPasswordEmailCode(emailAddressId: "1"),
    .resetPasswordPhoneCode(phoneNumberId: "1")
  ])
  func testPrepareFirstFactorRequest(strategy: SignIn.PrepareFirstFactorStrategy) async throws {
    let requestHandled = LockIsolated(false)
    let signIn = SignIn.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins/\(signIn.id)/prepare_first_factor")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody["strategy"] == strategy.params.strategy)
      #expect(request.urlEncodedFormBody["email_address_id"] == strategy.params.emailAddressId)
      #expect(request.urlEncodedFormBody["phone_number_id"] == strategy.params.phoneNumberId)
      #expect(request.urlEncodedFormBody["redirect_url"] == strategy.params.redirectUrl)
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await signIn.prepareFirstFactor(for: strategy)
    #expect(requestHandled.value)
  }
  
  @MainActor
  @Test("All attempt first factor strategies", arguments: [
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
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>.init(response: .mock, client: .mock))
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
    _ = try await signIn.attemptFirstFactor(for: strategy)
    #expect(requestHandled.value)
  }
  
  @MainActor
  @Test("All prepare second factor strategies", arguments: [
    SignIn.PrepareSecondFactorStrategy.phoneCode
  ])
  func testPrepareFirstFactorRequest(strategy: SignIn.PrepareSecondFactorStrategy) async throws {
    let requestHandled = LockIsolated(false)
    let signIn = SignIn.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins/\(signIn.id)/prepare_second_factor")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody["strategy"] == strategy.params.strategy)
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await signIn.prepareSecondFactor(for: strategy)
    #expect(requestHandled.value)
  }
  
  @MainActor
  @Test("All attempt second factor strategies", arguments: [
    SignIn.AttemptSecondFactorStrategy.backupCode(code: "backupcode"),
    .phoneCode(code: "phonecode"),
    .totp(code: "totpcode")
  ])
  func testAttemptSecondFactorRequest(strategy: SignIn.AttemptSecondFactorStrategy) async throws {
    let requestHandled = LockIsolated(false)
    let signIn = SignIn.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins/\(signIn.id)/attempt_second_factor")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody["strategy"] == strategy.params.strategy)
      #expect(request.urlEncodedFormBody["code"] == strategy.params.code)
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await signIn.attemptSecondFactor(for: strategy)
    #expect(requestHandled.value)
  }
  
  @MainActor
  @Test func testGetRequest() async throws {
    let requestHandled = LockIsolated(false)
    let signIn = SignIn.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins/\(signIn.id)")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await signIn.get()
    #expect(requestHandled.value)
  }
  
  @MainActor
  @Test func testGetWithRotatingTokenNonceRequest() async throws {
    let requestHandled = LockIsolated(false)
    let signIn = SignIn.mock
    let nonce = UUID().uuidString
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ins/\(signIn.id)")
    var mock = Mock(url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200, data: [
      .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignIn>.init(response: .mock, client: .mock))
    ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url!.query()!.contains("rotating_token_nonce=\(nonce)"))
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await signIn.get(rotatingTokenNonce: nonce)
    #expect(requestHandled.value)
  }
  
}
