#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct MfaRemovalTests {
  private func environment(secondFactors keys: [String], mfaRequired: Bool) -> Clerk.Environment {
    var environment = Clerk.Environment.mock
    environment.userSettings.signUp.mfa = .init(required: mfaRequired)
    environment.userSettings.attributes = [:]
    for key in keys {
      environment.userSettings.attributes[key] = .init(
        enabled: true,
        required: false,
        usedForFirstFactor: false,
        firstFactors: [],
        usedForSecondFactor: true,
        secondFactors: [],
        verifications: [],
        verifyAtSignUp: false
      )
    }
    return environment
  }

  private func mfaPhone(_ id: String, verified: Bool = true) -> PhoneNumber {
    var phoneNumber = PhoneNumber.mock
    phoneNumber.id = id
    phoneNumber.reservedForSecondFactor = true
    if !verified {
      phoneNumber.verification = nil
    }
    return phoneNumber
  }

  private func user(totpEnabled: Bool, phoneNumbers: [PhoneNumber]) -> User {
    var user = User.mock
    user.totpEnabled = totpEnabled
    user.phoneNumbers = phoneNumbers
    return user
  }

  @Test
  func requiredMfaKeepsTheOnlyAuthenticatorApp() {
    let environment = environment(secondFactors: ["authenticator_app", "phone_number"], mfaRequired: true)

    #expect(!environment.allowsRemovingAuthenticatorApp(for: user(totpEnabled: true, phoneNumbers: [])))
    #expect(!environment.allowsRemovingAuthenticatorApp(for: user(totpEnabled: true, phoneNumbers: [mfaPhone("1", verified: false)])))
    #expect(environment.allowsRemovingAuthenticatorApp(for: user(totpEnabled: true, phoneNumbers: [mfaPhone("1")])))
  }

  @Test
  func requiredMfaKeepsTheOnlySmsNumber() {
    let environment = environment(secondFactors: ["authenticator_app", "phone_number"], mfaRequired: true)
    let only = mfaPhone("1")

    #expect(!environment.allowsRemovingMfaPhoneNumber(only, for: user(totpEnabled: false, phoneNumbers: [only])))
    #expect(environment.allowsRemovingMfaPhoneNumber(only, for: user(totpEnabled: true, phoneNumbers: [only])))
    #expect(environment.allowsRemovingMfaPhoneNumber(only, for: user(totpEnabled: false, phoneNumbers: [only, mfaPhone("2")])))
  }

  @Test
  func anyFactorCanBeRemovedWhenMfaIsNotRequired() {
    let environment = environment(secondFactors: ["authenticator_app", "phone_number"], mfaRequired: false)
    let only = mfaPhone("1")

    #expect(environment.allowsRemovingAuthenticatorApp(for: user(totpEnabled: true, phoneNumbers: [])))
    #expect(environment.allowsRemovingMfaPhoneNumber(only, for: user(totpEnabled: false, phoneNumbers: [only])))
  }

  @Test
  func factorsOfADisabledStrategyCanAlwaysBeRemoved() {
    let smsOnly = environment(secondFactors: ["phone_number"], mfaRequired: true)
    let appOnly = environment(secondFactors: ["authenticator_app"], mfaRequired: true)
    let phone = mfaPhone("1")

    #expect(smsOnly.allowsRemovingAuthenticatorApp(for: user(totpEnabled: true, phoneNumbers: [])))
    #expect(appOnly.allowsRemovingMfaPhoneNumber(phone, for: user(totpEnabled: false, phoneNumbers: [phone])))
  }

  @Test
  func authenticatorAppOfADisabledStrategyIsNotAFallback() {
    let environment = environment(secondFactors: ["phone_number"], mfaRequired: true)
    let only = mfaPhone("1")

    #expect(!environment.allowsRemovingMfaPhoneNumber(only, for: user(totpEnabled: true, phoneNumbers: [only])))
  }
}

#endif
