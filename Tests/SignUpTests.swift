import ConcurrencyExtras
import FactoryKit
import Foundation
import Mocker
import Testing

@testable import ClerkKit

// Any test that accesses Container.shared or performs networking
// should be placed in the serialized tests below

struct SignUpTests {

  @Test @MainActor func testAuthenticateWithRedirectStrategyParams() {
    let enterpriseSSO = SignUp.AuthenticateWithRedirectStrategy.enterpriseSSO(identifier: "user@email.com")
    #expect(enterpriseSSO.params.strategy == "enterprise_sso")
    #expect(enterpriseSSO.params.identifier == "user@email.com")

    let oauth = SignUp.AuthenticateWithRedirectStrategy.oauth(provider: .google)
    #expect(oauth.params.strategy == "oauth_google")
  }

}

@Suite(.serialized) struct SignUpSerializedTests {

  init() {
    resetTestContainer()
  }

  @Test(
    "All create strategies",
    arguments: [
      SignUp.CreateStrategy.enterpriseSSO(identifier: "user@email.com", redirectUrl: "createRedirectUrl"),
      .ticket("ticket"),
      .idToken(provider: .apple, idToken: "token", firstName: "First", lastName: "Last"),
      .oauth(provider: .google, redirectUrl: "oauthRedirectUrl"),
      .standard(emailAddress: "user@email.com", password: "password", firstName: "First", lastName: "Last", username: "username", phoneNumber: "phoneNumber"),
      .transfer
    ])
  @MainActor
  func testCreateRequest(strategy: SignUp.CreateStrategy) async throws {
    let requestHandled = LockIsolated(false)
    let legalAccepted: Bool? = true
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ups")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody["email_address"] == strategy.params.emailAddress)
      #expect(request.urlEncodedFormBody["first_name"] == strategy.params.firstName)
      #expect(request.urlEncodedFormBody["last_name"] == strategy.params.lastName)
      #expect(request.urlEncodedFormBody["locale"] == LocaleUtils.userLocale())
      #expect(request.urlEncodedFormBody["oidc_login_hint"] == strategy.params.oidcLoginHint)
      #expect(request.urlEncodedFormBody["oidc_prompt"] == strategy.params.oidcPrompt)
      #expect(request.urlEncodedFormBody["password"] == strategy.params.password)
      #expect(request.urlEncodedFormBody["phone_number"] == strategy.params.phoneNumber)
      #expect(request.urlEncodedFormBody["redirect_url"] == strategy.params.redirectUrl)
      #expect(request.urlEncodedFormBody["strategy"] == strategy.params.strategy)
      #expect(request.urlEncodedFormBody["ticket"] == strategy.params.ticket)
      #expect(request.urlEncodedFormBody["token"] == strategy.params.token)
      #expect(request.urlEncodedFormBody["username"] == strategy.params.username)
      #expect(request.urlEncodedFormBody["web3_wallet"] == strategy.params.web3Wallet)
      #expect(request.urlEncodedFormBody["unsafe_metadata"] == strategy.params.unsafeMetadata?.stringValue)
      if let legalAccepted {
        #expect(request.urlEncodedFormBody["legal_accepted"] == String(describing: NSNumber(booleanLiteral: legalAccepted)))
      }
      if let transfer = strategy.params.transfer {
        #expect(request.urlEncodedFormBody["transfer"] == String(describing: NSNumber(booleanLiteral: transfer)))
      }
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await SignUp.create(strategy: strategy, legalAccepted: legalAccepted)
    #expect(requestHandled.value)
  }

  @Test func testCreateRawRequest() async throws {
    let requestHandled = LockIsolated(false)
    let params = [
      "strategy": "strategy",
      "first_name": "first",
      "last_name": "last",
      "password": "password",
      "email_address": "user@email.com",
      "phone_number": "5555550100",
      "web3_wallet": "wallet",
      "username": "username",
      "unsafe_metadata": "metadata",
      "redirect_url": "redirctUrl",
      "ticket": "ticket",
      "transfer": "1",
      "legal_accepted": "1",
      "oidc_prompt": "oidcPrompt",
      "oidc_login_hint": "oidcHint",
      "token": "token"
    ]
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ups")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody["email_address"] == params["email_address"])
      #expect(request.urlEncodedFormBody["first_name"] == params["first_name"])
      #expect(request.urlEncodedFormBody["last_name"] == params["last_name"])
      #expect(request.urlEncodedFormBody["locale"] == LocaleUtils.userLocale())
      #expect(request.urlEncodedFormBody["oidc_login_hint"] == params["oidc_login_hint"])
      #expect(request.urlEncodedFormBody["oidc_prompt"] == params["oidc_prompt"])
      #expect(request.urlEncodedFormBody["password"] == params["password"])
      #expect(request.urlEncodedFormBody["phone_number"] == params["phone_number"])
      #expect(request.urlEncodedFormBody["redirect_url"] == params["redirect_url"])
      #expect(request.urlEncodedFormBody["strategy"] == params["strategy"])
      #expect(request.urlEncodedFormBody["ticket"] == params["ticket"])
      #expect(request.urlEncodedFormBody["token"] == params["token"])
      #expect(request.urlEncodedFormBody["username"] == params["username"])
      #expect(request.urlEncodedFormBody["web3_wallet"] == params["web3_wallet"])
      #expect(request.urlEncodedFormBody["unsafe_metadata"] == params["unsafe_metadata"])
      #expect(request.urlEncodedFormBody["legal_accepted"] == params["legal_accepted"])
      #expect(request.urlEncodedFormBody["transfer"] == params["transfer"])
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await SignUp.create(params)
    #expect(requestHandled.value)
  }

  @Test func testCreateRequestWithCustomLocale() async throws {
    let requestHandled = LockIsolated(false)
    let strategy = SignUp.CreateStrategy.standard(emailAddress: "user@email.com", password: "password")
    let customLocale = "fr-FR"
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ups")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody["locale"] == customLocale)
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await SignUp.create(strategy: strategy, locale: customLocale)
    #expect(requestHandled.value)
  }

  @Test func testUpdateRequest() async throws {
    let requestHandled = LockIsolated(false)
    let params = SignUp.UpdateParams(
      strategy: "strategy",
      firstName: "first",
      lastName: "last",
      password: "password",
      emailAddress: "user@email.com",
      phoneNumber: "5555550100",
      web3Wallet: "wallet",
      username: "username",
      unsafeMetadata: "metadata",
      redirectUrl: "redirctUrl",
      ticket: "ticket",
      transfer: true,
      legalAccepted: true,
      oidcPrompt: "oidcPrompt",
      oidcLoginHint: "oidcHint",
      token: "token"
    )
    let signUp = SignUp.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ups/\(signUp.id)")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .patch: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "PATCH")
      #expect(request.urlEncodedFormBody["email_address"] == params.emailAddress)
      #expect(request.urlEncodedFormBody["first_name"] == params.firstName)
      #expect(request.urlEncodedFormBody["last_name"] == params.lastName)
      #expect(request.urlEncodedFormBody["oidc_login_hint"] == params.oidcLoginHint)
      #expect(request.urlEncodedFormBody["oidc_prompt"] == params.oidcPrompt)
      #expect(request.urlEncodedFormBody["password"] == params.password)
      #expect(request.urlEncodedFormBody["phone_number"] == params.phoneNumber)
      #expect(request.urlEncodedFormBody["redirect_url"] == params.redirectUrl)
      #expect(request.urlEncodedFormBody["strategy"] == params.strategy)
      #expect(request.urlEncodedFormBody["ticket"] == params.ticket)
      #expect(request.urlEncodedFormBody["token"] == params.token)
      #expect(request.urlEncodedFormBody["username"] == params.username)
      #expect(request.urlEncodedFormBody["web3_wallet"] == params.web3Wallet)
      #expect(request.urlEncodedFormBody["unsafe_metadata"] == params.unsafeMetadata?.stringValue)
      if let legalAccepted = params.legalAccepted {
        #expect(request.urlEncodedFormBody["legal_accepted"] == String(describing: NSNumber(booleanLiteral: legalAccepted)))
      }
      if let transfer = params.transfer {
        #expect(request.urlEncodedFormBody["transfer"] == String(describing: NSNumber(booleanLiteral: transfer)))
      }
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await signUp.update(params: params)
    #expect(requestHandled.value)
  }

  @Test(
    "All prepare strategies",
    arguments: [
      SignUp.PrepareStrategy.emailCode,
      .phoneCode
    ])
  func testPrepareVerificationRequest(strategy: SignUp.PrepareStrategy) async throws {
    let requestHandled = LockIsolated(false)
    let signUp = SignUp.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ups/\(signUp.id)/prepare_verification")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody["strategy"] == strategy.params.strategy)
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await signUp.prepareVerification(strategy: strategy)
    #expect(requestHandled.value)
  }

  @Test(
    "All attempt strategies",
    arguments: [
      SignUp.AttemptStrategy.emailCode(code: "12345"),
      .phoneCode(code: "67890")
    ])
  func testPrepareVerificationRequest(strategy: SignUp.AttemptStrategy) async throws {
    let requestHandled = LockIsolated(false)
    let signUp = SignUp.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ups/\(signUp.id)/attempt_verification")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody["strategy"] == strategy.params.strategy)
      #expect(request.urlEncodedFormBody["code"] == strategy.params.code)
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await signUp.attemptVerification(strategy: strategy)
    #expect(requestHandled.value)
  }

  @Test(arguments: [nil, UUID().uuidString])
  func testGetRequest(rotatingTokenNonce: String?) async throws {
    let requestHandled = LockIsolated(false)
    let signUp = SignUp.mock
    let originalUrl = mockBaseUrl.appending(path: "/v1/client/sign_ups/\(signUp.id)")
    var mock = Mock(
      url: originalUrl, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .get: try! JSONEncoder.clerkEncoder.encode(ClientResponse<SignUp>(response: .mock, client: .mock))
      ])
    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "GET")
      if let rotatingTokenNonce {
        #expect(request.url!.query()!.contains("rotating_token_nonce=\(rotatingTokenNonce)"))
      }
      requestHandled.setValue(true)
    }
    mock.register()
    _ = try await signUp.get(rotatingTokenNonce: rotatingTokenNonce)
    #expect(requestHandled.value)
  }
}
