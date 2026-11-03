#if os(iOS)

@testable import ClerkKit
@_spi(FrameworkIntegration) @testable import ClerkKitUI
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct AuthSensitiveFieldsTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func returningToTheStartScreenClearsEnteredSecrets() async throws {
    let view = AuthView()
    let authState = view.authState
    let navigation = view.navigation
    let window = try await show(view)
    defer { hide(window) }

    // AuthView's state persists the identifier to the standard defaults.
    let storedIdentifier = UserDefaults.standard.string(forKey: AuthState.identifierStorageKey)
    defer { UserDefaults.standard.set(storedIdentifier, forKey: AuthState.identifierStorageKey) }

    navigation.path = [.signInForgotPassword]
    try await layout(window)
    authState.authStartIdentifier = "a@example.com"
    enterSecrets(into: authState)

    navigation.path = []
    try await layout(window)

    #expect(authState.signInPassword.isEmpty)
    #expect(authState.signInNewPassword.isEmpty)
    #expect(authState.signInConfirmNewPassword.isEmpty)
    #expect(authState.signInBackupCode.isEmpty)
    #expect(authState.signUpPassword.isEmpty)
    #expect(authState.authStartIdentifier == "a@example.com")
  }

  @Test
  func movingBetweenLaterStepsKeepsEnteredSecrets() async throws {
    let view = AuthView()
    let authState = view.authState
    let navigation = view.navigation
    let window = try await show(view)
    defer { hide(window) }

    navigation.path = [.signInForgotPassword]
    try await layout(window)
    enterSecrets(into: authState)

    navigation.path = [.signInForgotPassword, .signInSetNewPassword(token: nil)]
    try await layout(window)
    navigation.path = [.signInForgotPassword]
    try await layout(window)

    #expect(authState.signInPassword == "password-for-a")
    #expect(authState.signInNewPassword == "new-password-for-a")
  }

  @Test
  func signingOutDuringAPostAuthStepClearsEnteredSecrets() async throws {
    let clerk = Clerk.mock
    let view = AuthView()
    let authState = view.authState
    let navigation = view.navigation
    let window = try await show(view, clerk: clerk)
    defer { hide(window) }

    let token = AuthFlowPresentationToken(
      work: AuthFlowWork(ownerId: UUID(), id: UUID(), sessionId: Session.mock.id),
      id: UUID(),
      kind: .biometricCredentialEnrollment
    )
    navigation.path = [
      .signInForgotPassword,
      .biometricCredentialEnrollment(biometryDisplayName: .init(biometryType: .faceID), token: token),
    ]
    try await layout(window)
    enterSecrets(into: authState)
    enterSignUpDetails(into: authState)

    clerk.setClientFromIdentityController(.mockSignedOut)
    try await layout(window)

    #expect(authState.signInPassword.isEmpty)
    #expect(authState.signInNewPassword.isEmpty)
    #expect(authState.signInConfirmNewPassword.isEmpty)
    #expect(authState.signInBackupCode.isEmpty)
    #expect(authState.signUpPassword.isEmpty)
    #expect(authState.signUpEmailAddress.isEmpty)
    #expect(authState.signUpLegalAccepted == false)
  }

  @Test(arguments: [true, false])
  func completingTheFlowClearsEnteredSecretsOnlyAfterTheSavePasswordWindow(isDismissible: Bool) async throws {
    let clerk = Clerk.mockSignedOut
    let view = AuthView(isDismissible: isDismissible)
    let authState = view.authState
    let window = try await show(view, clerk: clerk)
    defer { hide(window) }
    enterSecrets(into: authState)

    try await completeAuthFlow(in: clerk, window: window)
    #expect(authState.signInPassword == "password-for-a")

    try await waitUntil(window) { authState.signInPassword.isEmpty }
    #expect(authState.signInPassword.isEmpty)
    #expect(authState.signInNewPassword.isEmpty)
    #expect(authState.signInConfirmNewPassword.isEmpty)
    #expect(authState.signInBackupCode.isEmpty)
    #expect(authState.signUpPassword.isEmpty)
  }

  @Test
  func leavingTheScreenAfterCompletionClearsEnteredSecrets() async throws {
    let clerk = Clerk.mockSignedOut
    let view = AuthView(isDismissible: false)
    let authState = view.authState
    let window = try await show(view, clerk: clerk)
    defer { hide(window) }
    enterSecrets(into: authState)

    try await completeAuthFlow(in: clerk, window: window)
    window.rootViewController = UIViewController()

    try await waitUntil(window) { authState.signInPassword.isEmpty }
    #expect(authState.signInPassword.isEmpty)
  }

  @Test
  func signingOutSoonAfterCompletionKeepsWhatTheNextPersonTypes() async throws {
    let clerk = Clerk.mockSignedOut
    let view = AuthView(isDismissible: false)
    let authState = view.authState
    let window = try await show(view, clerk: clerk)
    defer { hide(window) }

    try await completeAuthFlow(in: clerk, window: window)
    clerk.setClientFromIdentityController(.mockSignedOut)
    try await layout(window)
    authState.signInPassword = "password-for-b"

    try await Task.sleep(for: .seconds(1.5))
    #expect(authState.signInPassword == "password-for-b")
  }

  @Test
  func signingOutResetsSignUpDetailsAndConsentForTheNextPerson() async throws {
    let clerk = Clerk.mock
    let view = AuthView(isDismissible: false)
    let authState = view.authState
    let window = try await show(view, clerk: clerk)
    defer { hide(window) }
    enterSignUpDetails(into: authState)

    clerk.setClientFromIdentityController(.mockSignedOut)
    try await layout(window)

    #expect(authState.signUpFirstName.isEmpty)
    #expect(authState.signUpLastName.isEmpty)
    #expect(authState.signUpUsername.isEmpty)
    #expect(authState.signUpEmailAddress.isEmpty)
    #expect(authState.signUpPhoneNumber.isEmpty)
    #expect(authState.signUpLegalAccepted == false)
  }

  @Test
  func signingOutRestoresConfiguredInitialNames() async throws {
    let clerk = Clerk.mock
    let view = AuthView(isDismissible: false)
      .initialFirstName("Jane")
      .lockPrefilledFields()
    let authState = view.authState
    let window = try await show(view, clerk: clerk)
    defer { hide(window) }
    enterSignUpDetails(into: authState)

    clerk.setClientFromIdentityController(.mockSignedOut)
    try await layout(window)

    #expect(authState.signUpFirstName == "Jane")
    #expect(authState.signUpFirstNameIsEnabled == false)
    #expect(authState.signUpLastName.isEmpty)
  }

  @Test
  func signingOutClearsTheIdentifierWhenTheHostOptedOutOfRememberingIt() async throws {
    let clerk = Clerk.mock
    let view = AuthView(isDismissible: false)
      .persistsIdentifiers(false)
    let authState = view.authState
    let window = try await show(view, clerk: clerk)
    defer { hide(window) }
    authState.authStartIdentifier = "a+clerk_test@example.com"

    clerk.setClientFromIdentityController(.mockSignedOut)
    try await layout(window)

    #expect(authState.authStartIdentifier.isEmpty)
    #expect(authState.authStartPhoneNumber.isEmpty)
    #expect(authState.authStartPhoneNumberFieldIsActive == false)
  }

  private func enterSignUpDetails(into authState: AuthState) {
    authState.signUpFirstName = "Ann"
    authState.signUpLastName = "Other"
    authState.signUpUsername = "ann"
    authState.signUpEmailAddress = "ann+clerk_test@example.com"
    authState.signUpPhoneNumber = "+15555550100"
    authState.signUpLegalAccepted = true
  }

  private func completeAuthFlow(in clerk: Clerk, window: UIWindow) async throws {
    clerk.setClientFromIdentityController(.mock)
    try await waitUntil(window) { clerk.isAuthFlowComplete }
    #expect(clerk.isAuthFlowComplete)
  }

  private func waitUntil(_ window: UIWindow, _ condition: () -> Bool) async throws {
    for _ in 0 ..< 300 where !condition() {
      window.layoutIfNeeded()
      try await Task.sleep(for: .milliseconds(10))
    }
  }

  private func enterSecrets(into authState: AuthState) {
    authState.signInPassword = "password-for-a"
    authState.signInNewPassword = "new-password-for-a"
    authState.signInConfirmNewPassword = "new-password-for-a"
    authState.signInBackupCode = "backup-code-for-a"
    authState.signUpPassword = "sign-up-password-for-a"
  }

  private func show(_ view: AuthView, clerk: Clerk = .mockSignedOut) async throws -> UIWindow {
    let host = UIHostingController(rootView: view.environment(clerk))
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
    window.rootViewController = host
    window.isHidden = false
    try await layout(window)
    return window
  }

  private func hide(_ window: UIWindow) {
    window.isHidden = true
    window.rootViewController = nil
  }

  private func layout(_ window: UIWindow) async throws {
    for _ in 0 ..< 10 {
      window.layoutIfNeeded()
      try await Task.sleep(for: .milliseconds(10))
    }
  }
}

#endif
