#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct EnvironmentAttributeAvailabilityTests {
  private nonisolated static let identifierKeys = ["email_address", "phone_number", "username"]

  private func environment(
    _ key: String,
    enabled: Bool,
    usedForFirstFactor: Bool,
    usedForSecondFactor: Bool = false
  ) -> Clerk.Environment {
    var environment = Clerk.Environment.mock
    for identifierKey in Self.identifierKeys {
      environment.userSettings.attributes[identifierKey] = nil
    }
    environment.userSettings.attributes[key] = .init(
      enabled: enabled,
      required: false,
      usedForFirstFactor: usedForFirstFactor,
      firstFactors: [],
      usedForSecondFactor: usedForSecondFactor,
      secondFactors: usedForSecondFactor ? ["phone_code"] : [],
      verifications: [],
      verifyAtSignUp: false
    )
    return environment
  }

  @Test(arguments: identifierKeys)
  func signInOnlyIdentifierIsOfferedForSignInButNotSignUp(key: String) {
    let environment = environment(key, enabled: false, usedForFirstFactor: true)

    #expect(environment.firstFactorAttributes(for: .signIn).contains(key))
    #expect(environment.firstFactorAttributes(for: .signInOrUp).contains(key))
    #expect(!environment.firstFactorAttributes(for: .signUp).contains(key))
  }

  @Test(arguments: identifierKeys)
  func identifierEnabledForSignUpAndSignInIsOfferedInEveryMode(key: String) {
    let environment = environment(key, enabled: true, usedForFirstFactor: true)

    #expect(environment.firstFactorAttributes(for: .signIn).contains(key))
    #expect(environment.firstFactorAttributes(for: .signInOrUp).contains(key))
    #expect(environment.firstFactorAttributes(for: .signUp).contains(key))
  }

  @Test(arguments: identifierKeys)
  func disabledIdentifierIsNotOfferedOrManageable(key: String) {
    let environment = environment(key, enabled: false, usedForFirstFactor: false)

    #expect(!environment.firstFactorAttributes(for: .signIn).contains(key))
    #expect(!environment.firstFactorAttributes(for: .signInOrUp).contains(key))
    #expect(!environment.firstFactorAttributes(for: .signUp).contains(key))
    #expect(!environment.emailIsAvailable)
    #expect(!environment.phoneNumberIsAvailable)
    #expect(!environment.usernameIsAvailable)
    #expect(environment.totalEnabledFirstFactorMethods == environment.authenticatableSocialProviders.count)
  }

  @Test
  func signInOnlyIdentifiersAreManageableInTheProfile() {
    #expect(environment("email_address", enabled: false, usedForFirstFactor: true).emailIsAvailable)
    #expect(environment("phone_number", enabled: false, usedForFirstFactor: true).phoneNumberIsAvailable)
    #expect(environment("username", enabled: false, usedForFirstFactor: true).usernameIsAvailable)
  }

  @Test
  func signInOnlyIdentifierCountsAsASignInMethod() {
    let environment = environment("email_address", enabled: false, usedForFirstFactor: true)

    #expect(environment.totalEnabledFirstFactorMethods == environment.authenticatableSocialProviders.count + 1)
  }

  @Test
  func phoneUsedOnlyForTwoStepIsAvailableInTheProfileButNotOnTheStartScreen() {
    let environment = environment("phone_number", enabled: false, usedForFirstFactor: false, usedForSecondFactor: true)

    #expect(!environment.firstFactorAttributes(for: .signIn).contains("phone_number"))
    #expect(!environment.firstFactorAttributes(for: .signInOrUp).contains("phone_number"))
    #expect(!environment.firstFactorAttributes(for: .signUp).contains("phone_number"))
    #expect(environment.phoneNumberIsAvailable)
    #expect(environment.mfaIsEnabled)
    #expect(environment.mfaPhoneCodeIsEnabled)
  }

  @Test
  func phoneThatIsNotASecondFactorDoesNotEnableSmsTwoStep() {
    let environment = environment("phone_number", enabled: true, usedForFirstFactor: true)

    #expect(!environment.mfaPhoneCodeIsEnabled)
  }
}

#endif
