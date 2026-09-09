#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Foundation
import Testing

@MainActor
struct BiometricCredentialEnrollmentPromptTests {
  private let clerk = Clerk.preview(.signedOut)
  @Test
  func signInPromptIsSuppressedAfterItHasBeenSeen() throws {
    let (store, suiteName) = try makePromptStore()
    defer { removePromptStoreSuite(named: suiteName) }
    let result = completedSignInResult()

    #expect(result.shouldOfferBiometricCredentialEnrollmentPrompt(
      userID: "user_123",
      nativeSettings: nativeSettings(promptAfterSignIn: true),
      promptStore: store
    ))

    store.markPromptSeen(userID: "user_123")

    #expect(result.shouldOfferBiometricCredentialEnrollmentPrompt(
      userID: "user_123",
      nativeSettings: nativeSettings(promptAfterSignIn: true),
      promptStore: store
    ) == false)
  }

  @Test
  func signUpPromptIgnoresSeenState() throws {
    let (store, suiteName) = try makePromptStore()
    defer { removePromptStoreSuite(named: suiteName) }
    let result = completedSignUpResult()

    store.markPromptSeen(userID: "user_123")

    #expect(result.shouldOfferBiometricCredentialEnrollmentPrompt(
      userID: "user_123",
      nativeSettings: nativeSettings(promptAfterSignUp: true),
      promptStore: store
    ))
  }

  @Test
  func signInPromptIsSuppressedWhenEnvironmentSettingIsDisabled() throws {
    let (store, suiteName) = try makePromptStore()
    defer { removePromptStoreSuite(named: suiteName) }
    let result = completedSignInResult()

    #expect(result.shouldOfferBiometricCredentialEnrollmentPrompt(
      userID: "user_123",
      nativeSettings: nativeSettings(promptAfterSignIn: false),
      promptStore: store
    ) == false)
  }

  @Test
  func signUpPromptIsSuppressedWhenEnvironmentSettingIsDisabled() throws {
    let (store, suiteName) = try makePromptStore()
    defer { removePromptStoreSuite(named: suiteName) }
    let result = completedSignUpResult()

    #expect(result.shouldOfferBiometricCredentialEnrollmentPrompt(
      userID: "user_123",
      nativeSettings: nativeSettings(promptAfterSignUp: false),
      promptStore: store
    ) == false)
  }

  @Test
  func seenStateIsScopedByUser() throws {
    let (store, suiteName) = try makePromptStore()
    defer { removePromptStoreSuite(named: suiteName) }

    store.markPromptSeen(userID: "user_123")

    #expect(store.hasSeenPrompt(userID: "user_123"))
    #expect(store.hasSeenPrompt(userID: "user_456") == false)
  }

  private func makePromptStore() throws -> (BiometricCredentialEnrollmentPromptStore, String) {
    let suiteName = "com.clerk.tests.biometric-credential-enrollment-prompt.\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    userDefaults.removePersistentDomain(forName: suiteName)
    return (BiometricCredentialEnrollmentPromptStore(userDefaults: userDefaults), suiteName)
  }

  private func removePromptStoreSuite(named suiteName: String) {
    UserDefaults.standard.removePersistentDomain(forName: suiteName)
    UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
  }

  private func nativeSettings(
    promptAfterSignIn: Bool = false,
    promptAfterSignUp: Bool = false
  ) -> NativeAuthSettings {
    .init(
      apiEnabled: true,
      trustedDeviceSignInEnabled: true,
      trustedDeviceEnrollmentPromptAfterSignInEnabled: promptAfterSignIn,
      trustedDeviceEnrollmentPromptAfterSignUpEnabled: promptAfterSignUp
    )
  }

  private func completedSignInResult() -> TransferFlowResult {
    var state = try! clerk.signIn.state.encode().object()
    state["id"] = .string("sign_in_123")
    state["status"] = .string("complete")
    state["createdSessionId"] = .string("sess_123")
    setTestResourceState(clerk.signIn, encoded: .object(state), path: [], value: .object(state))
    return .signIn(clerk.signIn)
  }

  private func completedSignUpResult() -> TransferFlowResult {
    var state = try! clerk.signUp.state.encode().object()
    state["id"] = .string("sign_up_123")
    state["status"] = .string("complete")
    state["createdSessionId"] = .string("sess_123")
    setTestResourceState(clerk.signUp, encoded: .object(state), path: [], value: .object(state))
    return .signUp(clerk.signUp)
  }
}
#endif
