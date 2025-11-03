//
//  SignUpTests.swift
//  Clerk
//
//  Created by Mike Pitre on 1/1/26.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct SignUpTests {

  // MARK: - Create Tests

  @Test
  @MainActor
  func testCreateWithParams() async throws {
    TestContainer.reset()

    let params: [String: String] = [
      "email_address": "test@example.com",
      "password": "password123"
    ]
    _ = try? await SignUp.create(params)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ups", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/client/sign_ups"))
    #expect(verification.hasMethod("POST"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["email_address"] == "test@example.com")
    #expect(bodyParams["password"] == "password123")
  }

  // MARK: - CreateStrategy Tests

  @Test("SignUp create with standard strategy")
  @MainActor
  func testCreateStandard() async throws {
    TestContainer.reset()

    _ = try? await SignUp.create(strategy: .standard(emailAddress: "test@example.com", password: "password123"), legalAccepted: true, locale: "en")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ups", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["email_address"] == "test@example.com")
    #expect(bodyParams["password"] == "password123")
    #expect(bodyParams["legal_accepted"] == "1")  // URL-encoded form encodes booleans as "1" or "0"
    #expect(bodyParams["locale"] == "en")
  }

  @Test("SignUp create with standard strategy and all fields")
  @MainActor
  func testCreateStandardAllFields() async throws {
    TestContainer.reset()

    _ = try? await SignUp.create(
      strategy: .standard(
        emailAddress: "test@example.com",
        password: "password123",
        firstName: "John",
        lastName: "Doe",
        username: "johndoe",
        phoneNumber: "+15551234567"
      ),
      legalAccepted: true,
      locale: "en"
    )

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ups", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["email_address"] == "test@example.com")
    #expect(bodyParams["password"] == "password123")
    #expect(bodyParams["first_name"] == "John")
    #expect(bodyParams["last_name"] == "Doe")
    #expect(bodyParams["username"] == "johndoe")
    #expect(bodyParams["phone_number"] == "+15551234567")
    #expect(bodyParams["legal_accepted"] == "1")
    #expect(bodyParams["locale"] == "en")
  }

  @Test("SignUp create with passkey strategy")
  @MainActor
  func testCreatePasskey() async throws {
    TestContainer.reset()

    _ = try? await SignUp.create(strategy: .standard(), legalAccepted: true, locale: "en")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ups", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["legal_accepted"] == "1")
    #expect(bodyParams["locale"] == "en")
  }

  @Test("SignUp create with ticket strategy")
  @MainActor
  func testCreateTicket() async throws {
    TestContainer.reset()

    _ = try? await SignUp.create(strategy: .ticket("ticket_123"), legalAccepted: true, locale: "en")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ups", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "ticket")
    #expect(bodyParams["ticket"] == "ticket_123")
    #expect(bodyParams["legal_accepted"] == "1")
    #expect(bodyParams["locale"] == "en")
  }

  @Test("SignUp create with transfer strategy")
  @MainActor
  func testCreateTransfer() async throws {
    TestContainer.reset()

    _ = try? await SignUp.create(strategy: .transfer, legalAccepted: true, locale: "en")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ups", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["transfer"] == "1")  // URL-encoded form encodes booleans as "1" or "0"
    #expect(bodyParams["legal_accepted"] == "1")
    #expect(bodyParams["locale"] == "en")
  }

  @Test("SignUp create with none strategy")
  @MainActor
  func testCreateNone() async throws {
    TestContainer.reset()

    _ = try? await SignUp.create(strategy: .none, legalAccepted: true, locale: "en")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ups", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["legal_accepted"] == "1")
    #expect(bodyParams["locale"] == "en")
  }

  @Test("SignUp create with OAuth providers", arguments: OAuthProvider.allCases.filter { $0 != .custom("") })
  @MainActor
  func testCreateOAuth(provider: OAuthProvider) async throws {
    TestContainer.reset()

    _ = try? await SignUp.create(strategy: .oauth(provider: provider, redirectUrl: "https://example.com/callback"), legalAccepted: true, locale: "en")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ups", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == provider.strategy)
    #expect(bodyParams["redirect_url"] == "https://example.com/callback")
    #expect(bodyParams["legal_accepted"] == "1")
    #expect(bodyParams["locale"] == "en")
  }

  @Test("SignUp create with enterprise SSO")
  @MainActor
  func testCreateEnterpriseSSO() async throws {
    TestContainer.reset()

    _ = try? await SignUp.create(strategy: .enterpriseSSO(identifier: "user@enterprise.com", redirectUrl: "https://example.com/callback"), legalAccepted: true, locale: "en")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ups", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "enterprise_sso")
    #expect(bodyParams["email_address"] == "user@enterprise.com")
    #expect(bodyParams["redirect_url"] == "https://example.com/callback")
    #expect(bodyParams["legal_accepted"] == "1")
    #expect(bodyParams["locale"] == "en")
  }

  @Test("SignUp create with ID token")
  @MainActor
  func testCreateIDToken() async throws {
    TestContainer.reset()

    _ = try? await SignUp.create(strategy: .idToken(provider: .apple, idToken: "token_123", firstName: "John", lastName: "Doe"), legalAccepted: true, locale: "en")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ups", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "oauth_token_apple")
    #expect(bodyParams["token"] == "token_123")
    #expect(bodyParams["first_name"] == "John")
    #expect(bodyParams["last_name"] == "Doe")
    #expect(bodyParams["legal_accepted"] == "1")
    #expect(bodyParams["locale"] == "en")
  }

  // MARK: - Update Tests

  @Test
  @MainActor
  func testUpdate() async throws {
    TestContainer.reset()

    let signUp = SignUp.mock
    let params = SignUp.UpdateParams(firstName: "John", lastName: "Doe")
    _ = try? await signUp.update(params: params)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ups/\(signUp.id)", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/client/sign_ups/\(signUp.id)"))
    #expect(verification.hasMethod("PATCH"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["first_name"] == "John")
    #expect(bodyParams["last_name"] == "Doe")
  }

  // MARK: - PrepareVerificationStrategy Tests

  @Test("SignUp prepareVerification with emailCode")
  @MainActor
  func testPrepareVerificationEmailCode() async throws {
    TestContainer.reset()

    let signUp = SignUp.mock
    _ = try? await signUp.prepareVerification(strategy: .emailCode)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ups/\(signUp.id)/prepare_verification", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "email_code")
  }

  @Test("SignUp prepareVerification with phoneCode")
  @MainActor
  func testPrepareVerificationPhoneCode() async throws {
    TestContainer.reset()

    let signUp = SignUp.mock
    _ = try? await signUp.prepareVerification(strategy: .phoneCode)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ups/\(signUp.id)/prepare_verification", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "phone_code")
  }

  // MARK: - AttemptVerificationStrategy Tests

  @Test("SignUp attemptVerification with emailCode")
  @MainActor
  func testAttemptVerificationEmailCode() async throws {
    TestContainer.reset()

    let signUp = SignUp.mock
    _ = try? await signUp.attemptVerification(strategy: .emailCode(code: "123456"))

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ups/\(signUp.id)/attempt_verification", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "email_code")
    #expect(bodyParams["code"] == "123456")
  }

  @Test("SignUp attemptVerification with phoneCode")
  @MainActor
  func testAttemptVerificationPhoneCode() async throws {
    TestContainer.reset()

    let signUp = SignUp.mock
    _ = try? await signUp.attemptVerification(strategy: .phoneCode(code: "123456"))

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ups/\(signUp.id)/attempt_verification", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "phone_code")
    #expect(bodyParams["code"] == "123456")
  }

  // MARK: - Get Tests

  @Test
  @MainActor
  func testGet() async throws {
    TestContainer.reset()

    let signUp = SignUp.mock
    _ = try? await signUp.get(rotatingTokenNonce: nil)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ups/\(signUp.id)", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/client/sign_ups/\(signUp.id)"))
    #expect(verification.hasMethod("GET"))
  }

  @Test
  @MainActor
  func testGetWithRotatingTokenNonce() async throws {
    TestContainer.reset()

    let signUp = SignUp.mock
    _ = try? await signUp.get(rotatingTokenNonce: "token_nonce_123")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ups/\(signUp.id)", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/client/sign_ups/\(signUp.id)"))
    #expect(verification.hasMethod("GET"))
    #expect(verification.hasQueryParameter("rotating_token_nonce", value: "token_nonce_123"))
  }
}
