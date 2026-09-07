@testable import ClerkJSCore
import Foundation
import Testing

struct ClerkAPITests {
  @Test
  @MainActor
  func constructsWithoutLoading() {
    let clerk = Clerk(
      publishableKey: "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk",
      tokenCache: .memory()
    )
    #expect(clerk.client.id == "")
    #expect(clerk.client.sessions.isEmpty)
    #expect(clerk.client.signIn.createdSessionId == nil)
    #expect(clerk.client.signIn.supportedSecondFactors.isEmpty)
    #expect(clerk.client.signIn.id == nil)
    #expect(clerk.client.signUp.id == nil)
    #expect(clerk.client.signUp.status == nil)
    #expect(clerk.client.signUp.createdSessionId == nil)
    #expect(clerk.session.id == nil)
    #expect(clerk.session.status != .active)
    #expect(clerk.session.user == nil)
  }

  @Test
  func createParamsEncodeIdentifier() throws {
    let json = try encodeJSON(Clerk.SignIn.CreateParams(identifier: "user@example.com"))
    #expect(json["identifier"] as? String == "user@example.com")
    #expect(json["strategy"] == nil)
    #expect(json["redirectUrl"] == nil)
    #expect(json.count == 1)
  }

  @Test
  func createParamsEncodeOAuthStrategyAndRedirectUrl() throws {
    let json = try encodeJSON(
      Clerk.SignIn.CreateParams(
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
    let ticket = try encodeJSON(Clerk.SignIn.CreateParams(strategy: "ticket", ticket: "tkt_1"))
    #expect(ticket["strategy"] as? String == "ticket")
    #expect(ticket["ticket"] as? String == "tkt_1")
    #expect(ticket.count == 2)

    let token = try encodeJSON(
      Clerk.SignIn.CreateParams(strategy: "oauth_token_apple", token: "id_token")
    )
    #expect(token["strategy"] as? String == "oauth_token_apple")
    #expect(token["token"] as? String == "id_token")
    #expect(token.count == 2)
  }

  @Test
  func authenticateWithRedirectParamsEncodeStrategyAndRedirectUrl() throws {
    let json = try encodeJSON(
      Clerk.SignIn.AuthenticateWithRedirectParams(
        strategy: "oauth_google",
        redirectUrl: "clerk://sso-callback"
      )
    )
    #expect(json["strategy"] as? String == "oauth_google")
    #expect(json["redirectUrl"] as? String == "clerk://sso-callback")
    #expect(json["redirectUrlComplete"] == nil)
    #expect(json["identifier"] == nil)
    #expect(json.count == 2)
  }

  @Test
  func authenticateWithRedirectParamsEncodeIdentifierWhenPresent() throws {
    let json = try encodeJSON(
      Clerk.SignIn.AuthenticateWithRedirectParams(
        strategy: "enterprise_sso",
        redirectUrl: "clerk://sso-callback",
        identifier: "user@example.com"
      )
    )
    #expect(json["strategy"] as? String == "enterprise_sso")
    #expect(json["redirectUrl"] as? String == "clerk://sso-callback")
    #expect(json["identifier"] as? String == "user@example.com")
    #expect(json.count == 3)
  }

  @Test
  func signUpCreateParamsEncodePresentKeysOnly() throws {
    let email = try encodeJSON(Clerk.SignUp.CreateParams(emailAddress: "user@example.com"))
    #expect(email["emailAddress"] as? String == "user@example.com")
    #expect(email["phoneNumber"] == nil)
    #expect(email["username"] == nil)
    #expect(email.count == 1)

    let phone = try encodeJSON(Clerk.SignUp.CreateParams(phoneNumber: "+15555550100"))
    #expect(phone["phoneNumber"] as? String == "+15555550100")
    #expect(phone.count == 1)

    let username = try encodeJSON(Clerk.SignUp.CreateParams(username: "ada"))
    #expect(username["username"] as? String == "ada")
    #expect(username.count == 1)

    let empty = try encodeJSON(Clerk.SignUp.CreateParams())
    #expect(empty.isEmpty)
  }

  @Test
  func signUpUpdateParamsEncodePasswordOnly() throws {
    let json = try encodeJSON(Clerk.SignUp.CreateParams(password: "hunter2"))
    #expect(json["password"] as? String == "hunter2")
    #expect(json["emailAddress"] == nil)
    #expect(json["phoneNumber"] == nil)
    #expect(json["username"] == nil)
    #expect(json.count == 1)
  }

  @Test
  func signUpUpdateParamsEncodeNamesOnly() throws {
    let json = try encodeJSON(Clerk.SignUp.CreateParams(firstName: "Ada", lastName: "Lovelace"))
    #expect(json["firstName"] as? String == "Ada")
    #expect(json["lastName"] as? String == "Lovelace")
    #expect(json["password"] == nil)
    #expect(json.count == 2)
  }

  @Test
  func signUpUpdateParamsEncodeLegalAcceptedOnly() throws {
    let json = try encodeJSON(Clerk.SignUp.CreateParams(legalAccepted: true))
    #expect(json["legalAccepted"] as? Bool == true)
    #expect(json.count == 1)
  }

  @Test
  func prepareVerificationParamsEncodeStrategyOnly() throws {
    let email = try encodeJSON(Clerk.SignUp.PrepareVerificationParams(strategy: .emailCode))
    #expect(email["strategy"] as? String == "email_code")
    #expect(email.count == 1)

    let emailLink = try encodeJSON(Clerk.SignUp.PrepareVerificationParams(strategy: .emailLink))
    #expect(emailLink["strategy"] as? String == "email_link")
    #expect(emailLink.count == 1)

    let phone = try encodeJSON(Clerk.SignUp.PrepareVerificationParams(strategy: .phoneCode))
    #expect(phone["strategy"] as? String == "phone_code")
    #expect(phone.count == 1)
  }

  @Test
  func attemptVerificationParamsEncodeStrategyAndCode() throws {
    let email = try encodeJSON(
      Clerk.SignUp.AttemptVerificationParams(strategy: .emailCode, code: "424242")
    )
    #expect(email["strategy"] as? String == "email_code")
    #expect(email["code"] as? String == "424242")
    #expect(email.count == 2)

    let phone = try encodeJSON(
      Clerk.SignUp.AttemptVerificationParams(strategy: .phoneCode, code: "424242")
    )
    #expect(phone["strategy"] as? String == "phone_code")
    #expect(phone["code"] as? String == "424242")
    #expect(phone.count == 2)
  }

  @Test
  func prepareFirstFactorParamsEncodeJSNames() throws {
    let withEmail = try encodeJSON(
      Clerk.SignIn.PrepareFirstFactorParams(strategy: .emailCode, emailAddressId: "idn_1")
    )
    #expect(withEmail["strategy"] as? String == "email_code")
    #expect(withEmail["emailAddressId"] as? String == "idn_1")
    #expect(withEmail["redirectUrl"] == nil)
    #expect(withEmail.count == 2)

    let emailLink = try encodeJSON(
      Clerk.SignIn.PrepareFirstFactorParams(
        strategy: .emailLink,
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

    let strategyOnly = try encodeJSON(Clerk.SignIn.PrepareFirstFactorParams(strategy: .emailCode))
    #expect(strategyOnly["strategy"] as? String == "email_code")
    #expect(strategyOnly["emailAddressId"] == nil)
    #expect(strategyOnly["phoneNumberId"] == nil)
    #expect(strategyOnly["redirectUrl"] == nil)
    #expect(strategyOnly.count == 1)

    let withPhone = try encodeJSON(
      Clerk.SignIn.PrepareFirstFactorParams(strategy: .phoneCode, phoneNumberId: "idn_phone")
    )
    #expect(withPhone["strategy"] as? String == "phone_code")
    #expect(withPhone["phoneNumberId"] as? String == "idn_phone")
    #expect(withPhone["emailAddressId"] == nil)
    #expect(withPhone.count == 2)

    let resetEmail = try encodeJSON(
      Clerk.SignIn.PrepareFirstFactorParams(
        strategy: .resetPasswordEmailCode,
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
      Clerk.SignIn.AttemptFirstFactorParams(strategy: .emailCode, code: "424242")
    )
    #expect(json["strategy"] as? String == "email_code")
    #expect(json["code"] as? String == "424242")
    #expect(json.count == 2)

    let phone = try encodeJSON(
      Clerk.SignIn.AttemptFirstFactorParams(strategy: .phoneCode, code: "424242")
    )
    #expect(phone["strategy"] as? String == "phone_code")
    #expect(phone["code"] as? String == "424242")
    #expect(phone.count == 2)

    let password = try encodeJSON(
      Clerk.SignIn.AttemptFirstFactorParams(strategy: .password, password: "hunter2")
    )
    #expect(password["strategy"] as? String == "password")
    #expect(password["password"] as? String == "hunter2")
    #expect(password["code"] == nil)
    #expect(password.count == 2)

    let reset = try encodeJSON(
      Clerk.SignIn.AttemptFirstFactorParams(strategy: .resetPasswordEmailCode, code: "424242")
    )
    #expect(reset["strategy"] as? String == "reset_password_email_code")
    #expect(reset["code"] as? String == "424242")
    #expect(reset["password"] == nil)
    #expect(reset.count == 2)
  }

  @Test
  func prepareSecondFactorParamsEncodePresentKeysOnly() throws {
    let withEmail = try encodeJSON(
      Clerk.SignIn.PrepareSecondFactorParams(strategy: .emailCode, emailAddressId: "idn_1")
    )
    #expect(withEmail["strategy"] as? String == "email_code")
    #expect(withEmail["emailAddressId"] as? String == "idn_1")
    #expect(withEmail["phoneNumberId"] == nil)
    #expect(withEmail.count == 2)

    let strategyOnly = try encodeJSON(Clerk.SignIn.PrepareSecondFactorParams(strategy: .phoneCode))
    #expect(strategyOnly["strategy"] as? String == "phone_code")
    #expect(strategyOnly["emailAddressId"] == nil)
    #expect(strategyOnly["phoneNumberId"] == nil)
    #expect(strategyOnly.count == 1)

    let withPhone = try encodeJSON(
      Clerk.SignIn.PrepareSecondFactorParams(strategy: .phoneCode, phoneNumberId: "idn_phone")
    )
    #expect(withPhone["strategy"] as? String == "phone_code")
    #expect(withPhone["phoneNumberId"] as? String == "idn_phone")
    #expect(withPhone["emailAddressId"] == nil)
    #expect(withPhone.count == 2)
  }

  @Test
  func attemptSecondFactorParamsEncodeJSNames() throws {
    let email = try encodeJSON(
      Clerk.SignIn.AttemptSecondFactorParams(strategy: .emailCode, code: "424242")
    )
    #expect(email["strategy"] as? String == "email_code")
    #expect(email["code"] as? String == "424242")
    #expect(email.count == 2)

    let phone = try encodeJSON(
      Clerk.SignIn.AttemptSecondFactorParams(strategy: .phoneCode, code: "424242")
    )
    #expect(phone["strategy"] as? String == "phone_code")
    #expect(phone["code"] as? String == "424242")
    #expect(phone.count == 2)

    let totp = try encodeJSON(
      Clerk.SignIn.AttemptSecondFactorParams(strategy: .totp, code: "123456")
    )
    #expect(totp["strategy"] as? String == "totp")
    #expect(totp["code"] as? String == "123456")
    #expect(totp.count == 2)

    let backup = try encodeJSON(
      Clerk.SignIn.AttemptSecondFactorParams(strategy: .backupCode, code: "abcd-efgh")
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
    let json = try encodeJSON(Clerk.SignIn.ResetPasswordParams(password: "hunter2"))
    #expect(json["password"] as? String == "hunter2")
    #expect(json["signOutOfOtherSessions"] == nil)
    #expect(json.count == 1)
  }

  @Test
  func resetPasswordParamsEncodeSignOutWhenSet() throws {
    let json = try encodeJSON(
      Clerk.SignIn.ResetPasswordParams(password: "hunter2", signOutOfOtherSessions: true)
    )
    #expect(json["password"] as? String == "hunter2")
    #expect(json["signOutOfOtherSessions"] as? Bool == true)
    #expect(json.count == 2)
  }

  @Test
  func storageNamespaceIsStablePerKey() {
    #expect(Clerk.storageNamespace(for: "pk_test_a") == Clerk.storageNamespace(for: "pk_test_a"))
    #expect(Clerk.storageNamespace(for: "pk_test_a") != Clerk.storageNamespace(for: "pk_test_b"))
  }

  @Test
  func setActiveParamsEncodeSession() throws {
    let json = try encodeJSON(Clerk.SetActiveParams(session: "sess_1"))
    #expect(json["session"] as? String == "sess_1")
    #expect(json.count == 1)
  }

  @Test
  func setActiveParamsEncodeOrganization() throws {
    let json = try encodeJSON(Clerk.SetActiveParams(session: "sess_1", organization: "org_1"))
    #expect(json["session"] as? String == "sess_1")
    #expect(json["organization"] as? String == "org_1")
  }

  @Test
  func createParamsEncodePassword() throws {
    let json = try encodeJSON(
      Clerk.SignIn.CreateParams(
        identifier: "user@example.com",
        strategy: "password",
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
  }

  @Test
  func jsMethodPathsJoinReceiverAndName() {
    #expect(ClerkJSPath.signIn(.create) == "__clerkInstance.client.signIn.create")
    #expect(ClerkJSPath.signIn(.prepareFirstFactor) == "__clerkInstance.client.signIn.prepareFirstFactor")
    #expect(ClerkJSPath.signIn(.attemptFirstFactor) == "__clerkInstance.client.signIn.attemptFirstFactor")
    #expect(ClerkJSPath.signIn(.prepareSecondFactor) == "__clerkInstance.client.signIn.prepareSecondFactor")
    #expect(ClerkJSPath.signIn(.attemptSecondFactor) == "__clerkInstance.client.signIn.attemptSecondFactor")
    #expect(ClerkJSPath.signIn(.authenticateWithPasskey) == "__clerkInstance.client.signIn.authenticateWithPasskey")
    #expect(ClerkJSPath.signIn(.resetPassword) == "__clerkInstance.client.signIn.resetPassword")
    #expect(
      ClerkJSPath.signInNamed("authenticateWithRedirect")
        == "__clerkInstance.client.signIn.authenticateWithRedirect"
    )
    #expect(ClerkJSPath.signUp(.create) == "__clerkInstance.client.signUp.create")
    #expect(ClerkJSPath.signUp(.update) == "__clerkInstance.client.signUp.update")
    #expect(ClerkJSPath.signUp(.prepareVerification) == "__clerkInstance.client.signUp.prepareVerification")
    #expect(ClerkJSPath.signUp(.attemptVerification) == "__clerkInstance.client.signUp.attemptVerification")
    #expect(ClerkJSPath.clerk(.setActive) == "__clerkInstance.setActive")
    #expect(ClerkJSPath.session(.getToken) == "__clerkInstance.session.getToken")
  }

  @Test
  @MainActor
  func unsignedClientPublishLeavesSessionEmpty() throws {
    let url = try #require(Bundle.module.url(forResource: "unsigned-client", withExtension: "json"))
    let clerk = Clerk(
      publishableKey: "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk",
      tokenCache: .memory()
    )
    try clerk.publishClient(Data(contentsOf: url))
    #expect(clerk.client.signUp.id == nil)
    #expect(clerk.client.signUp.status == nil)
    #expect(clerk.client.signUp.emailAddress == nil)
    #expect(clerk.client.signUp.missingFields.isEmpty)
    #expect(clerk.client.signUp.unverifiedFields.isEmpty)
    #expect(clerk.client.signUp.hasPassword == false)
    #expect(clerk.client.signUp.createdSessionId == nil)
    #expect(clerk.session.id == nil)
    #expect(clerk.session.status != .active)
    #expect(clerk.session.user == nil)
  }

  @Test
  @MainActor
  func signedInClientPublishExposesSessionIdAndStatus() throws {
    let clerk = Clerk(
      publishableKey: "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk",
      tokenCache: .memory()
    )
    try clerk.publishClient(Clerk.snapshotSignedInClient())
    #expect(clerk.session.id == "sess_fixture")
    #expect(clerk.session.status == .active)
    #expect(clerk.session.user?.id == "user_fixture")
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
    let clerk = Clerk(
      publishableKey: "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk",
      tokenCache: .memory()
    )
    try clerk.publishClient(JSONSerialization.data(withJSONObject: payload))
    #expect(clerk.client.signIn.id == "sia_mfa")
    #expect(clerk.client.signIn.status == .needsSecondFactor)
    #expect(clerk.client.signIn.supportedSecondFactors.count == 2)
    #expect(clerk.client.signIn.supportedSecondFactors[0].strategy == .totp)
    #expect(clerk.client.signIn.supportedSecondFactors[1].strategy == .phoneCode)
    #expect(clerk.client.signIn.supportedSecondFactors[1].phoneNumberId == "idn_phone")
    #expect(clerk.client.signIn.supportedSecondFactors[1].safeIdentifier == "+1••••••00")
    #expect(clerk.client.signIn.supportedSecondFactors[1].primary == true)
    #expect(clerk.client.signIn.supportedSecondFactors[1].default == true)
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
    let clerk = Clerk(
      publishableKey: "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk",
      tokenCache: .memory()
    )
    try clerk.publishClient(JSONSerialization.data(withJSONObject: payload))
    #expect(clerk.client.signUp.id == "sua_1")
    #expect(clerk.client.signUp.status == .complete)
    #expect(clerk.client.signUp.createdSessionId == "sess_1")
  }
}

private func encodeJSON(_ value: some Encodable) throws -> [String: Any] {
  let data = try JSONEncoder().encode(value)
  return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}
