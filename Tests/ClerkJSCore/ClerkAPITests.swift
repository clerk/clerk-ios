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
    #expect(clerk.session.id == nil)
    #expect(clerk.session.status != .active)
    #expect(clerk.session.user == nil)
    #expect(clerk.user == nil)
  }

  @Test
  func createParamsEncodeIdentifier() throws {
    let json = try encodeJSON(Clerk.SignIn.CreateParams(identifier: "user@example.com"))
    #expect(json["identifier"] as? String == "user@example.com")
    #expect(json.count == 1)
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
  func prepareFirstFactorParamsEncodeJSNames() throws {
    let withEmail = try encodeJSON(
      Clerk.SignIn.PrepareFirstFactorParams(strategy: .emailCode, emailAddressId: "idn_1")
    )
    #expect(withEmail["strategy"] as? String == "email_code")
    #expect(withEmail["emailAddressId"] as? String == "idn_1")
    #expect(withEmail.count == 2)

    let strategyOnly = try encodeJSON(Clerk.SignIn.PrepareFirstFactorParams(strategy: .emailCode))
    #expect(strategyOnly["strategy"] as? String == "email_code")
    #expect(strategyOnly["emailAddressId"] == nil)
    #expect(strategyOnly["phoneNumberId"] == nil)
    #expect(strategyOnly.count == 1)

    let withPhone = try encodeJSON(
      Clerk.SignIn.PrepareFirstFactorParams(strategy: .phoneCode, phoneNumberId: "idn_phone")
    )
    #expect(withPhone["strategy"] as? String == "phone_code")
    #expect(withPhone["phoneNumberId"] as? String == "idn_phone")
    #expect(withPhone["emailAddressId"] == nil)
    #expect(withPhone.count == 2)
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
  func generatedJSMethodRawValuesAreJSNames() {
    #expect(SignInJSMethod.create.rawValue == "create")
    #expect(SignInJSMethod.prepareFirstFactor.rawValue == "prepareFirstFactor")
    #expect(SignInJSMethod.attemptFirstFactor.rawValue == "attemptFirstFactor")
    #expect(SignInJSMethod.prepareSecondFactor.rawValue == "prepareSecondFactor")
    #expect(SignInJSMethod.attemptSecondFactor.rawValue == "attemptSecondFactor")
    #expect(SignUpJSMethod.create.rawValue == "create")
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
    #expect(ClerkJSPath.signUp(.create) == "__clerkInstance.client.signUp.create")
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
    #expect(clerk.session.id == nil)
    #expect(clerk.session.status != .active)
    #expect(clerk.session.user == nil)
    #expect(clerk.user == nil)
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
    #expect(clerk.user?.id == "user_fixture")
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
}

private func encodeJSON(_ value: some Encodable) throws -> [String: Any] {
  let data = try JSONEncoder().encode(value)
  return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}
