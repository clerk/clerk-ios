#if os(iOS) || os(macOS)

import ClerkJSCore
@testable import ClerkKit
@testable import ClerkKitUI
import Testing

struct JSCoreAuthMappingTests {
  @Test
  func mapsEmailCodeFirstFactor() {
    let factor = JSCoreAuthMapping.factor(from: firstFactor(
      strategy: "email_code",
      emailAddressId: "idn_1",
      safeIdentifier: "user@example.com",
      primary: true
    ))

    #expect(factor.strategy == .emailCode)
    #expect(factor.emailAddressId == "idn_1")
    #expect(factor.safeIdentifier == "user@example.com")
    #expect(factor.primary == true)
  }

  @Test
  func mapsEnterpriseSSOAndUnknownStrategies() {
    #expect(JSCoreAuthMapping.factor(from: firstFactor(strategy: "enterprise_sso")).strategy == .enterpriseSSO)
    #expect(JSCoreAuthMapping.factor(from: firstFactor(strategy: "future_factor")).strategy == .unknown("future_factor"))
  }

  @Test
  func mapsSignInStatusIncludingProtectCheck() {
    #expect(JSCoreAuthMapping.signInStatus(from: .needsIdentifier) == .needsIdentifier)
    #expect(JSCoreAuthMapping.signInStatus(from: .needsFirstFactor) == .needsFirstFactor)
    #expect(JSCoreAuthMapping.signInStatus(from: .needsSecondFactor) == .needsSecondFactor)
    #expect(JSCoreAuthMapping.signInStatus(from: .needsClientTrust) == .needsClientTrust)
    #expect(JSCoreAuthMapping.signInStatus(from: .needsNewPassword) == .needsNewPassword)
    #expect(JSCoreAuthMapping.signInStatus(from: .complete) == .complete)
    #expect(JSCoreAuthMapping.signInStatus(from: .needsProtectCheck) == .unknown("needs_protect_check"))
    #expect(JSCoreAuthMapping.signInStatus(from: .unknown("future_status")) == .unknown("future_status"))
  }

  @Test
  func mapsSignUpStatus() {
    #expect(JSCoreAuthMapping.signUpStatus(from: .abandoned) == .abandoned)
    #expect(JSCoreAuthMapping.signUpStatus(from: .complete) == .complete)
    #expect(JSCoreAuthMapping.signUpStatus(from: .missingRequirements) == .missingRequirements)
    #expect(JSCoreAuthMapping.signUpStatus(from: .unknown("future_status")) == .unknown("future_status"))
  }

  @Test
  func mappedSignInCarriesFactorsForNavigation() {
    let signIn = JSCoreAuthMapping.signIn(
      id: "sia_1",
      status: .needsFirstFactor,
      identifier: "user@example.com",
      firstFactors: [
        firstFactor(strategy: "email_code", emailAddressId: "idn_1", safeIdentifier: "user@example.com"),
      ]
    )

    #expect(signIn.id == "sia_1")
    #expect(signIn.status == .needsFirstFactor)
    #expect(signIn.identifier == "user@example.com")
    #expect(signIn.supportedFirstFactors?.count == 1)
    #expect(signIn.supportedFirstFactors?.first?.strategy == .emailCode)
    #expect(signIn.createdSessionId == nil)
  }

  @Test
  func mapsSecondFactorStrategyAndIdentifiers() {
    let totp = JSCoreAuthMapping.factor(from: secondFactor(strategy: .totp))
    #expect(totp.strategy == .totp)

    let phone = JSCoreAuthMapping.factor(from: secondFactor(
      strategy: .phoneCode,
      safeIdentifier: "+1••••••00",
      primary: true,
      phoneNumberId: "idn_phone",
      default: true
    ))
    #expect(phone.strategy == .phoneCode)
    #expect(phone.phoneNumberId == "idn_phone")
    #expect(phone.safeIdentifier == "+1••••••00")
    #expect(phone.primary == true)
    #expect(phone.default == true)

    #expect(JSCoreAuthMapping.factor(from: secondFactor(strategy: .emailCode)).strategy == .emailCode)
    #expect(JSCoreAuthMapping.factor(from: secondFactor(strategy: .backupCode)).strategy == .backupCode)
    #expect(JSCoreAuthMapping.factor(from: secondFactor(strategy: .unknown("future_mfa"))).strategy == .unknown("future_mfa"))
  }

  @Test
  func mappedNeedsSecondFactorCarriesSecondFactors() {
    let signIn = JSCoreAuthMapping.signIn(
      id: "sia_1",
      status: .needsSecondFactor,
      identifier: "user@example.com",
      firstFactors: [],
      secondFactors: [
        secondFactor(strategy: .totp),
        secondFactor(strategy: .phoneCode, phoneNumberId: "idn_phone"),
      ]
    )

    #expect(signIn.status == .needsSecondFactor)
    #expect(signIn.supportedSecondFactors?.count == 2)
    #expect(signIn.supportedSecondFactors?[0].strategy == .totp)
    #expect(signIn.supportedSecondFactors?[1].strategy == .phoneCode)
    #expect(signIn.supportedSecondFactors?[1].phoneNumberId == "idn_phone")
    #expect(signIn.startingSecondFactor?.strategy == .totp)
  }

  @Test
  func mappedSignInCarriesCreatedSessionId() {
    let signIn = JSCoreAuthMapping.signIn(
      id: "sia_1",
      status: .complete,
      identifier: "user@example.com",
      firstFactors: [],
      createdSessionId: "sess_1"
    )

    #expect(signIn.id == "sia_1")
    #expect(signIn.status == .complete)
    #expect(signIn.createdSessionId == "sess_1")
  }

  @Test
  func mappedSignUpCarriesFieldsForNavigation() {
    let signUp = JSCoreAuthMapping.signUp(
      id: "sua_1",
      status: .missingRequirements,
      emailAddress: "user@example.com",
      phoneNumber: nil,
      username: nil,
      missingFields: ["password"],
      unverifiedFields: ["email_address"]
    )

    #expect(signUp.id == "sua_1")
    #expect(signUp.status == .missingRequirements)
    #expect(signUp.emailAddress == "user@example.com")
    #expect(signUp.missingFields == [.password])
    #expect(signUp.unverifiedFields == [.emailAddress])
  }

  @Test
  func parsesIdentifierNotFoundFromJSAndAPIErrors() {
    #expect(
      JSCoreAuthMapping.isIdentifierNotFound(
        ClerkJSCoreError.javascript("form_identifier_not_found: Couldn't find your account.")
      )
    )
    #expect(
      JSCoreAuthMapping.isIdentifierNotFound(
        ClerkJSCoreError.javascript("invitation_account_not_exists")
      )
    )
    #expect(
      JSCoreAuthMapping.isIdentifierNotFound(
        ClerkKit.ClerkAPIError(code: "form_identifier_not_found", message: nil, longMessage: nil, meta: nil, clerkTraceId: nil)
      )
    )
    #expect(
      !JSCoreAuthMapping.isIdentifierNotFound(
        ClerkJSCoreError.javascript("form_password_incorrect: Password is incorrect.")
      )
    )
    #expect(!JSCoreAuthMapping.isIdentifierNotFound(ClerkJSCoreError.cancelled))
  }
}

private func secondFactor(
  strategy: SignInSecondFactorStrategy,
  emailAddressId: String? = nil,
  safeIdentifier: String? = nil,
  primary: Bool? = nil,
  phoneNumberId: String? = nil,
  default: Bool? = nil
) -> SignInSecondFactor {
  SignInSecondFactor(
    strategy: strategy,
    emailAddressId: emailAddressId,
    safeIdentifier: safeIdentifier,
    primary: primary,
    phoneNumberId: phoneNumberId,
    default: `default`,
    channel: nil
  )
}

private func firstFactor(
  strategy: String,
  emailAddressId: String? = nil,
  safeIdentifier: String? = nil,
  primary: Bool? = nil,
  phoneNumberId: String? = nil
) -> SignInFirstFactor {
  SignInFirstFactor(
    strategy: strategy,
    emailAddressId: emailAddressId,
    safeIdentifier: safeIdentifier,
    primary: primary,
    phoneNumberId: phoneNumberId,
    default: nil,
    channel: nil,
    web3WalletId: nil,
    walletName: nil,
    enterpriseConnectionId: nil,
    enterpriseConnectionName: nil
  )
}

#endif
