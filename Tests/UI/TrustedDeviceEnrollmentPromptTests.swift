#if os(iOS) || os(macOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Foundation
import Testing

struct TrustedDeviceEnrollmentPromptTests {
  @Test
  func signInPromptIsSuppressedAfterItHasBeenSeen() throws {
    let (store, suiteName) = try makePromptStore()
    defer { removePromptStoreSuite(named: suiteName) }
    let result = completedSignInResult()

    #expect(result.shouldOfferTrustedDeviceEnrollmentPrompt(
      userID: "user_123",
      promptStore: store
    ))

    store.markPromptSeen(userID: "user_123")

    #expect(result.shouldOfferTrustedDeviceEnrollmentPrompt(
      userID: "user_123",
      promptStore: store
    ) == false)
  }

  @Test
  func signUpPromptIgnoresSeenState() throws {
    let (store, suiteName) = try makePromptStore()
    defer { removePromptStoreSuite(named: suiteName) }
    let result = completedSignUpResult()

    store.markPromptSeen(userID: "user_123")

    #expect(result.shouldOfferTrustedDeviceEnrollmentPrompt(
      userID: "user_123",
      promptStore: store
    ))
  }

  @Test
  func seenStateIsScopedByUser() throws {
    let (store, suiteName) = try makePromptStore()
    defer { removePromptStoreSuite(named: suiteName) }

    store.markPromptSeen(userID: "user_123")

    #expect(store.hasSeenPrompt(userID: "user_123"))
    #expect(store.hasSeenPrompt(userID: "user_456") == false)
  }

  private func makePromptStore() throws -> (TrustedDeviceEnrollmentPromptStore, String) {
    let suiteName = "com.clerk.tests.trusted-device-enrollment-prompt.\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    userDefaults.removePersistentDomain(forName: suiteName)
    return (TrustedDeviceEnrollmentPromptStore(userDefaults: userDefaults), suiteName)
  }

  private func removePromptStoreSuite(named suiteName: String) {
    UserDefaults.standard.removePersistentDomain(forName: suiteName)
    UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
  }

  private func completedSignInResult() -> TransferFlowResult {
    .signIn(SignIn(
      id: "sign_in_123",
      status: .complete,
      createdSessionId: "sess_123"
    ))
  }

  private func completedSignUpResult() -> TransferFlowResult {
    .signUp(SignUp(
      id: "sign_up_123",
      status: .complete,
      requiredFields: [],
      optionalFields: [],
      missingFields: [],
      unverifiedFields: [],
      verifications: [:],
      passwordEnabled: false,
      createdSessionId: "sess_123",
      createdUserId: "user_123",
      abandonAt: .distantFuture
    ))
  }
}

#endif
