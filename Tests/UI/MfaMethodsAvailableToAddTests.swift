#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct MfaMethodsAvailableToAddTests {
  private func environment(secondFactors keys: [String]) -> Clerk.Environment {
    var environment = Clerk.Environment.mock
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

  private func user(totpEnabled: Bool = false, twoFactorEnabled: Bool = false, backupCodeEnabled: Bool = false) -> User {
    var user = User.mock
    user.totpEnabled = totpEnabled
    user.twoFactorEnabled = twoFactorEnabled
    user.backupCodeEnabled = backupCodeEnabled
    return user
  }

  @Test
  func phoneCodeStaysAvailableSoUsersCanAddAnotherNumber() {
    let environment = environment(secondFactors: ["phone_number"])

    #expect(environment.mfaMethodsAvailableToAdd(for: user(twoFactorEnabled: true)) == [.phoneCode])
  }

  @Test
  func authenticatorAppIsOfferedUntilTheUserSetsItUp() {
    let environment = environment(secondFactors: ["authenticator_app"])

    #expect(environment.mfaMethodsAvailableToAdd(for: user()) == [.authenticatorApp])
    #expect(environment.mfaMethodsAvailableToAdd(for: user(totpEnabled: true, twoFactorEnabled: true)).isEmpty)
  }

  @Test(arguments: [
    (twoFactorEnabled: true, backupCodeEnabled: false, isOffered: true),
    (twoFactorEnabled: true, backupCodeEnabled: true, isOffered: false),
    (twoFactorEnabled: false, backupCodeEnabled: false, isOffered: false),
  ])
  func backupCodesAreOfferedToUsersWithTwoStepVerificationButNoCodes(
    twoFactorEnabled: Bool,
    backupCodeEnabled: Bool,
    isOffered: Bool
  ) {
    let environment = environment(secondFactors: ["backup_code"])
    let user = user(twoFactorEnabled: twoFactorEnabled, backupCodeEnabled: backupCodeEnabled)

    #expect(environment.mfaMethodsAvailableToAdd(for: user).contains(.backupCodes) == isOffered)
  }

  @Test
  func backupCodesAreNotOfferedWhenTheInstanceDisablesThem() {
    let environment = environment(secondFactors: ["phone_number"])

    #expect(!environment.mfaMethodsAvailableToAdd(for: user(twoFactorEnabled: true)).contains(.backupCodes))
  }

  @Test
  func nothingIsLeftWhenSmsIsOffAndTheAuthenticatorAppAndBackupCodesAreSetUp() {
    let environment = environment(secondFactors: ["authenticator_app", "backup_code"])
    let user = user(totpEnabled: true, twoFactorEnabled: true, backupCodeEnabled: true)

    #expect(environment.mfaMethodsAvailableToAdd(for: user).isEmpty)
  }
}

#endif
