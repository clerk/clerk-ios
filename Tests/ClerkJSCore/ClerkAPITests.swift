@testable import ClerkJSCore
import Foundation
import Testing

struct ClerkAPITests {
  @Test
  @MainActor
  func constructsWithoutLoading() {
    let clerk = ClerkJSHost(
      publishableKey: "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk",
      tokenCache: .memory()
    )
    #expect(clerk.state == nil)
    #expect(clerk.client == nil)
    #expect(clerk.environment == nil)
  }

  @Test
  func createParamsEncodeIdentifier() throws {
    let json = try encodeJSON(SignInCreateParams(identifier: "user@example.com"))
    #expect(json["identifier"] as? String == "user@example.com")
    #expect(json["strategy"] == nil)
    #expect(json["redirectUrl"] == nil)
    #expect(json.count == 1)
  }

  @Test
  func createParamsEncodeOAuthStrategyAndRedirectUrl() throws {
    let json = try encodeJSON(
      SignInCreateParams(
        strategy: "oauth_google",
        redirectUrl: "clerk://sso-callback"
      )
    )
    #expect(json["strategy"] as? String == "oauth_google")
    #expect(json["redirectUrl"] as? String == "clerk://sso-callback")
    #expect(json["identifier"] == nil)
    #expect(json.count == 2)
  }

  @Test
  func createParamsEncodeTicketAndToken() throws {
    let ticket = try encodeJSON(SignInCreateParams(strategy: "ticket", ticket: "tkt_1"))
    #expect(ticket["strategy"] as? String == "ticket")
    #expect(ticket["ticket"] as? String == "tkt_1")
    #expect(ticket.count == 2)

    let token = try encodeJSON(
      SignInCreateParams(strategy: "oauth_token_apple", token: "id_token")
    )
    #expect(token["strategy"] as? String == "oauth_token_apple")
    #expect(token["token"] as? String == "id_token")
    #expect(token.count == 2)
  }

  @Test
  func createParamsEncodeTransfer() throws {
    let json = try encodeJSON(SignInCreateParams(transfer: true))
    #expect(json["transfer"] as? Bool == true)
    #expect(json["identifier"] == nil)
    #expect(json.count == 1)
  }

  @Test
  func prepareFirstFactorParamsEncodeJSNames() throws {
    let withEmail = try encodeJSON(
      PrepareFirstFactorParams(strategy: "email_code", emailAddressId: "idn_1")
    )
    #expect(withEmail["strategy"] as? String == "email_code")
    #expect(withEmail["emailAddressId"] as? String == "idn_1")
    #expect(withEmail["redirectUrl"] == nil)
    #expect(withEmail.count == 2)

    let emailLink = try encodeJSON(
      PrepareFirstFactorParams(
        strategy: "email_link",
        emailAddressId: "idn_1",
        redirectUrl: "clerk://sso-callback",
        codeChallenge: "challenge",
        codeChallengeMethod: "S256"
      )
    )
    #expect(emailLink["strategy"] as? String == "email_link")
    #expect(emailLink["emailAddressId"] as? String == "idn_1")
    #expect(emailLink["redirectUrl"] as? String == "clerk://sso-callback")
    #expect(emailLink["codeChallenge"] as? String == "challenge")
    #expect(emailLink["codeChallengeMethod"] as? String == "S256")
    #expect(emailLink.count == 5)

    let strategyOnly = try encodeJSON(PrepareFirstFactorParams(strategy: "email_code"))
    #expect(strategyOnly["strategy"] as? String == "email_code")
    #expect(strategyOnly["emailAddressId"] == nil)
    #expect(strategyOnly["phoneNumberId"] == nil)
    #expect(strategyOnly["redirectUrl"] == nil)
    #expect(strategyOnly.count == 1)

    let withPhone = try encodeJSON(
      PrepareFirstFactorParams(strategy: "phone_code", phoneNumberId: "idn_phone")
    )
    #expect(withPhone["strategy"] as? String == "phone_code")
    #expect(withPhone["phoneNumberId"] as? String == "idn_phone")
    #expect(withPhone["emailAddressId"] == nil)
    #expect(withPhone.count == 2)

    let resetEmail = try encodeJSON(
      PrepareFirstFactorParams(
        strategy: "reset_password_email_code",
        emailAddressId: "idn_1"
      )
    )
    #expect(resetEmail["strategy"] as? String == "reset_password_email_code")
    #expect(resetEmail["emailAddressId"] as? String == "idn_1")
    #expect(resetEmail["password"] == nil)
    #expect(resetEmail.count == 2)
  }

  @Test
  func attemptFirstFactorParamsEncodeJSNames() throws {
    let json = try encodeJSON(
      AttemptFirstFactorParams(strategy: .emailCode, code: "424242")
    )
    #expect(json["strategy"] as? String == "email_code")
    #expect(json["code"] as? String == "424242")
    #expect(json.count == 2)

    let phone = try encodeJSON(
      AttemptFirstFactorParams(strategy: .phoneCode, code: "424242")
    )
    #expect(phone["strategy"] as? String == "phone_code")
    #expect(phone["code"] as? String == "424242")
    #expect(phone.count == 2)

    let password = try encodeJSON(
      AttemptFirstFactorParams(strategy: .password, password: "hunter2")
    )
    #expect(password["strategy"] as? String == "password")
    #expect(password["password"] as? String == "hunter2")
    #expect(password["code"] == nil)
    #expect(password.count == 2)

    let reset = try encodeJSON(
      AttemptFirstFactorParams(strategy: .resetPasswordEmailCode, code: "424242")
    )
    #expect(reset["strategy"] as? String == "reset_password_email_code")
    #expect(reset["code"] as? String == "424242")
    #expect(reset["password"] == nil)
    #expect(reset.count == 2)
  }

  @Test
  func prepareSecondFactorParamsEncodePresentKeysOnly() throws {
    let withEmail = try encodeJSON(
      PrepareSecondFactorParams(strategy: .emailCode, emailAddressId: "idn_1")
    )
    #expect(withEmail["strategy"] as? String == "email_code")
    #expect(withEmail["emailAddressId"] as? String == "idn_1")
    #expect(withEmail["phoneNumberId"] == nil)
    #expect(withEmail.count == 2)

    let strategyOnly = try encodeJSON(PrepareSecondFactorParams(strategy: .phoneCode))
    #expect(strategyOnly["strategy"] as? String == "phone_code")
    #expect(strategyOnly["emailAddressId"] == nil)
    #expect(strategyOnly["phoneNumberId"] == nil)
    #expect(strategyOnly.count == 1)

    let withPhone = try encodeJSON(
      PrepareSecondFactorParams(strategy: .phoneCode, phoneNumberId: "idn_phone")
    )
    #expect(withPhone["strategy"] as? String == "phone_code")
    #expect(withPhone["phoneNumberId"] as? String == "idn_phone")
    #expect(withPhone["emailAddressId"] == nil)
    #expect(withPhone.count == 2)
  }

  @Test
  func attemptSecondFactorParamsEncodeJSNames() throws {
    let email = try encodeJSON(
      AttemptSecondFactorParams(strategy: .emailCode, code: "424242")
    )
    #expect(email["strategy"] as? String == "email_code")
    #expect(email["code"] as? String == "424242")
    #expect(email.count == 2)

    let phone = try encodeJSON(
      AttemptSecondFactorParams(strategy: .phoneCode, code: "424242")
    )
    #expect(phone["strategy"] as? String == "phone_code")
    #expect(phone["code"] as? String == "424242")
    #expect(phone.count == 2)

    let totp = try encodeJSON(
      AttemptSecondFactorParams(strategy: .totp, code: "123456")
    )
    #expect(totp["strategy"] as? String == "totp")
    #expect(totp["code"] as? String == "123456")
    #expect(totp.count == 2)

    let backup = try encodeJSON(
      AttemptSecondFactorParams(strategy: .backupCode, code: "abcd-efgh")
    )
    #expect(backup["strategy"] as? String == "backup_code")
    #expect(backup["code"] as? String == "abcd-efgh")
    #expect(backup.count == 2)
  }

  @Test
  func authenticateWithPasskeyParamsOmitNilFlow() throws {
    let omitted = try encodeJSON(AuthenticateWithPasskeyParams(flow: nil))
    #expect(omitted["flow"] == nil)
    #expect(omitted.isEmpty)

    let autofill = try encodeJSON(AuthenticateWithPasskeyParams(flow: .autofill))
    #expect(autofill["flow"] as? String == "autofill")
    #expect(autofill.count == 1)

    let discoverable = try encodeJSON(AuthenticateWithPasskeyParams(flow: .discoverable))
    #expect(discoverable["flow"] as? String == "discoverable")
    #expect(discoverable.count == 1)
  }

  @Test
  func resetPasswordParamsEncodePasswordOnlyWhenBoolOmitted() throws {
    let json = try encodeJSON(ResetPasswordParams(password: "hunter2"))
    #expect(json["password"] as? String == "hunter2")
    #expect(json["signOutOfOtherSessions"] == nil)
    #expect(json.count == 1)
  }

  @Test
  func resetPasswordParamsEncodeSignOutWhenSet() throws {
    let json = try encodeJSON(
      ResetPasswordParams(password: "hunter2", signOutOfOtherSessions: true)
    )
    #expect(json["password"] as? String == "hunter2")
    #expect(json["signOutOfOtherSessions"] as? Bool == true)
    #expect(json.count == 2)
  }

  @Test
  func storageNamespaceIsStablePerKey() {
    #expect(ClerkJSHost.storageNamespace(for: "pk_test_a") == ClerkJSHost.storageNamespace(for: "pk_test_a"))
    #expect(ClerkJSHost.storageNamespace(for: "pk_test_a") != ClerkJSHost.storageNamespace(for: "pk_test_b"))
  }

  @Test
  func createParamsEncodePassword() throws {
    let json = try encodeJSON(
      SignInCreateParams(
        strategy: "password",
        identifier: "user@example.com",
        password: "hunter2"
      )
    )
    #expect(json["identifier"] as? String == "user@example.com")
    #expect(json["strategy"] as? String == "password")
    #expect(json["password"] as? String == "hunter2")
  }

  @Test
  func generatedJSMethodRawValuesAreJSNames() {
    #expect(SignInJSMethod.create.rawValue == "create")
    #expect(SignInJSMethod.prepareFirstFactor.rawValue == "prepareFirstFactor")
    #expect(SignInJSMethod.attemptFirstFactor.rawValue == "attemptFirstFactor")
    #expect(SignInJSMethod.prepareSecondFactor.rawValue == "prepareSecondFactor")
    #expect(SignInJSMethod.attemptSecondFactor.rawValue == "attemptSecondFactor")
    #expect(SignInJSMethod.authenticateWithPasskey.rawValue == "authenticateWithPasskey")
    #expect(SignInJSMethod.resetPassword.rawValue == "resetPassword")
    #expect(SignUpJSMethod.create.rawValue == "create")
    #expect(SignUpJSMethod.update.rawValue == "update")
    #expect(SignUpJSMethod.prepareVerification.rawValue == "prepareVerification")
    #expect(SignUpJSMethod.attemptVerification.rawValue == "attemptVerification")
    #expect(ClerkJSMethod.setActive.rawValue == "setActive")
    #expect(SessionJSMethod.getToken.rawValue == "getToken")
    #expect(SessionJSMethod.startVerification.rawValue == "startVerification")
    #expect(SessionJSMethod.prepareFirstFactorVerification.rawValue == "prepareFirstFactorVerification")
    #expect(SessionJSMethod.attemptFirstFactorVerification.rawValue == "attemptFirstFactorVerification")
    #expect(SessionJSMethod.prepareSecondFactorVerification.rawValue == "prepareSecondFactorVerification")
    #expect(SessionJSMethod.attemptSecondFactorVerification.rawValue == "attemptSecondFactorVerification")
    #expect(SessionJSMethod.verifyWithPasskey.rawValue == "verifyWithPasskey")
  }

  @Test
  @MainActor
  func unsignedClientPublishLeavesSessionEmpty() throws {
    let url = try #require(Bundle.module.url(forResource: "unsigned-client", withExtension: "json"))
    let client = try FAPIJSON.decodeClient(Data(contentsOf: url))
    #expect(client.signUp == nil)
    #expect(client.sessions.isEmpty)
    #expect(client.lastActiveSessionId == nil)
  }

  @Test
  @MainActor
  func signedInClientPublishExposesSessionIdAndStatus() throws {
    let client = try FAPIJSON.decodeClient(ClerkJSHost.snapshotSignedInClient())
    let session = try #require(client.sessions.first { $0.id == client.lastActiveSessionId })
    #expect(session.id == "sess_fixture")
    #expect(session.status == .active)
    #expect(session.user.id == "user_fixture")
  }

  @Test
  @MainActor
  func publishedSignInExposesSupportedSecondFactors() throws {
    let payload: [String: Any] = [
      "object": "client",
      "id": "client_fixture",
      "sessions": [Any](),
      "sign_in": [
        "object": "sign_in",
        "id": "sia_mfa",
        "status": "needs_second_factor",
        "supported_identifiers": ["email_address"],
        "identifier": "user@example.com",
        "user_data": NSNull(),
        "supported_first_factors": [Any](),
        "supported_second_factors": [
          [
            "strategy": "totp",
          ],
          [
            "strategy": "phone_code",
            "phone_number_id": "idn_phone",
            "safe_identifier": "+1••••••00",
            "primary": true,
            "default": true,
          ],
        ],
        "first_factor_verification": NSNull(),
        "second_factor_verification": NSNull(),
        "created_session_id": NSNull(),
        "created_at": 1_700_000_000_000,
        "updated_at": 1_700_000_000_000,
      ],
      "sign_up": NSNull(),
      "last_active_session_id": NSNull(),
      "created_at": 1_700_000_000_000,
      "updated_at": 1_700_000_000_000,
    ]
    let client = try FAPIJSON.decodeClient(JSONSerialization.data(withJSONObject: payload))
    let resource = try #require(client.signIn)
    #expect(resource.id == "sia_mfa")
    #expect(resource.status == .needsSecondFactor)
    #expect(resource.supportedSecondFactors.count == 2)
    #expect(resource.supportedSecondFactors[0].strategy == .totp)
    #expect(resource.supportedSecondFactors[1].strategy == .phoneCode)
    #expect(resource.supportedSecondFactors[1].phoneNumberId == "idn_phone")
    #expect(resource.supportedSecondFactors[1].safeIdentifier == "+1••••••00")
    #expect(resource.supportedSecondFactors[1].primary == true)
    #expect(resource.supportedSecondFactors[1].default == true)
  }

  @Test
  @MainActor
  func publishedSignUpExposesCreatedSessionId() throws {
    let payload: [String: Any] = [
      "object": "client",
      "id": "client_fixture",
      "sessions": [Any](),
      "sign_in": NSNull(),
      "sign_up": [
        "object": "sign_up",
        "id": "sua_1",
        "status": "complete",
        "required_fields": [Any](),
        "optional_fields": [Any](),
        "missing_fields": [Any](),
        "unverified_fields": [Any](),
        "external_account": [String: Any](),
        "has_password": false,
        "unsafe_metadata": [String: Any](),
        "created_session_id": "sess_1",
      ],
      "last_active_session_id": NSNull(),
      "created_at": 1_700_000_000_000,
      "updated_at": 1_700_000_000_000,
    ]
    let client = try FAPIJSON.decodeClient(JSONSerialization.data(withJSONObject: payload))
    let resource = try #require(client.signUp)
    #expect(resource.id == "sua_1")
    #expect(resource.status == .complete)
    #expect(resource.createdSessionId == "sess_1")
  }
}

private func encodeJSON(_ value: some Encodable) throws -> [String: Any] {
  let data = try JSONEncoder().encode(value)
  return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}
