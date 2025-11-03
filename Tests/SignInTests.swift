//
//  SignInTests.swift
//  Clerk
//
//  Created by Mike Pitre on 1/1/26.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct SignInTests {

  // MARK: - Create Tests

  @Test
  @MainActor
  func testCreateWithParams() async throws {
    TestContainer.reset()

    let params: [String: String] = [
      "identifier": "test@example.com",
      "strategy": "email_code"
    ]
    _ = try? await SignIn.create(params)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/client/sign_ins"))
    #expect(verification.hasMethod("POST"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["identifier"] == "test@example.com")
    #expect(bodyParams["strategy"] == "email_code")
  }

  // MARK: - CreateStrategy Tests

  @Test("SignIn create with identifier strategy")
  @MainActor
  func testCreateIdentifier() async throws {
    TestContainer.reset()

    _ = try? await SignIn.create(strategy: .identifier("test@example.com", password: "password123"), locale: "en")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/client/sign_ins"))
    #expect(verification.hasMethod("POST"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["identifier"] == "test@example.com")
    #expect(bodyParams["password"] == "password123")
    #expect(bodyParams["locale"] == "en")
  }

  @Test("SignIn create with identifier and strategy")
  @MainActor
  func testCreateIdentifierWithStrategy() async throws {
    TestContainer.reset()

    _ = try? await SignIn.create(strategy: .identifier("test@example.com", password: nil, strategy: .emailCode()), locale: "en")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["identifier"] == "test@example.com")
    #expect(bodyParams["strategy"] == "email_code")
    #expect(bodyParams["locale"] == "en")
  }

  @Test("SignIn create with passkey strategy")
  @MainActor
  func testCreatePasskey() async throws {
    TestContainer.reset()

    _ = try? await SignIn.create(strategy: .passkey, locale: "en")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "passkey")
    #expect(bodyParams["locale"] == "en")
  }

  @Test("SignIn create with ticket strategy")
  @MainActor
  func testCreateTicket() async throws {
    TestContainer.reset()

    _ = try? await SignIn.create(strategy: .ticket("ticket_123"), locale: "en")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "ticket")
    #expect(bodyParams["ticket"] == "ticket_123")
    #expect(bodyParams["locale"] == "en")
  }

  @Test("SignIn create with transfer strategy")
  @MainActor
  func testCreateTransfer() async throws {
    TestContainer.reset()

    _ = try? await SignIn.create(strategy: .transfer, locale: "en")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["transfer"] == "1")  // URL-encoded form encodes booleans as "1" or "0"
    #expect(bodyParams["locale"] == "en")
  }

  @Test("SignIn create with none strategy")
  @MainActor
  func testCreateNone() async throws {
    TestContainer.reset()

    _ = try? await SignIn.create(strategy: .none, locale: "en")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["locale"] == "en")
  }

  @Test("SignIn create with OAuth providers", arguments: OAuthProvider.allCases.filter { $0 != .custom("") })
  @MainActor
  func testCreateOAuth(provider: OAuthProvider) async throws {
    TestContainer.reset()

    _ = try? await SignIn.create(strategy: .oauth(provider: provider, redirectUrl: "https://example.com/callback"), locale: "en")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == provider.strategy)
    #expect(bodyParams["redirect_url"] == "https://example.com/callback")
    #expect(bodyParams["locale"] == "en")
  }

  @Test("SignIn create with enterprise SSO")
  @MainActor
  func testCreateEnterpriseSSO() async throws {
    TestContainer.reset()

    _ = try? await SignIn.create(strategy: .enterpriseSSO(identifier: "user@enterprise.com", redirectUrl: "https://example.com/callback"), locale: "en")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "enterprise_sso")
    #expect(bodyParams["identifier"] == "user@enterprise.com")
    #expect(bodyParams["redirect_url"] == "https://example.com/callback")
    #expect(bodyParams["locale"] == "en")
  }

  @Test("SignIn create with ID token")
  @MainActor
  func testCreateIDToken() async throws {
    TestContainer.reset()

    _ = try? await SignIn.create(strategy: .idToken(provider: .apple, idToken: "token_123"), locale: "en")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "oauth_token_apple")
    #expect(bodyParams["token"] == "token_123")
    #expect(bodyParams["locale"] == "en")
  }

  // MARK: - Reset Password Tests

  @Test
  @MainActor
  func testResetPassword() async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    let params = SignIn.ResetPasswordParams(password: "newpassword123")
    _ = try? await signIn.resetPassword(params)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)/reset_password", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/client/sign_ins/\(signIn.id)/reset_password"))
    #expect(verification.hasMethod("POST"))

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["password"] == "newpassword123")
  }

  // MARK: - PrepareFirstFactorStrategy Tests

  @Test("SignIn prepareFirstFactor with emailCode")
  @MainActor
  func testPrepareFirstFactorEmailCode() async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    _ = try? await signIn.prepareFirstFactor(strategy: .emailCode(emailAddressId: "email_123"))

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)/prepare_first_factor", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "email_code")
    #expect(bodyParams["email_address_id"] == "email_123")
  }

  @Test("SignIn prepareFirstFactor with phoneCode")
  @MainActor
  func testPrepareFirstFactorPhoneCode() async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    _ = try? await signIn.prepareFirstFactor(strategy: .phoneCode(phoneNumberId: "phone_123"))

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)/prepare_first_factor", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "phone_code")
    #expect(bodyParams["phone_number_id"] == "phone_123")
  }

  @Test("SignIn prepareFirstFactor with passkey")
  @MainActor
  func testPrepareFirstFactorPasskey() async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    _ = try? await signIn.prepareFirstFactor(strategy: .passkey)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)/prepare_first_factor", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "passkey")
  }

  @Test("SignIn prepareFirstFactor with resetPasswordEmailCode")
  @MainActor
  func testPrepareFirstFactorResetPasswordEmailCode() async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    _ = try? await signIn.prepareFirstFactor(strategy: .resetPasswordEmailCode(emailAddressId: "email_123"))

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)/prepare_first_factor", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "reset_password_email_code")
    #expect(bodyParams["email_address_id"] == "email_123")
  }

  @Test("SignIn prepareFirstFactor with resetPasswordPhoneCode")
  @MainActor
  func testPrepareFirstFactorResetPasswordPhoneCode() async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    _ = try? await signIn.prepareFirstFactor(strategy: .resetPasswordPhoneCode(phoneNumberId: "phone_123"))

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)/prepare_first_factor", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "reset_password_phone_code")
    #expect(bodyParams["phone_number_id"] == "phone_123")
  }

  @Test("SignIn prepareFirstFactor with OAuth providers", arguments: OAuthProvider.allCases.filter { $0 != .custom("") })
  @MainActor
  func testPrepareFirstFactorOAuth(provider: OAuthProvider) async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    _ = try? await signIn.prepareFirstFactor(strategy: .oauth(provider: provider, redirectUrl: "https://example.com/callback"))

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)/prepare_first_factor", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == provider.strategy)
    #expect(bodyParams["redirect_url"] == "https://example.com/callback")
  }

  @Test("SignIn prepareFirstFactor with enterpriseSSO")
  @MainActor
  func testPrepareFirstFactorEnterpriseSSO() async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    _ = try? await signIn.prepareFirstFactor(strategy: .enterpriseSSO(redirectUrl: "https://example.com/callback"))

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)/prepare_first_factor", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "enterprise_sso")
    #expect(bodyParams["redirect_url"] == "https://example.com/callback")
  }

  // MARK: - AttemptFirstFactorStrategy Tests

  @Test("SignIn attemptFirstFactor with password")
  @MainActor
  func testAttemptFirstFactorPassword() async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    _ = try? await signIn.attemptFirstFactor(strategy: .password(password: "password123"))

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)/attempt_first_factor", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "password")
    #expect(bodyParams["password"] == "password123")
  }

  @Test("SignIn attemptFirstFactor with emailCode")
  @MainActor
  func testAttemptFirstFactorEmailCode() async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    _ = try? await signIn.attemptFirstFactor(strategy: .emailCode(code: "123456"))

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)/attempt_first_factor", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "email_code")
    #expect(bodyParams["code"] == "123456")
  }

  @Test("SignIn attemptFirstFactor with phoneCode")
  @MainActor
  func testAttemptFirstFactorPhoneCode() async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    _ = try? await signIn.attemptFirstFactor(strategy: .phoneCode(code: "123456"))

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)/attempt_first_factor", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "phone_code")
    #expect(bodyParams["code"] == "123456")
  }

  @Test("SignIn attemptFirstFactor with passkey")
  @MainActor
  func testAttemptFirstFactorPasskey() async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    _ = try? await signIn.attemptFirstFactor(strategy: .passkey(publicKeyCredential: "credential_123"))

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)/attempt_first_factor", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "passkey")
    #expect(bodyParams["public_key_credential"] == "credential_123")
  }

  @Test("SignIn attemptFirstFactor with resetPasswordEmailCode")
  @MainActor
  func testAttemptFirstFactorResetPasswordEmailCode() async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    _ = try? await signIn.attemptFirstFactor(strategy: .resetPasswordEmailCode(code: "123456"))

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)/attempt_first_factor", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "reset_password_email_code")
    #expect(bodyParams["code"] == "123456")
  }

  @Test("SignIn attemptFirstFactor with resetPasswordPhoneCode")
  @MainActor
  func testAttemptFirstFactorResetPasswordPhoneCode() async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    _ = try? await signIn.attemptFirstFactor(strategy: .resetPasswordPhoneCode(code: "123456"))

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)/attempt_first_factor", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "reset_password_phone_code")
    #expect(bodyParams["code"] == "123456")
  }

  // MARK: - PrepareSecondFactorStrategy Tests

  @Test("SignIn prepareSecondFactor with phoneCode")
  @MainActor
  func testPrepareSecondFactorPhoneCode() async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    _ = try? await signIn.prepareSecondFactor(strategy: .phoneCode)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)/prepare_second_factor", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "phone_code")
  }

  // MARK: - AttemptSecondFactorStrategy Tests

  @Test("SignIn attemptSecondFactor with phoneCode")
  @MainActor
  func testAttemptSecondFactorPhoneCode() async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    _ = try? await signIn.attemptSecondFactor(strategy: .phoneCode(code: "123456"))

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)/attempt_second_factor", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "phone_code")
    #expect(bodyParams["code"] == "123456")
  }

  @Test("SignIn attemptSecondFactor with totp")
  @MainActor
  func testAttemptSecondFactorTotp() async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    _ = try? await signIn.attemptSecondFactor(strategy: .totp(code: "123456"))

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)/attempt_second_factor", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "totp")
    #expect(bodyParams["code"] == "123456")
  }

  @Test("SignIn attemptSecondFactor with backupCode")
  @MainActor
  func testAttemptSecondFactorBackupCode() async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    _ = try? await signIn.attemptSecondFactor(strategy: .backupCode(code: "backup123"))

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)/attempt_second_factor", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let bodyParams = parseURLEncodedForm(from: request)
    #expect(bodyParams["strategy"] == "backup_code")
    #expect(bodyParams["code"] == "backup123")
  }

  // MARK: - Get Tests

  @Test
  @MainActor
  func testGet() async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    _ = try? await signIn.get(rotatingTokenNonce: nil)

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/client/sign_ins/\(signIn.id)"))
    #expect(verification.hasMethod("GET"))
  }

  @Test
  @MainActor
  func testGetWithRotatingTokenNonce() async throws {
    TestContainer.reset()

    var signIn = SignIn.mock
    _ = try? await signIn.get(rotatingTokenNonce: "token_nonce_123")

    let requests = RequestCaptureURLProtocol.getCapturedRequests()
    #expect(requests.count >= 1)

    guard let request = findLastRequest(matchingPath: "/v1/client/sign_ins/\(signIn.id)", from: requests) else {
      Issue.record("Expected request to be captured")
      return
    }

    let verification = RequestVerification(url: request)
    #expect(verification.hasPath("/v1/client/sign_ins/\(signIn.id)"))
    #expect(verification.hasMethod("GET"))
    #expect(verification.hasQueryParameter("rotating_token_nonce", value: "token_nonce_123"))
  }
}
