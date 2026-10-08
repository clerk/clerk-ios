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

  private func enterSecrets(into authState: AuthState) {
    authState.signInPassword = "password-for-a"
    authState.signInNewPassword = "new-password-for-a"
    authState.signInConfirmNewPassword = "new-password-for-a"
    authState.signInBackupCode = "backup-code-for-a"
    authState.signUpPassword = "sign-up-password-for-a"
  }

  private func show(_ view: AuthView) async throws -> UIWindow {
    let host = UIHostingController(rootView: view.environment(Clerk.mockSignedOut))
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
