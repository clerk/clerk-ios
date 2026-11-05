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

    clerk.setClientFromIdentityController(.mockSignedOut)
    try await layout(window)

    #expect(authState.signInPassword.isEmpty)
    #expect(authState.signInNewPassword.isEmpty)
    #expect(authState.signInConfirmNewPassword.isEmpty)
    #expect(authState.signInBackupCode.isEmpty)
    #expect(authState.signUpPassword.isEmpty)
  }

  @Test
  func signingOutOnTheStartScreenClearsEnteredSecrets() async throws {
    let clerk = Clerk.mock
    let view = AuthView(isDismissible: false)
    let authState = view.authState
    let window = try await show(view, clerk: clerk)
    defer { hide(window) }
    enterSecrets(into: authState)

    clerk.setClientFromIdentityController(.mockSignedOut)
    try await layout(window)

    #expect(authState.signInPassword.isEmpty)
    #expect(authState.signInNewPassword.isEmpty)
    #expect(authState.signInConfirmNewPassword.isEmpty)
    #expect(authState.signInBackupCode.isEmpty)
    #expect(authState.signUpPassword.isEmpty)
  }

  @Test
  func signingOutResetsConsentAndKeepsOtherEnteredDetails() async throws {
    let clerk = Clerk.mock
    // With persistence off, AuthView's state removes the stored identifiers from the standard defaults.
    let restoreStoredIdentifiers = storedIdentifiersRestorer()
    defer { restoreStoredIdentifiers() }
    let view = AuthView(isDismissible: false)
      .persistsIdentifiers(false)
    let authState = view.authState
    let window = try await show(view, clerk: clerk)
    defer { hide(window) }
    authState.authStartIdentifier = "a+clerk_test@example.com"
    authState.signUpFirstName = "Ann"
    authState.signUpEmailAddress = "a+clerk_test@example.com"
    authState.signUpLegalAccepted = true

    clerk.setClientFromIdentityController(.mockSignedOut)
    try await layout(window)

    #expect(authState.signUpLegalAccepted == false)
    #expect(authState.authStartIdentifier == "a+clerk_test@example.com")
    #expect(authState.signUpFirstName == "Ann")
    #expect(authState.signUpEmailAddress == "a+clerk_test@example.com")
  }

  @Test
  func completingTheFlowKeepsTheEnteredPasswordForAutoFill() async throws {
    let clerk = Clerk.mockSignedOut
    let view = AuthView(isDismissible: false)
    let authState = view.authState
    let window = try await show(view, clerk: clerk)
    defer { hide(window) }
    enterSecrets(into: authState)

    clerk.setClientFromIdentityController(.mock)
    try await layout(window, until: { clerk.isAuthFlowComplete })
    #expect(clerk.isAuthFlowComplete)

    try await Task.sleep(for: .seconds(1.5))
    #expect(authState.signInPassword == "password-for-a")
  }

  @Test
  func leavingTheScreenAfterACompletedFlowClearsEnteredSecrets() async throws {
    let clerk = Clerk.mockSignedOut
    let view = AuthView(isDismissible: false)
    let authState = view.authState
    let window = try await show(view, clerk: clerk)
    defer { hide(window) }
    enterSecrets(into: authState)

    clerk.setClientFromIdentityController(.mock)
    try await layout(window, until: { clerk.isAuthFlowComplete })
    #expect(clerk.isAuthFlowComplete)

    window.rootViewController = UIViewController()
    try await layout(window)

    #expect(authState.signInPassword.isEmpty)
    #expect(authState.signInNewPassword.isEmpty)
    #expect(authState.signInConfirmNewPassword.isEmpty)
    #expect(authState.signInBackupCode.isEmpty)
    #expect(authState.signUpPassword.isEmpty)
  }

  @Test
  func leavingTheScreenDuringTheFlowKeepsEnteredSecrets() async throws {
    let view = AuthView(isDismissible: false)
    let authState = view.authState
    let window = try await show(view)
    defer { hide(window) }
    enterSecrets(into: authState)

    window.rootViewController = UIViewController()
    try await layout(window)

    #expect(authState.signInPassword == "password-for-a")
    #expect(authState.signUpPassword == "sign-up-password-for-a")
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

  private func layout(_ window: UIWindow, until condition: () -> Bool) async throws {
    for _ in 0 ..< 300 where !condition() {
      window.layoutIfNeeded()
      try await Task.sleep(for: .milliseconds(10))
    }
  }

  private func storedIdentifiersRestorer() -> () -> Void {
    let defaults = UserDefaults.standard
    let keys = [
      AuthState.identifierStorageKey,
      AuthState.phoneNumberStorageKey,
      AuthState.phoneNumberFieldIsActiveStorageKey,
    ]
    let storedValues = keys.map { defaults.object(forKey: $0) }
    let storedIdentifierType = LastUsedAuth.retrieveStoredIdentifierType(userDefaults: defaults)
    return {
      for (key, value) in zip(keys, storedValues) {
        defaults.set(value, forKey: key)
      }
      if let storedIdentifierType {
        LastUsedAuth.storeIdentifierType(storedIdentifierType, userDefaults: defaults)
      } else {
        LastUsedAuth.clearStoredIdentifierType(userDefaults: defaults)
      }
    }
  }
}

#endif
