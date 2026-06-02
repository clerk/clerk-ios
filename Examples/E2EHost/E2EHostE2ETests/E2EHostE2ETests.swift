//
//  E2EHostE2ETests.swift
//  E2EHostE2ETests
//

import CryptoKit
import Foundation
import XCTest

private struct E2ELaunchConfiguration {
  let authMode: String
  let publishableKey: String
  let publishableKeyName: String
  let keychainService: String
}

private enum E2ECleanupCommand {
  static let notificationName = "com.clerk.E2EHost.cleanupAccount"

  static func post() {
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName(notificationName as CFString),
      nil,
      nil,
      true
    )
  }
}

final class E2EHostE2ETests: XCTestCase {
  private static let defaultPublishableKeyName = "auth-email-code-password"
  private static let multiMethodsPublishableKeyName = "auth-multi-methods"
  private static let phonePublishableKeyName = "auth-phone-code"
  private static let usernameUserModelPublishableKeyName = "auth-username-password-user-model"
  private static let legalConsentPublishableKeyName = "auth-legal-consent"
  private static let sessionTaskSetupMfaPublishableKeyName = "session-task-setup-mfa"
  private static let sessionTaskChooseOrganizationPublishableKeyName = "session-task-choose-organization"
  private static let sessionTaskResetPasswordPublishableKeyName = "session-task-reset-password"
  private static let defaultChooseOrganizationEmailDomain = "clerk.dev"

  private let verificationCode = "424242"
  private let testPassword = "ClerkIOS2026E2ETestPassword9!"

  private var app: XCUIApplication?

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  override func tearDownWithError() throws {
    if let app, let testRun, testRun.failureCount > 0 {
      add(XCTAttachment(screenshot: app.screenshot()))
    }

    if let app {
      cleanupAccountIfNeeded(in: app)
    }

    app?.terminate()
    app = nil
  }

  func testEmailCodeSignUpThenPasswordSignIn() throws {
    let publishableKey = try requiredPublishableKey(named: Self.defaultPublishableKeyName)
    let email = Self.makeUniqueTestEmail()
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"

    app = launchApp(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.defaultPublishableKeyName,
      keychainService: keychainService
    )
    guard let signUpApp = app else { return }

    openAuth(in: signUpApp)
    completeEmailCodeSignUp(email: email, in: signUpApp)
    waitForSignedIn(in: signUpApp)
    dismissSavePasswordPromptIfPresent(in: signUpApp)

    tap(E2EIdentifier.signOut, in: signUpApp)
    waitForSignedOut(in: signUpApp)
    signUpApp.terminate()

    app = launchApp(
      authMode: "signIn",
      publishableKey: publishableKey,
      publishableKeyName: Self.defaultPublishableKeyName,
      keychainService: keychainService
    )
    guard let signInApp = app else { return }

    openAuth(in: signInApp)
    enterText(email, into: E2EIdentifier.authStartIdentifier, in: signInApp)
    tap(E2EIdentifier.authStartContinue, in: signInApp)
    enterText(testPassword, into: E2EIdentifier.signInPassword, in: signInApp)
    tap(E2EIdentifier.signInContinue, in: signInApp)
    waitForSignedIn(in: signInApp)
    dismissSavePasswordPromptIfPresent(in: signInApp)

    tap(E2EIdentifier.deleteAccount, in: signInApp)
    waitForSignedOut(in: signInApp)
  }

  func testUserProfileSecurityChangesPassword() throws {
    let publishableKey = try requiredPublishableKey(named: Self.defaultPublishableKeyName)
    let email = Self.makeUniqueTestEmail()
    let newPassword = Self.makeUniqueTestPassword()
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"

    app = launchApp(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.defaultPublishableKeyName,
      keychainService: keychainService
    )
    guard let signUpApp = app else { return }

    openAuth(in: signUpApp)
    completeEmailCodeSignUp(email: email, in: signUpApp)
    waitForSignedIn(in: signUpApp)
    waitForSessionActive(in: signUpApp)
    dismissSavePasswordPromptIfPresent(in: signUpApp)

    openUserProfileSecurity(in: signUpApp)
    completeUserProfilePasswordChange(newPassword: newPassword, in: signUpApp)
    cleanupAccountIfNeeded(in: signUpApp)
  }

  func testUserProfileSecurityAddsTwoStepVerificationWithAuthenticatorApp() throws {
    let publishableKey = try requiredPublishableKey(named: Self.multiMethodsPublishableKeyName)
    let email = Self.makeUniqueTestEmail()
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"

    app = launchApp(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.multiMethodsPublishableKeyName,
      keychainService: keychainService
    )
    guard let signUpApp = app else { return }

    openAuth(in: signUpApp)
    completeEmailCodeSignUp(email: email, in: signUpApp)
    waitForSignedIn(in: signUpApp)
    waitForSessionActive(in: signUpApp)
    dismissSavePasswordPromptIfPresent(in: signUpApp)

    openUserProfileSecurity(in: signUpApp)
    try completeUserProfileAuthenticatorAppMfaSetup(in: signUpApp)
    cleanupAccountIfNeeded(in: signUpApp)
  }

  func testUserProfileSecurityAddsTwoStepVerificationWithSmsCode() throws {
    let publishableKey = try requiredPublishableKey(named: Self.multiMethodsPublishableKeyName)
    let email = Self.makeUniqueTestEmail()
    let phoneNumber = Self.makeUniqueTestPhoneNumber()
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"

    app = launchApp(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.multiMethodsPublishableKeyName,
      keychainService: keychainService
    )
    guard let signUpApp = app else { return }

    openAuth(in: signUpApp)
    completeEmailCodeSignUp(email: email, in: signUpApp)
    waitForSignedIn(in: signUpApp)
    waitForSessionActive(in: signUpApp)
    dismissSavePasswordPromptIfPresent(in: signUpApp)

    openUserProfileSecurity(in: signUpApp)
    completeUserProfileSmsCodeMfaSetup(phoneNumber: phoneNumber, in: signUpApp)
    cleanupAccountIfNeeded(in: signUpApp)
  }

  func testUserProfileSecurityDeletesAccount() throws {
    let publishableKey = try requiredPublishableKey(named: Self.defaultPublishableKeyName)
    let email = Self.makeUniqueTestEmail()
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"

    app = launchApp(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.defaultPublishableKeyName,
      keychainService: keychainService
    )
    guard let signUpApp = app else { return }

    openAuth(in: signUpApp)
    completeEmailCodeSignUp(email: email, in: signUpApp)
    waitForSignedIn(in: signUpApp)
    waitForSessionActive(in: signUpApp)
    dismissSavePasswordPromptIfPresent(in: signUpApp)

    openUserProfileSecurity(in: signUpApp)
    deleteAccountFromUserProfileSecurity(in: signUpApp)
    waitForSignedOut(in: signUpApp)
  }

  func testUserProfileAddsAccountThenSwitchesAccounts() throws {
    let publishableKey = try requiredPublishableKey(named: Self.multiMethodsPublishableKeyName)
    let firstEmail = Self.makeUniqueTestEmail()
    let secondEmail = Self.makeUniqueTestEmail()
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"

    app = launchApp(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.multiMethodsPublishableKeyName,
      keychainService: keychainService
    )
    guard let signUpApp = app else { return }

    openAuth(in: signUpApp)
    completeEmailCodeSignUp(email: firstEmail, in: signUpApp)
    waitForSignedIn(in: signUpApp)
    waitForSessionActive(in: signUpApp)
    dismissSavePasswordPromptIfPresent(in: signUpApp)
    let firstUserID = try currentUserID(in: signUpApp)

    openUserProfileRoot(in: signUpApp)
    waitForUserProfileCurrentUser(firstUserID, in: signUpApp)
    tapWhenHittableAfterScrolling(
      E2EIdentifier.userProfileAddAccountRow,
      in: signUpApp,
      message: "Expected User Profile to show Add account. Enable Dashboard > Sessions > Multi-session handling for auth-multi-methods."
    )
    completeEmailCodeSignUp(email: secondEmail, in: signUpApp)
    waitForSignedIn(in: signUpApp)
    waitForSessionActive(in: signUpApp)
    dismissSavePasswordPromptIfPresent(in: signUpApp, timeout: 10)

    tapWhenHittableAfterScrolling(
      E2EIdentifier.userProfileSwitchAccountRow,
      in: signUpApp,
      timeout: 45,
      message: "Expected User Profile to show Switch account after adding a second session."
    )
    tapWhenHittable(E2EIdentifier.accountSwitcherSession(userID: firstUserID), in: signUpApp, timeout: 45)
    XCTAssertTrue(
      signUpApp.descendants(matching: .any)[E2EIdentifier.accountSwitcherSession(userID: firstUserID)]
        .waitForNonExistence(timeout: 45),
      "Expected the account switcher to dismiss after switching accounts."
    )
    waitForUserProfileCurrentUser(firstUserID, in: signUpApp)

    tapWhenHittable(E2EIdentifier.dismissButton, in: signUpApp)
    tapWhenHittable(E2EIdentifier.deleteAccount, in: signUpApp)
    waitForSignedOut(in: signUpApp)
    signUpApp.terminate()

    app = launchApp(
      authMode: "signIn",
      publishableKey: publishableKey,
      publishableKeyName: Self.multiMethodsPublishableKeyName,
      keychainService: keychainService
    )
    guard let signInApp = app else { return }

    openAuth(in: signInApp)
    completePasswordSignIn(email: secondEmail, in: signInApp)
    waitForSignedIn(in: signInApp)
    waitForSessionActive(in: signInApp)
    dismissSavePasswordPromptIfPresent(in: signInApp, timeout: 10)
    tapWhenHittable(E2EIdentifier.deleteAccount, in: signInApp)
    waitForSignedOut(in: signInApp)
  }

  func testMultiMethodsEmailSignUpThenEmailCodeSignInViaUseAnotherMethod() throws {
    let publishableKey = try requiredPublishableKey(named: Self.multiMethodsPublishableKeyName)
    let email = Self.makeUniqueTestEmail()
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"

    app = launchApp(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.multiMethodsPublishableKeyName,
      keychainService: keychainService
    )
    guard let signUpApp = app else { return }

    openAuth(in: signUpApp)
    completeEmailCodeSignUp(email: email, in: signUpApp)
    waitForSignedIn(in: signUpApp)
    dismissSavePasswordPromptIfPresent(in: signUpApp)

    tap(E2EIdentifier.signOut, in: signUpApp)
    waitForSignedOut(in: signUpApp)
    signUpApp.terminate()

    app = launchApp(
      authMode: "signIn",
      publishableKey: publishableKey,
      publishableKeyName: Self.multiMethodsPublishableKeyName,
      keychainService: keychainService
    )
    guard let signInApp = app else { return }

    openAuth(in: signInApp)
    enterText(email, into: E2EIdentifier.authStartIdentifier, in: signInApp)
    tap(E2EIdentifier.authStartContinue, in: signInApp)
    tap(E2EIdentifier.signInUseAnotherMethod, in: signInApp)
    tap(E2EIdentifier.signInEmailCodeAlternativeMethod, in: signInApp)
    waitForSignInCodePrepared(in: signInApp)
    enterVerificationCode(verificationCode, into: E2EIdentifier.signInCode, in: signInApp)
    waitForSignedIn(in: signInApp)
    dismissSavePasswordPromptIfPresent(in: signInApp)

    tap(E2EIdentifier.deleteAccount, in: signInApp)
    waitForSignedOut(in: signInApp)
  }

  func testPhoneCodeSignUpThenPhoneCodeSignIn() throws {
    let publishableKey = try requiredPublishableKey(named: Self.phonePublishableKeyName)
    let email = Self.makeUniqueTestEmail()
    let phoneNumber = Self.makeUniqueTestPhoneNumber()
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"

    app = launchApp(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.phonePublishableKeyName,
      keychainService: keychainService
    )
    guard let signUpApp = app else { return }

    openAuth(in: signUpApp)
    completePhoneCodeSignUp(phoneNumber: phoneNumber, email: email, in: signUpApp)
    waitForSignedIn(in: signUpApp)
    dismissSavePasswordPromptIfPresent(in: signUpApp)

    tap(E2EIdentifier.signOut, in: signUpApp)
    waitForSignedOut(in: signUpApp)
    signUpApp.terminate()

    app = launchApp(
      authMode: "signIn",
      publishableKey: publishableKey,
      publishableKeyName: Self.phonePublishableKeyName,
      keychainService: keychainService
    )
    guard let signInApp = app else { return }

    openAuth(in: signInApp)
    switchToPhoneNumberIdentifier(in: signInApp)
    enterPhoneNumber(phoneNumber, in: signInApp)
    tap(E2EIdentifier.authStartContinue, in: signInApp)
    completePhoneCodeSignIn(in: signInApp)
    waitForSignedIn(in: signInApp)
    dismissSavePasswordPromptIfPresent(in: signInApp)

    tap(E2EIdentifier.deleteAccount, in: signInApp)
    waitForSignedOut(in: signInApp)
  }

  func testMultiMethodsPhoneSignUpThenPhoneCodeSignInViaUseAnotherMethod() throws {
    let publishableKey = try requiredPublishableKey(named: Self.multiMethodsPublishableKeyName)
    let email = Self.makeUniqueTestEmail()
    let phoneNumber = Self.makeUniqueTestPhoneNumber()
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"

    app = launchApp(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.multiMethodsPublishableKeyName,
      keychainService: keychainService
    )
    guard let signUpApp = app else { return }

    openAuth(in: signUpApp)
    completePhoneCodeSignUp(phoneNumber: phoneNumber, email: email, in: signUpApp)
    waitForSignedIn(in: signUpApp)
    dismissSavePasswordPromptIfPresent(in: signUpApp)

    tap(E2EIdentifier.signOut, in: signUpApp)
    waitForSignedOut(in: signUpApp)
    signUpApp.terminate()

    app = launchApp(
      authMode: "signIn",
      publishableKey: publishableKey,
      publishableKeyName: Self.multiMethodsPublishableKeyName,
      keychainService: keychainService
    )
    guard let signInApp = app else { return }

    openAuth(in: signInApp)
    switchToPhoneNumberIdentifier(in: signInApp)
    enterPhoneNumber(phoneNumber, in: signInApp)
    tap(E2EIdentifier.authStartContinue, in: signInApp)
    tap(E2EIdentifier.signInUseAnotherMethod, in: signInApp)
    tap(E2EIdentifier.signInPhoneCodeAlternativeMethod, in: signInApp)
    waitForSignInCodePrepared(in: signInApp)
    enterVerificationCode(verificationCode, into: E2EIdentifier.signInCode, in: signInApp)
    waitForSignedIn(in: signInApp)
    dismissSavePasswordPromptIfPresent(in: signInApp)

    tap(E2EIdentifier.deleteAccount, in: signInApp)
    waitForSignedOut(in: signInApp)
  }

  func testUsernamePasswordSignUpThenUsernamePasswordSignInWithRequiredUserModelFields() throws {
    let publishableKey = try requiredPublishableKey(named: Self.usernameUserModelPublishableKeyName)
    let username = Self.makeUniqueTestUsername()
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"

    app = launchApp(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.usernameUserModelPublishableKeyName,
      keychainService: keychainService
    )
    guard let signUpApp = app else { return }

    openAuth(in: signUpApp)
    completeUsernamePasswordUserModelSignUp(username: username, in: signUpApp)
    waitForSignedIn(in: signUpApp)
    dismissSavePasswordPromptIfPresent(in: signUpApp)

    tap(E2EIdentifier.signOut, in: signUpApp)
    waitForSignedOut(in: signUpApp)
    signUpApp.terminate()

    app = launchApp(
      authMode: "signIn",
      publishableKey: publishableKey,
      publishableKeyName: Self.usernameUserModelPublishableKeyName,
      keychainService: keychainService
    )
    guard let signInApp = app else { return }

    openAuth(in: signInApp)
    enterText(username, into: E2EIdentifier.authStartIdentifier, in: signInApp)
    tap(E2EIdentifier.authStartContinue, in: signInApp)
    enterText(testPassword, into: E2EIdentifier.signInPassword, in: signInApp)
    tap(E2EIdentifier.signInContinue, in: signInApp)
    waitForSignedIn(in: signInApp)
    dismissSavePasswordPromptIfPresent(in: signInApp)

    tap(E2EIdentifier.deleteAccount, in: signInApp)
    waitForSignedOut(in: signInApp)
  }

  func testEmailCodeSignUpCompletesRequiredLegalConsent() throws {
    let publishableKey = try requiredPublishableKey(named: Self.legalConsentPublishableKeyName)
    let email = Self.makeUniqueTestEmail()
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"

    app = launchApp(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.legalConsentPublishableKeyName,
      keychainService: keychainService
    )
    guard let signUpApp = app else { return }

    openAuth(in: signUpApp)
    completeEmailCodeSignUp(email: email, in: signUpApp)
    dismissSavePasswordPromptIfPresent(in: signUpApp)
    completeRequiredLegalConsent(in: signUpApp)
    waitForSignedIn(in: signUpApp)
    waitForSessionActive(in: signUpApp)

    tap(E2EIdentifier.deleteAccount, in: signUpApp)
    waitForSignedOut(in: signUpApp)
  }

  func testSessionTaskSetupMfaSignUpCompletesAuthenticatorAppSetup() throws {
    let publishableKey = try requiredPublishableKey(named: Self.sessionTaskSetupMfaPublishableKeyName)
    let email = Self.makeUniqueTestEmail()
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"

    app = launchApp(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.sessionTaskSetupMfaPublishableKeyName,
      keychainService: keychainService
    )
    guard let signUpApp = app else { return }

    openAuth(in: signUpApp)
    completeEmailCodeSignUp(email: email, in: signUpApp)
    waitForSignedIn(in: signUpApp)
    waitForSessionPending(in: signUpApp)
    assertPendingTasksContain("setup-mfa", in: signUpApp)
    dismissSavePasswordPromptIfPresent(in: signUpApp)

    try completeAuthenticatorAppSetup(in: signUpApp)
    waitForSessionActive(in: signUpApp)

    tap(E2EIdentifier.deleteAccount, in: signUpApp)
    waitForSignedOut(in: signUpApp)
  }

  func testSessionTaskSetupMfaSignUpCompletesSmsCodeSetup() throws {
    let publishableKey = try requiredPublishableKey(named: Self.sessionTaskSetupMfaPublishableKeyName)
    let email = Self.makeUniqueTestEmail()
    let phoneNumber = Self.makeUniqueTestPhoneNumber()
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"

    app = launchApp(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.sessionTaskSetupMfaPublishableKeyName,
      keychainService: keychainService
    )
    guard let signUpApp = app else { return }

    openAuth(in: signUpApp)
    completeEmailCodeSignUp(email: email, in: signUpApp)
    waitForSignedIn(in: signUpApp)
    waitForSessionPending(in: signUpApp)
    assertPendingTasksContain("setup-mfa", in: signUpApp)
    dismissSavePasswordPromptIfPresent(in: signUpApp)

    completeSmsCodeMfaSetup(phoneNumber: phoneNumber, in: signUpApp)
    waitForSessionActive(in: signUpApp)

    tap(E2EIdentifier.deleteAccount, in: signUpApp)
    waitForSignedOut(in: signUpApp)
  }

  func testSessionTaskChooseOrganizationSignUpAcceptsInvitationAndSelectsOrganization() throws {
    let publishableKey = try requiredPublishableKey(named: Self.sessionTaskChooseOrganizationPublishableKeyName)
    let email = Self.makeUniqueChooseOrganizationTestEmail()
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"

    app = launchApp(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.sessionTaskChooseOrganizationPublishableKeyName,
      keychainService: keychainService
    )
    guard let signUpApp = app else { return }

    openAuth(in: signUpApp)
    completeEmailCodeSignUp(email: email, in: signUpApp)
    waitForSignedIn(in: signUpApp)
    waitForSessionPending(in: signUpApp)
    assertPendingTasksContain("choose-organization", in: signUpApp)
    dismissSavePasswordPromptIfPresent(in: signUpApp)

    completeChooseOrganizationByAcceptingInvitation(in: signUpApp)
    waitForSessionActive(in: signUpApp)

    tap(E2EIdentifier.deleteAccount, in: signUpApp)
    waitForSignedOut(in: signUpApp)
  }

  func testSessionTaskChooseOrganizationSignUpCreatesOrganization() throws {
    let publishableKey = try requiredPublishableKey(named: Self.sessionTaskChooseOrganizationPublishableKeyName)
    let email = Self.makeUniqueChooseOrganizationTestEmail()
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"

    app = launchApp(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.sessionTaskChooseOrganizationPublishableKeyName,
      keychainService: keychainService
    )
    guard let signUpApp = app else { return }

    openAuth(in: signUpApp)
    completeEmailCodeSignUp(email: email, in: signUpApp)
    waitForSignedIn(in: signUpApp)
    waitForSessionPending(in: signUpApp)
    assertPendingTasksContain("choose-organization", in: signUpApp)
    dismissSavePasswordPromptIfPresent(in: signUpApp)

    completeChooseOrganizationByCreatingOrganization(in: signUpApp)
    waitForSessionActive(in: signUpApp)

    tap(E2EIdentifier.deleteAccount, in: signUpApp)
    waitForSignedOut(in: signUpApp)
  }

  func testSessionTaskResetPasswordSignInCompletesPasswordReset() throws {
    let publishableKey = try requiredPublishableKey(named: Self.sessionTaskResetPasswordPublishableKeyName)
    let secretKey = try requiredSecretKey(named: Self.sessionTaskResetPasswordPublishableKeyName)
    let email = Self.makeUniqueTestEmail()
    let newPassword = Self.makeUniqueTestPassword()
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"

    app = launchApp(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.sessionTaskResetPasswordPublishableKeyName,
      keychainService: keychainService
    )
    guard let signUpApp = app else { return }

    openAuth(in: signUpApp)
    completeEmailCodeSignUp(email: email, in: signUpApp)
    waitForSignedIn(in: signUpApp)
    waitForSessionActive(in: signUpApp)
    dismissSavePasswordPromptIfPresent(in: signUpApp)
    let userID = try currentUserID(in: signUpApp)

    tap(E2EIdentifier.signOut, in: signUpApp)
    waitForSignedOut(in: signUpApp)
    signUpApp.terminate()

    try setUserPasswordCompromised(userID: userID, publishableKey: publishableKey, secretKey: secretKey)

    app = launchApp(
      authMode: "signIn",
      publishableKey: publishableKey,
      publishableKeyName: Self.sessionTaskResetPasswordPublishableKeyName,
      keychainService: keychainService
    )
    guard let signInApp = app else { return }

    openAuth(in: signInApp)
    enterText(email, into: E2EIdentifier.authStartIdentifier, in: signInApp)
    tap(E2EIdentifier.authStartContinue, in: signInApp)
    enterText(testPassword, into: E2EIdentifier.signInPassword, in: signInApp)
    tap(E2EIdentifier.signInContinue, in: signInApp)
    dismissSavePasswordPromptIfPresent(in: signInApp)
    tap(E2EIdentifier.signInUseAnotherMethod, in: signInApp)
    dismissSavePasswordPromptIfPresent(in: signInApp, timeout: 3)
    tapWhenHittable(E2EIdentifier.signInEmailCodeAlternativeMethod, in: signInApp)
    dismissSavePasswordPromptIfPresent(in: signInApp, timeout: 3)
    waitForSignInCodePrepared(in: signInApp)
    enterVerificationCode(verificationCode, into: E2EIdentifier.signInCode, in: signInApp)
    waitForSignedIn(in: signInApp)
    waitForSessionPending(in: signInApp)
    assertPendingTasksContain("reset-password", in: signInApp)
    dismissSavePasswordPromptIfPresent(in: signInApp)

    completeResetPasswordSessionTask(newPassword: newPassword, in: signInApp)
    waitForSessionActive(in: signInApp)
    dismissSavePasswordPromptIfPresent(in: signInApp)

    tap(E2EIdentifier.deleteAccount, in: signInApp)
    waitForSignedOut(in: signInApp)
  }

  func testInAppCleanupDeletesPendingUser() throws {
    let publishableKey = try requiredPublishableKey(named: Self.sessionTaskSetupMfaPublishableKeyName)
    let email = Self.makeUniqueTestEmail()
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"
    let configuration = E2ELaunchConfiguration(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.sessionTaskSetupMfaPublishableKeyName,
      keychainService: keychainService
    )

    app = launchApp(configuration: configuration)
    guard let signUpApp = app else { return }
    waitForSignedOut(in: signUpApp)

    openAuth(in: signUpApp)
    completeEmailCodeSignUp(email: email, in: signUpApp)
    waitForSignedIn(in: signUpApp)
    waitForSessionPending(in: signUpApp)
    dismissSavePasswordPromptIfPresent(in: signUpApp)
    XCTAssertFalse(
      signUpApp.descendants(matching: .any)[E2EIdentifier.deleteAccount].exists,
      "Delete account should not be visible while the session is pending."
    )
    cleanupAccountIfNeeded(in: signUpApp)
  }
}

extension E2EHostE2ETests {
  fileprivate enum E2EIdentifier {
    static let authStartIdentifier = "clerk.auth.start.identifier"
    static let authStartPhoneNumber = "clerk.auth.start.phoneNumber"
    static let authStartContinue = "clerk.auth.start.continue"
    static let authStartIdentifierSwitcher = "clerk.auth.start.identifierSwitcher"
    static let signUpCode = "clerk.auth.signUp.code"
    static let signUpEmailAddress = "clerk.auth.signUp.emailAddress"
    static let signUpUsername = "clerk.auth.signUp.username"
    static let signUpPassword = "clerk.auth.signUp.password"
    static let signUpContinue = "clerk.auth.signUp.continue"
    static let signUpCompleteProfileFirstName = "clerk.auth.signUp.completeProfile.firstName"
    static let signUpCompleteProfileLastName = "clerk.auth.signUp.completeProfile.lastName"
    static let signUpCompleteProfileContinue = "clerk.auth.signUp.completeProfile.continue"
    static let signUpLegalAccepted = "clerk.auth.signUp.legalAccepted"
    static let signInCode = "clerk.auth.signIn.code"
    static let signInPassword = "clerk.auth.signIn.password"
    static let signInContinue = "clerk.auth.signIn.continue"
    static let signInUseAnotherMethod = "clerk.auth.signIn.useAnotherMethod"
    static let signInEmailCodeAlternativeMethod = "clerk.auth.signIn.alternativeMethod.email_code"
    static let signInPhoneCodeAlternativeMethod = "clerk.auth.signIn.alternativeMethod.phone_code"
    static let signedIn = "e2e.auth.signedIn"
    static let signedOut = "e2e.auth.signedOut"
    static let sessionActive = "e2e.auth.sessionActive"
    static let sessionPending = "e2e.auth.sessionPending"
    static let sessionStatus = "e2e.auth.sessionStatus"
    static let pendingTasks = "e2e.auth.pendingTasks"
    static let userID = "e2e.auth.userID"
    static let cleanupComplete = "e2e.auth.cleanupComplete"
    static let signOut = "e2e.auth.signOut"
    static let deleteAccount = "e2e.auth.deleteAccount"
    static let dismissButton = "clerk.dismissButton"
    static let userButtonProfile = "clerk.userButton.profile"
    static let userProfileAddAccountRow = "clerk.userProfile.row.addAccount"
    static let userProfileSwitchAccountRow = "clerk.userProfile.row.switchAccount"
    static let userProfileSecurityRow = "clerk.userProfile.row.security"
    static let userProfileSecurityChangePassword = "clerk.userProfile.security.changePassword"
    static let userProfileSecurityAddMfa = "clerk.userProfile.security.addMfa"
    static let userProfileSecurityDeleteAccount = "clerk.userProfile.security.deleteAccount"
    static let userProfileChangePasswordCurrentPassword = "clerk.userProfile.changePassword.currentPassword"
    static let userProfileChangePasswordNext = "clerk.userProfile.changePassword.next"
    static let userProfileChangePasswordNewPassword = "clerk.userProfile.changePassword.newPassword"
    static let userProfileChangePasswordConfirmPassword = "clerk.userProfile.changePassword.confirmPassword"
    static let userProfileChangePasswordSave = "clerk.userProfile.changePassword.save"
    static let userProfileMfaSmsCode = "clerk.userProfile.mfa.smsCode"
    static let userProfileMfaSmsPhoneNumber = "clerk.userProfile.mfa.sms.phoneNumber"
    static let userProfileMfaSmsContinue = "clerk.userProfile.mfa.sms.continue"
    static let userProfileMfaSmsAddPhone = "clerk.userProfile.mfa.sms.addPhone"
    static let userProfilePhoneNumber = "clerk.userProfile.phone.phoneNumber"
    static let userProfilePhoneContinue = "clerk.userProfile.phone.continue"
    static let userProfileMfaAuthenticatorApp = "clerk.userProfile.mfa.authenticatorApp"
    static let userProfileMfaTotpSecret = "clerk.userProfile.mfa.totp.secret"
    static let userProfileMfaTotpContinue = "clerk.userProfile.mfa.totp.continue"
    static let userProfileMfaVerificationCode = "clerk.userProfile.mfa.verificationCode"
    static let userProfileBackupCodesDone = "clerk.userProfile.backupCodes.done"
    static let userProfileDeleteAccountConfirmation = "clerk.userProfile.deleteAccount.confirmation"
    static let userProfileDeleteAccountConfirm = "clerk.userProfile.deleteAccount.confirm"
    static let setupMfaSmsCode = "clerk.auth.sessionTask.setupMfa.smsCode"
    static let setupMfaAuthenticatorApp = "clerk.auth.sessionTask.setupMfa.authenticatorApp"
    static let smsPhoneNumber = "clerk.auth.sessionTask.sms.phoneNumber"
    static let smsContinue = "clerk.auth.sessionTask.sms.continue"
    static let smsCode = "clerk.auth.sessionTask.sms.code"
    static let totpSecret = "clerk.auth.sessionTask.totp.secret"
    static let totpContinue = "clerk.auth.sessionTask.totp.continue"
    static let totpCode = "clerk.auth.sessionTask.totp.code"
    static let backupCodesContinue = "clerk.auth.sessionTask.backupCodes.continue"
    static let chooseOrganizationCreateOrganization = "clerk.organization.accountList.createOrganization"
    static let chooseOrganizationAcceptedInvitation = "clerk.organization.accountList.invitation.accepted"
    static let chooseOrganizationInvitationJoin = "clerk.organization.accountList.invitation.join"
    static let organizationProfileSubmit = "clerk.organization.profileForm.submit"
    static let resetPasswordNewPassword = "clerk.auth.sessionTask.resetPassword.newPassword"
    static let resetPasswordConfirmPassword = "clerk.auth.sessionTask.resetPassword.confirmPassword"
    static let resetPasswordSubmit = "clerk.auth.sessionTask.resetPassword.submit"

    static func userProfileCurrentUser(userID: String) -> String {
      "clerk.userProfile.currentUser.\(userID)"
    }

    static func accountSwitcherSession(userID: String) -> String {
      "clerk.accountSwitcher.session.\(userID)"
    }
  }

  fileprivate struct BackendAPIError: Error, CustomStringConvertible {
    let statusCode: Int
    let responseBody: String

    var description: String {
      "Backend API request failed with status \(statusCode): \(responseBody)"
    }
  }

  fileprivate enum TOTPError: Error {
    case invalidSecret
  }

  fileprivate static func makeUniqueTestEmail() -> String {
    let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    return "clerk_ios_e2e+clerk_test_\(suffix)@example.com"
  }

  fileprivate static func makeUniqueChooseOrganizationTestEmail() -> String {
    let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    let domain = normalized(ProcessInfo.processInfo.environment["CLERK_E2E_CHOOSE_ORG_EMAIL_DOMAIN"])
      ?? defaultChooseOrganizationEmailDomain
    return "clerk_ios_e2e+clerk_test_\(suffix)@\(domain)"
  }

  fileprivate static func makeUniqueTestPhoneNumber() -> String {
    let suffix = Int.random(in: 100 ... 199)
    return "5555550\(suffix)"
  }

  fileprivate static func makeUniqueTestUsername() -> String {
    let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(16)
    return "clerk_ios_e2e_\(suffix)"
  }

  fileprivate static func makeUniqueTestPassword() -> String {
    let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(12)
    return "ClerkIOS2026E2ENewPassword9!\(suffix)"
  }

  private func requiredPublishableKey(named keyName: String) throws -> String {
    let environment = ProcessInfo.processInfo.environment
    let selectedKeyName = Self.publishableKeyName(environment: environment)

    if selectedKeyName == keyName {
      if let publishableKey = Self.normalized(environment["CLERK_PUBLISHABLE_KEY"])
        ?? Self.normalized(environment["CLERK_E2E_PUBLISHABLE_KEY"])
        ?? Self.publishableKeyFromGeneratedFile(matching: keyName)
      {
        return publishableKey
      }
    }

    if let publishableKey = Self.publishableKeyFromKeysFile(keyName: keyName) {
      return publishableKey
    }

    throw XCTSkip("Configure '\(keyName).pk' in .keys.json.")
  }

  private func requiredSecretKey(named keyName: String) throws -> String {
    let environment = ProcessInfo.processInfo.environment
    let selectedKeyName = Self.publishableKeyName(environment: environment)

    if selectedKeyName == keyName, let secretKey = Self.normalized(environment["CLERK_E2E_SECRET_KEY"]) {
      return secretKey
    }

    if let secretKey = Self.secretKeyFromKeysFile(keyName: keyName) {
      return secretKey
    }

    throw XCTSkip("Configure '\(keyName).sk' in .keys.json.")
  }

  private static func publishableKeyName(environment: [String: String]) -> String {
    normalized(environment["CLERK_E2E_KEY_NAME"])
      ?? publishableKeyNameFromGeneratedFile()
      ?? defaultPublishableKeyName
  }

  private static func publishableKeyNameFromGeneratedFile(sourceFilePath: String = #filePath) -> String? {
    let keyURL = repositoryRoot(sourceFilePath: sourceFilePath)
      .appendingPathComponent("build/reports/E2EHostPublishableKeyName.txt")

    guard
      let contents = try? String(contentsOf: keyURL, encoding: .utf8),
      let keyName = normalized(contents)
    else {
      return nil
    }

    return keyName
  }

  private static func publishableKeyFromGeneratedFile(
    matching keyName: String,
    sourceFilePath: String = #filePath
  ) -> String? {
    guard publishableKeyNameFromGeneratedFile(sourceFilePath: sourceFilePath) == keyName else {
      return nil
    }

    let keyURL = repositoryRoot(sourceFilePath: sourceFilePath)
      .appendingPathComponent("build/reports/E2EHostPublishableKey.txt")

    guard
      let contents = try? String(contentsOf: keyURL, encoding: .utf8),
      let publishableKey = normalized(contents)
    else {
      return nil
    }

    return publishableKey
  }

  private static func publishableKeyFromKeysFile(
    keyName: String,
    sourceFilePath: String = #filePath
  ) -> String? {
    let keysURL = repositoryRoot(sourceFilePath: sourceFilePath)
      .appendingPathComponent(".keys.json")

    guard
      let data = try? Data(contentsOf: keysURL),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let instance = json[keyName] as? [String: Any],
      let publishableKey = normalized(instance["pk"] as? String)
    else {
      return nil
    }

    return publishableKey
  }

  private static func secretKeyFromKeysFile(
    keyName: String,
    sourceFilePath: String = #filePath
  ) -> String? {
    let keysURL = repositoryRoot(sourceFilePath: sourceFilePath)
      .appendingPathComponent(".keys.json")

    guard
      let data = try? Data(contentsOf: keysURL),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let instance = json[keyName] as? [String: Any]
    else {
      return nil
    }

    return normalized(instance["sk"] as? String)
      ?? normalized(instance["secret_key"] as? String)
      ?? normalized(instance["secretKey"] as? String)
  }

  private static func repositoryRoot(sourceFilePath: String) -> URL {
    var directory = URL(fileURLWithPath: sourceFilePath).deletingLastPathComponent()
    let fileManager = FileManager.default

    while directory.path != "/" {
      if fileManager.fileExists(atPath: directory.appendingPathComponent("Clerk.xcworkspace").path) {
        return directory
      }

      directory.deleteLastPathComponent()
    }

    return URL(fileURLWithPath: fileManager.currentDirectoryPath)
  }

  private static func normalized(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }

    return value
  }

  private func launchApp(
    authMode: String,
    publishableKey: String,
    publishableKeyName: String,
    keychainService: String
  ) -> XCUIApplication {
    let configuration = E2ELaunchConfiguration(
      authMode: authMode,
      publishableKey: publishableKey,
      publishableKeyName: publishableKeyName,
      keychainService: keychainService
    )

    let app = launchApp(configuration: configuration)
    waitForSignedOut(in: app)
    return app
  }

  private func launchApp(configuration: E2ELaunchConfiguration) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "-AppleLanguages", "(en)",
      "-AppleLocale", "en_US",
    ]
    let launchEnvironment = [
      "CLERK_PUBLISHABLE_KEY": configuration.publishableKey,
      "CLERK_E2E_MODE": "1",
      "CLERK_E2E_KEY_NAME": configuration.publishableKeyName,
      "CLERK_E2E_AUTH_MODE": configuration.authMode,
      "CLERK_E2E_KEYCHAIN_SERVICE": configuration.keychainService,
    ]

    app.launchEnvironment = launchEnvironment
    app.launch()
    return app
  }

  private func openAuth(in app: XCUIApplication) {
    let signInButton = app.buttons["Sign in"].firstMatch
    XCTAssertTrue(signInButton.waitForExistence(timeout: 20), "Expected the E2EHost sign-in button.")
    signInButton.tap()
  }

  private func openUserProfileRoot(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    tapWhenHittable(E2EIdentifier.userButtonProfile, in: app, file: file, line: line)

    XCTAssertTrue(
      app.descendants(matching: .any)[E2EIdentifier.userProfileSecurityRow].waitForExistence(timeout: 45),
      "Expected the user profile root screen.",
      file: file,
      line: line
    )
  }

  private func openUserProfileSecurity(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    tapWhenHittable(E2EIdentifier.userButtonProfile, in: app, file: file, line: line)
    tapWhenHittable(E2EIdentifier.userProfileSecurityRow, in: app, file: file, line: line)

    XCTAssertTrue(
      app.descendants(matching: .any)[E2EIdentifier.userProfileSecurityChangePassword].waitForExistence(timeout: 45),
      "Expected the user profile Security screen.",
      file: file,
      line: line
    )
  }

  private func completeEmailCodeSignUp(email: String, in app: XCUIApplication) {
    enterText(email, into: E2EIdentifier.authStartIdentifier, in: app)
    tap(E2EIdentifier.authStartContinue, in: app)
    waitForSignUpCodePrepared(in: app)
    enterVerificationCode(verificationCode, into: E2EIdentifier.signUpCode, in: app)
    completePasswordCollectionIfNeeded(in: app)
  }

  private func completePasswordSignIn(email: String, in app: XCUIApplication) {
    enterText(email, into: E2EIdentifier.authStartIdentifier, in: app)
    tap(E2EIdentifier.authStartContinue, in: app)
    enterText(testPassword, into: E2EIdentifier.signInPassword, in: app)
    tap(E2EIdentifier.signInContinue, in: app)
  }

  private func completePhoneCodeSignUp(phoneNumber: String, email: String, in app: XCUIApplication) {
    switchToPhoneNumberIdentifier(in: app)
    enterPhoneNumber(phoneNumber, in: app)
    tap(E2EIdentifier.authStartContinue, in: app)
    waitForSignUpCodePrepared(in: app)
    enterVerificationCode(verificationCode, into: E2EIdentifier.signUpCode, in: app)
    completeMissingEmailAddressIfNeeded(email: email, in: app)
    completePasswordCollectionIfNeeded(in: app)
  }

  private func completeUsernamePasswordUserModelSignUp(username: String, in app: XCUIApplication) {
    enterText(username, into: E2EIdentifier.authStartIdentifier, in: app)
    tap(E2EIdentifier.authStartContinue, in: app)
    completeUsernameCollectionIfNeeded(username: username, in: app)
    completePasswordCollectionIfNeeded(in: app)
    dismissSavePasswordPromptIfPresent(in: app)
    completeRequiredUserModelFieldsIfNeeded(firstName: "Clerk", lastName: "E2E", in: app)
  }

  private func completeUsernameCollectionIfNeeded(username: String, in app: XCUIApplication) {
    let usernameField = app.descendants(matching: .any)[E2EIdentifier.signUpUsername]
    guard usernameField.waitForExistence(timeout: 5) else {
      return
    }

    enterText(username, into: E2EIdentifier.signUpUsername, in: app)
    tap(E2EIdentifier.signUpContinue, in: app)
  }

  private func completeMissingEmailAddressIfNeeded(email: String, in app: XCUIApplication) {
    let emailField = app.descendants(matching: .any)[E2EIdentifier.signUpEmailAddress]
    guard emailField.waitForExistence(timeout: 10) else {
      return
    }

    enterText(email, into: E2EIdentifier.signUpEmailAddress, in: app)
    tap(E2EIdentifier.signUpContinue, in: app)
    waitForSignUpCodePrepared(in: app)
    enterVerificationCode(verificationCode, into: E2EIdentifier.signUpCode, in: app)
  }

  private func completePhoneCodeSignIn(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let codeField = app.descendants(matching: .any)[E2EIdentifier.signInCode]
    if codeField.waitForExistence(timeout: 10) {
      waitForSignInCodePrepared(in: app, file: file, line: line)
      enterVerificationCode(verificationCode, into: E2EIdentifier.signInCode, in: app, file: file, line: line)
      return
    }

    tap(E2EIdentifier.signInUseAnotherMethod, in: app, file: file, line: line)
    tap(E2EIdentifier.signInPhoneCodeAlternativeMethod, in: app, file: file, line: line)
    waitForSignInCodePrepared(in: app, file: file, line: line)
    enterVerificationCode(verificationCode, into: E2EIdentifier.signInCode, in: app, file: file, line: line)
  }

  private func switchToPhoneNumberIdentifier(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let phoneNumberField = app.descendants(matching: .any)[E2EIdentifier.authStartPhoneNumber]
    if phoneNumberField.waitForExistence(timeout: 2) {
      return
    }

    tap(E2EIdentifier.authStartIdentifierSwitcher, in: app, file: file, line: line)
    XCTAssertTrue(
      phoneNumberField.waitForExistence(timeout: 10),
      "Expected the phone number input after switching identifier type.",
      file: file,
      line: line
    )
  }

  private func completePasswordCollectionIfNeeded(in app: XCUIApplication) {
    let passwordField = app.descendants(matching: .any)[E2EIdentifier.signUpPassword]
    if passwordField.waitForExistence(timeout: 10) {
      enterText(testPassword, into: E2EIdentifier.signUpPassword, in: app)
      tap(E2EIdentifier.signUpContinue, in: app)
      return
    }

    waitForSignedIn(in: app)
  }

  private func completeRequiredUserModelFieldsIfNeeded(
    firstName: String,
    lastName: String,
    in app: XCUIApplication
  ) {
    if app.staticTexts[E2EIdentifier.signedIn].waitForExistence(timeout: 3) {
      return
    }

    let firstNameField = app.descendants(matching: .any)[E2EIdentifier.signUpCompleteProfileFirstName]
    let lastNameField = app.descendants(matching: .any)[E2EIdentifier.signUpCompleteProfileLastName]

    let firstNameExists = firstNameField.waitForExistence(timeout: 10)
    let lastNameExists = lastNameField.waitForExistence(timeout: firstNameExists ? 1 : 10)
    guard firstNameExists || lastNameExists else {
      return
    }

    if firstNameExists {
      enterText(firstName, into: E2EIdentifier.signUpCompleteProfileFirstName, in: app)
    }

    if lastNameExists {
      enterText(lastName, into: E2EIdentifier.signUpCompleteProfileLastName, in: app)
    }

    tap(E2EIdentifier.signUpCompleteProfileContinue, in: app)
  }

  private func completeRequiredLegalConsent(
    in app: XCUIApplication,
    message: String = "Expected required legal consent during sign-up.",
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let legalAccepted = app.descendants(matching: .any)[E2EIdentifier.signUpLegalAccepted]
    XCTAssertTrue(
      legalAccepted.waitForExistence(timeout: 60),
      message,
      file: file,
      line: line
    )
    legalAccepted.tap()
    tap(E2EIdentifier.signUpCompleteProfileContinue, in: app, file: file, line: line)
  }

  private func waitForSignUpCodePrepared(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    waitForCodePrepared(
      in: app,
      message: "Expected sign-up code preparation to finish before entering the verification code.",
      file: file,
      line: line
    )
  }

  private func waitForSignInCodePrepared(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    waitForCodePrepared(
      in: app,
      message: "Expected sign-in code preparation to finish before entering the verification code.",
      file: file,
      line: line
    )
  }

  private func waitForCodePrepared(
    in app: XCUIApplication,
    message: String,
    file: StaticString,
    line: UInt
  ) {
    let resendCooldown = app.buttons.matching(
      NSPredicate(format: "label CONTAINS %@", "Resend (")
    ).firstMatch

    XCTAssertTrue(
      resendCooldown.waitForExistence(timeout: 30),
      message,
      file: file,
      line: line
    )
  }

  private func enterText(
    _ text: String,
    into identifier: String,
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    guard tapInput(identifier, in: app, file: file, line: line) else { return }
    app.typeText(text)
    dismissKeyboardTutorialIfPresent()
  }

  private func enterVerificationCode(
    _ code: String,
    into identifier: String,
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let element = inputElement(withIdentifier: identifier, in: app)
    XCTAssertTrue(element.waitForExistence(timeout: 30), "Expected verification code input '\(identifier)'.", file: file, line: line)
    guard tapInput(identifier, in: app, file: file, line: line) else { return }

    for offset in code.indices {
      app.typeText(String(code[offset]))

      let expectedPrefix = String(code[...offset])
      let isCompleteCode = expectedPrefix.count == code.count
      guard !isCompleteCode else { return }

      let valueMatches = waitForInputValue(
        in: element,
        toHavePrefix: expectedPrefix,
        timeout: 2
      )
      XCTAssertTrue(
        valueMatches,
        "Expected verification code input to contain '\(expectedPrefix)'.",
        file: file,
        line: line
      )
    }
  }

  private func tapInput(
    _ identifier: String,
    in app: XCUIApplication,
    file: StaticString,
    line: UInt
  ) -> Bool {
    let element = inputElement(withIdentifier: identifier, in: app)
    guard element.waitForExistence(timeout: 30) else {
      XCTFail("Expected input '\(identifier)'.", file: file, line: line)
      return false
    }

    if element.isHittable {
      element.tap()
      return true
    }

    let hittableElement = app.descendants(matching: .any)
      .matching(identifier: identifier)
      .allElementsBoundByIndex
      .first { $0.exists && $0.isHittable }

    if let hittableElement {
      hittableElement.tap()
      return true
    }

    guard !element.frame.isEmpty else {
      XCTFail("Expected hittable input '\(identifier)'.", file: file, line: line)
      return false
    }

    app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
      .withOffset(CGVector(dx: element.frame.midX, dy: element.frame.midY))
      .tap()
    return true
  }

  private func enterPhoneNumber(
    _ phoneNumber: String,
    into identifier: String = E2EIdentifier.authStartPhoneNumber,
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let element = focusedPhoneNumberInput(withIdentifier: identifier, in: app, file: file, line: line)
    let digits = phoneNumber.filter(\.isWholeNumber)

    for offset in digits.indices {
      let digit = digits[offset]
      app.typeText(String(digit))

      let expectedPrefix = String(digits[...offset])
      XCTAssertTrue(
        waitForPhoneNumberDigits(in: element, toHavePrefix: expectedPrefix, timeout: 2),
        "Expected phone number input to contain '\(expectedPrefix)'. Actual value: '\(phoneNumberInputValue(in: element))'.",
        file: file,
        line: line
      )
    }

    XCTAssertTrue(
      waitForPhoneNumberDigits(in: element, toEqual: digits, timeout: 5),
      "Expected phone number input to contain '\(digits)' before continuing. Actual value: '\(phoneNumberInputValue(in: element))'.",
      file: file,
      line: line
    )
  }

  private func focusedPhoneNumberInput(
    withIdentifier identifier: String,
    in app: XCUIApplication,
    file: StaticString,
    line: UInt
  ) -> XCUIElement {
    let textField = app.textFields[identifier].firstMatch
    if textField.waitForExistence(timeout: 2) {
      textField.tap()
      return textField
    }

    let container = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    XCTAssertTrue(
      container.waitForExistence(timeout: 30),
      "Expected phone number input.",
      file: file,
      line: line
    )
    container.tap()

    XCTAssertTrue(
      textField.waitForExistence(timeout: 10),
      "Expected focused phone number text field.",
      file: file,
      line: line
    )
    return textField
  }

  private func waitForPhoneNumberDigits(
    in element: XCUIElement,
    toHavePrefix expectedPrefix: String,
    timeout: TimeInterval
  ) -> Bool {
    waitForPhoneNumberDigits(in: element, timeout: timeout) { digits in
      digits.hasPrefix(expectedPrefix)
    }
  }

  private func waitForPhoneNumberDigits(
    in element: XCUIElement,
    toEqual expectedDigits: String,
    timeout: TimeInterval
  ) -> Bool {
    waitForPhoneNumberDigits(in: element, timeout: timeout) { digits in
      digits == expectedDigits
    }
  }

  private func waitForPhoneNumberDigits(
    in element: XCUIElement,
    timeout: TimeInterval,
    matches: (String) -> Bool
  ) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if matches(phoneNumberDigits(in: element)) {
        return true
      }

      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }

    return matches(phoneNumberDigits(in: element))
  }

  private func waitForInputValue(
    in element: XCUIElement,
    toHavePrefix expectedPrefix: String,
    timeout: TimeInterval
  ) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      guard element.exists else { return false }

      if inputValue(in: element).hasPrefix(expectedPrefix) {
        return true
      }

      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }

    guard element.exists else { return false }

    return inputValue(in: element).hasPrefix(expectedPrefix)
  }

  private func inputValue(in element: XCUIElement) -> String {
    element.value as? String ?? ""
  }

  private func phoneNumberDigits(in element: XCUIElement) -> String {
    phoneNumberInputValue(in: element).filter(\.isWholeNumber)
  }

  private func phoneNumberInputValue(in element: XCUIElement) -> String {
    element.value as? String ?? ""
  }

  private func inputElement(withIdentifier identifier: String, in app: XCUIApplication) -> XCUIElement {
    let textField = app.textFields[identifier].firstMatch
    if textField.waitForExistence(timeout: 1) {
      return textField
    }

    let secureTextField = app.secureTextFields[identifier].firstMatch
    if secureTextField.waitForExistence(timeout: 1) {
      return secureTextField
    }

    return app.descendants(matching: .any).matching(identifier: identifier).firstMatch
  }

  private func tap(
    _ identifier: String,
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let element = app.descendants(matching: .any)[identifier]
    guard waitForElementHittable(element, timeout: 30) else {
      XCTFail("Expected tappable element '\(identifier)' to become hittable.", file: file, line: line)
      return
    }

    element.tap()
  }

  private func tapWhenEnabled(
    _ identifier: String,
    in app: XCUIApplication,
    timeout: TimeInterval = 30,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let element = app.descendants(matching: .any)[identifier]
    XCTAssertTrue(
      waitForElementEnabled(element, timeout: timeout),
      "Expected enabled tappable element '\(identifier)'.",
      file: file,
      line: line
    )
    element.tap()
  }

  private func tapWhenEnabled(
    matchingIdentifierPrefix identifierPrefix: String,
    in app: XCUIApplication,
    timeout: TimeInterval = 30,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    guard let element = waitForHittableElement(matchingIdentifierPrefix: identifierPrefix, in: app, timeout: timeout) else {
      XCTFail("Expected enabled tappable element with identifier prefix '\(identifierPrefix)'.", file: file, line: line)
      return
    }

    element.tap()
  }

  private func tapWhenHittable(
    _ identifier: String,
    in app: XCUIApplication,
    timeout: TimeInterval = 30,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    guard let element = waitForHittableElement(withIdentifier: identifier, in: app, timeout: timeout) else {
      XCTFail("Expected hittable tappable element '\(identifier)'.", file: file, line: line)
      return
    }

    element.tap()
  }

  private func tapWhenHittableAfterScrolling(
    _ identifier: String,
    in app: XCUIApplication,
    timeout: TimeInterval = 30,
    maxScrolls: Int = 5,
    message: String? = nil,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let deadline = Date().addingTimeInterval(timeout)

    for _ in 0 ... maxScrolls {
      let probeDeadline = min(deadline, Date().addingTimeInterval(1))
      while Date() < probeDeadline {
        if let element = hittableElement(withIdentifier: identifier, in: app) {
          element.tap()
          return
        }

        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
      }

      guard Date() < deadline else { break }
      scrollUp(in: app)
    }

    guard let element = waitForHittableElement(withIdentifier: identifier, in: app, timeout: 2) else {
      XCTFail(
        message ?? "Expected hittable tappable element '\(identifier)' after scrolling.",
        file: file,
        line: line
      )
      return
    }

    element.tap()
  }

  private func dismissKeyboardIfPresent(in app: XCUIApplication) {
    let keyboard = app.keyboards.firstMatch
    guard keyboard.waitForExistence(timeout: 1) else { return }

    let doneButton = keyboard.buttons["Done"].firstMatch
    if doneButton.waitForExistence(timeout: 1), doneButton.isHittable {
      doneButton.tap()
    } else {
      app.typeText("\n")
    }

    _ = keyboard.waitForNonExistence(timeout: 2)
  }

  private func waitForHittableElement(
    withIdentifier identifier: String,
    in app: XCUIApplication,
    timeout: TimeInterval
  ) -> XCUIElement? {
    let deadline = Date().addingTimeInterval(timeout)

    repeat {
      if let element = hittableElement(withIdentifier: identifier, in: app) {
        return element
      }

      RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    } while Date() < deadline

    return hittableElement(withIdentifier: identifier, in: app)
  }

  private func hittableElement(withIdentifier identifier: String, in app: XCUIApplication) -> XCUIElement? {
    app.descendants(matching: .any)
      .matching(identifier: identifier)
      .allElementsBoundByIndex
      .first { $0.exists && $0.isEnabled && $0.isHittable }
  }

  private func waitForHittableElement(
    matchingIdentifierPrefix identifierPrefix: String,
    in app: XCUIApplication,
    timeout: TimeInterval
  ) -> XCUIElement? {
    let deadline = Date().addingTimeInterval(timeout)

    repeat {
      if let element = hittableElement(matchingIdentifierPrefix: identifierPrefix, in: app) {
        return element
      }

      RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    } while Date() < deadline

    return hittableElement(matchingIdentifierPrefix: identifierPrefix, in: app)
  }

  private func hittableElement(matchingIdentifierPrefix identifierPrefix: String, in app: XCUIApplication) -> XCUIElement? {
    app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", identifierPrefix))
      .allElementsBoundByIndex
      .first { $0.exists && $0.isEnabled && $0.isHittable }
  }

  private func scrollUp(in app: XCUIApplication) {
    if let scrollView = app.scrollViews.allElementsBoundByIndex.first(where: { $0.exists && $0.isHittable }) {
      scrollView.swipeUp()
    } else {
      app.swipeUp()
    }
  }

  private func waitForElementEnabled(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
    let predicate = NSPredicate(format: "exists == true AND enabled == true")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
    return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
  }

  private func waitForElementHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
    let predicate = NSPredicate(format: "exists == true AND enabled == true AND hittable == true")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
    return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
  }

  private func waitForSignedIn(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertTrue(
      app.staticTexts[E2EIdentifier.signedIn].waitForExistence(timeout: 45),
      "Expected the E2EHost signed-in state.",
      file: file,
      line: line
    )
  }

  private func waitForSignedOut(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertTrue(
      app.staticTexts[E2EIdentifier.signedOut].waitForExistence(timeout: 30),
      "Expected the E2EHost signed-out state.",
      file: file,
      line: line
    )
  }

  private func waitForSessionPending(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertTrue(
      app.staticTexts[E2EIdentifier.sessionPending].waitForExistence(timeout: 45),
      "Expected the E2EHost pending-session state.",
      file: file,
      line: line
    )
  }

  private func waitForSessionActive(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertTrue(
      app.staticTexts[E2EIdentifier.sessionActive].waitForExistence(timeout: 45),
      "Expected the E2EHost active-session state.",
      file: file,
      line: line
    )
  }

  private func waitForUserProfileCurrentUser(
    _ userID: String,
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertTrue(
      app.descendants(matching: .any)[E2EIdentifier.userProfileCurrentUser(userID: userID)]
        .waitForExistence(timeout: 45),
      "Expected the user profile to show user '\(userID)'.",
      file: file,
      line: line
    )
  }

  private func waitForCleanupComplete(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertTrue(
      app.staticTexts[E2EIdentifier.cleanupComplete].waitForExistence(timeout: 45),
      "Expected E2EHost in-app cleanup to finish.",
      file: file,
      line: line
    )
  }

  private func assertPendingTasksContain(
    _ task: String,
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let pendingTasks = app.staticTexts[E2EIdentifier.pendingTasks]
    XCTAssertTrue(
      pendingTasks.waitForExistence(timeout: 30),
      "Expected pending session tasks.",
      file: file,
      line: line
    )
    XCTAssertTrue(
      pendingTasks.label.contains(task),
      "Expected pending tasks to contain '\(task)', got '\(pendingTasks.label)'.",
      file: file,
      line: line
    )
  }

  private func dismissSavePasswordPromptIfPresent(in app: XCUIApplication, timeout: TimeInterval = 5) {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let notNowButtons = [
      app.buttons["Not Now"].firstMatch,
      springboard.buttons["Not Now"].firstMatch,
    ]
    guard let initialNotNowButton = waitForExistingElement(in: notNowButtons, timeout: timeout) else { return }

    var notNowButton = initialNotNowButton
    for _ in 0 ..< 3 {
      if !notNowButton.exists {
        guard let existingNotNowButton = waitForExistingElement(in: notNowButtons, timeout: 0.5) else { return }
        notNowButton = existingNotNowButton
      }
      guard notNowButton.isHittable else {
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        continue
      }

      notNowButton.tap()
      if notNowButton.waitForNonExistence(timeout: 2) {
        return
      }
    }
  }

  private func dismissKeyboardTutorialIfPresent() {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let tutorialMessage = springboard.staticTexts
      .matching(NSPredicate(format: "label CONTAINS %@", "Speed up your typing"))
      .firstMatch
    let continueButton = springboard.buttons["Continue"].firstMatch
    guard tutorialMessage.waitForExistence(timeout: 0.3), waitForElementHittable(continueButton, timeout: 2) else { return }

    continueButton.tap()
    _ = continueButton.waitForNonExistence(timeout: 2)
  }

  private func waitForExistingElement(in elements: [XCUIElement], timeout: TimeInterval) -> XCUIElement? {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
      if let element = elements.first(where: \.exists) {
        return element
      }

      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    } while Date() < deadline

    return elements.first(where: \.exists)
  }

  private func completeUserProfilePasswordChange(
    newPassword: String,
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    tap(E2EIdentifier.userProfileSecurityChangePassword, in: app, file: file, line: line)
    enterText(testPassword, into: E2EIdentifier.userProfileChangePasswordCurrentPassword, in: app, file: file, line: line)
    tapWhenEnabled(E2EIdentifier.userProfileChangePasswordNext, in: app, file: file, line: line)
    enterText(newPassword, into: E2EIdentifier.userProfileChangePasswordNewPassword, in: app, file: file, line: line)
    enterText(newPassword, into: E2EIdentifier.userProfileChangePasswordConfirmPassword, in: app, file: file, line: line)
    tapWhenEnabled(E2EIdentifier.userProfileChangePasswordSave, in: app, timeout: 45, file: file, line: line)
    dismissSavePasswordPromptIfPresent(in: app, timeout: 10)

    XCTAssertTrue(
      app.descendants(matching: .any)[E2EIdentifier.userProfileChangePasswordSave].waitForNonExistence(timeout: 45),
      "Expected the change-password sheet to dismiss after saving.",
      file: file,
      line: line
    )
  }

  private func completeUserProfileAuthenticatorAppMfaSetup(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    tap(E2EIdentifier.userProfileSecurityAddMfa, in: app, file: file, line: line)
    tapWhenEnabled(E2EIdentifier.userProfileMfaAuthenticatorApp, in: app, timeout: 45, file: file, line: line)

    let secretElement = app.descendants(matching: .any)[E2EIdentifier.userProfileMfaTotpSecret]
    XCTAssertTrue(
      secretElement.waitForExistence(timeout: 45),
      "Expected the user profile TOTP setup secret.",
      file: file,
      line: line
    )
    let secret = secretElement.label

    tap(E2EIdentifier.userProfileMfaTotpContinue, in: app, file: file, line: line)
    waitForStableTOTPWindow()
    let code = try Self.currentTOTPCode(secret: secret)
    enterVerificationCode(code, into: E2EIdentifier.userProfileMfaVerificationCode, in: app, file: file, line: line)

    continueUserProfileBackupCodesIfPresent(in: app)
    XCTAssertTrue(
      app.descendants(matching: .any)[E2EIdentifier.userProfileSecurityAddMfa].waitForExistence(timeout: 45),
      "Expected the user profile Security screen after completing TOTP setup.",
      file: file,
      line: line
    )
  }

  private func completeUserProfileSmsCodeMfaSetup(
    phoneNumber: String,
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    tap(E2EIdentifier.userProfileSecurityAddMfa, in: app, file: file, line: line)
    tapWhenEnabled(E2EIdentifier.userProfileMfaSmsCode, in: app, timeout: 45, file: file, line: line)
    tap(E2EIdentifier.userProfileMfaSmsAddPhone, in: app, file: file, line: line)
    enterPhoneNumber(phoneNumber, into: E2EIdentifier.userProfilePhoneNumber, in: app, file: file, line: line)
    tap(E2EIdentifier.userProfilePhoneContinue, in: app, file: file, line: line)
    waitForCodePrepared(
      in: app,
      message: "Expected user-profile phone verification code preparation to finish before entering the verification code.",
      file: file,
      line: line
    )
    enterVerificationCode(verificationCode, into: E2EIdentifier.userProfileMfaVerificationCode, in: app, file: file, line: line)
    tapWhenEnabled(matchingIdentifierPrefix: E2EIdentifier.userProfileMfaSmsPhoneNumber, in: app, timeout: 45, file: file, line: line)
    tapWhenEnabled(E2EIdentifier.userProfileMfaSmsContinue, in: app, timeout: 45, file: file, line: line)

    continueUserProfileBackupCodesIfPresent(in: app)
    XCTAssertTrue(
      app.descendants(matching: .any)[E2EIdentifier.userProfileSecurityAddMfa].waitForExistence(timeout: 45),
      "Expected the user profile Security screen after completing SMS setup.",
      file: file,
      line: line
    )
  }

  private func continueUserProfileBackupCodesIfPresent(in app: XCUIApplication) {
    let backupCodesDone = app.buttons[E2EIdentifier.userProfileBackupCodesDone].firstMatch
    if backupCodesDone.waitForExistence(timeout: 10) {
      backupCodesDone.tap()
    }
  }

  private func deleteAccountFromUserProfileSecurity(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    tap(E2EIdentifier.userProfileSecurityDeleteAccount, in: app, file: file, line: line)
    enterText("DELETE", into: E2EIdentifier.userProfileDeleteAccountConfirmation, in: app, file: file, line: line)
    tapWhenEnabled(E2EIdentifier.userProfileDeleteAccountConfirm, in: app, timeout: 45, file: file, line: line)
  }

  private func completeAuthenticatorAppSetup(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    tap(E2EIdentifier.setupMfaAuthenticatorApp, in: app, file: file, line: line)

    let secretElement = app.descendants(matching: .any)[E2EIdentifier.totpSecret]
    XCTAssertTrue(
      secretElement.waitForExistence(timeout: 30),
      "Expected the TOTP setup secret.",
      file: file,
      line: line
    )
    let secret = secretElement.label

    tap(E2EIdentifier.totpContinue, in: app, file: file, line: line)
    waitForStableTOTPWindow()
    let code = try Self.currentTOTPCode(secret: secret)
    enterVerificationCode(code, into: E2EIdentifier.totpCode, in: app, file: file, line: line)

    continueBackupCodesIfPresent(in: app)
  }

  private func completeSmsCodeMfaSetup(
    phoneNumber: String,
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    tap(E2EIdentifier.setupMfaSmsCode, in: app, file: file, line: line)
    enterPhoneNumber(phoneNumber, into: E2EIdentifier.smsPhoneNumber, in: app, file: file, line: line)
    tap(E2EIdentifier.smsContinue, in: app, file: file, line: line)
    waitForCodePrepared(
      in: app,
      message: "Expected setup-MFA SMS code preparation to finish before entering the verification code.",
      file: file,
      line: line
    )
    enterVerificationCode(verificationCode, into: E2EIdentifier.smsCode, in: app, file: file, line: line)

    continueBackupCodesIfPresent(in: app)
  }

  private func continueBackupCodesIfPresent(in app: XCUIApplication) {
    let backupCodesContinue = app.descendants(matching: .any)[E2EIdentifier.backupCodesContinue]
    if backupCodesContinue.waitForExistence(timeout: 10) {
      backupCodesContinue.tap()
    }
  }

  private func completeChooseOrganizationByAcceptingInvitation(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    tapWhenEnabled(E2EIdentifier.chooseOrganizationInvitationJoin, in: app, file: file, line: line)
    tapWhenEnabled(E2EIdentifier.chooseOrganizationAcceptedInvitation, in: app, timeout: 45, file: file, line: line)
  }

  private func completeChooseOrganizationByCreatingOrganization(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    tapWhenEnabled(E2EIdentifier.chooseOrganizationCreateOrganization, in: app, file: file, line: line)
    tapWhenEnabled(E2EIdentifier.organizationProfileSubmit, in: app, timeout: 60, file: file, line: line)
  }

  private func completeResetPasswordSessionTask(
    newPassword: String,
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    enterText(newPassword, into: E2EIdentifier.resetPasswordNewPassword, in: app, file: file, line: line)
    enterText(newPassword, into: E2EIdentifier.resetPasswordConfirmPassword, in: app, file: file, line: line)
    dismissKeyboardIfPresent(in: app)
    tapWhenHittableAfterScrolling(E2EIdentifier.resetPasswordSubmit, in: app, timeout: 30, file: file, line: line)
  }

  private func currentUserID(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws -> String {
    let element = app.staticTexts[E2EIdentifier.userID]
    XCTAssertTrue(
      element.waitForExistence(timeout: 30),
      "Expected the E2EHost user ID.",
      file: file,
      line: line
    )

    return try XCTUnwrap(
      Self.normalized(element.label),
      "Expected the E2EHost user ID to be non-empty.",
      file: file,
      line: line
    )
  }

  private func setUserPasswordCompromised(
    userID: String,
    publishableKey: String,
    secretKey: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    let url = Self.backendAPIBaseURL(publishableKey: publishableKey)
      .appendingPathComponent("v1")
      .appendingPathComponent("users")
      .appendingPathComponent(userID)
      .appendingPathComponent("password")
      .appendingPathComponent("set_compromised")

    try performBackendAPIPost(
      url: url,
      secretKey: secretKey,
      body: ["revoke_all_sessions": false],
      file: file,
      line: line
    )
  }

  private func performBackendAPIPost(
    url: URL,
    secretKey: String,
    body: [String: Any],
    file: StaticString,
    line: UInt
  ) throws {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(secretKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("2026-05-12", forHTTPHeaderField: "Clerk-API-Version")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let expectation = expectation(description: "Backend API request")
    var result: Result<(HTTPURLResponse, Data), Error>?
    URLSession.shared.dataTask(with: request) { data, response, error in
      if let error {
        result = .failure(error)
      } else if let httpResponse = response as? HTTPURLResponse {
        result = .success((httpResponse, data ?? Data()))
      } else {
        result = .failure(URLError(.badServerResponse))
      }

      expectation.fulfill()
    }.resume()

    wait(for: [expectation], timeout: 30)

    let (response, data) = try XCTUnwrap(
      result,
      "Expected Backend API request to complete.",
      file: file,
      line: line
    ).get()

    guard (200 ..< 300).contains(response.statusCode) else {
      let responseBody = String(data: data, encoding: .utf8) ?? ""
      throw BackendAPIError(statusCode: response.statusCode, responseBody: responseBody)
    }
  }

  private static func backendAPIBaseURL(publishableKey: String) -> URL {
    let rawValue = normalized(ProcessInfo.processInfo.environment["CLERK_E2E_BACKEND_API_URL"])
      ?? inferredBackendAPIBaseURLString(publishableKey: publishableKey)
    let trimmed = rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    guard var url = URL(string: trimmed) else {
      XCTFail("Invalid CLERK_E2E_BACKEND_API_URL: '\(rawValue)'")
      return URL(string: inferredBackendAPIBaseURLString(publishableKey: publishableKey))!
    }

    if url.path == "/v1" {
      url.deleteLastPathComponent()
    }

    return url
  }

  private static func inferredBackendAPIBaseURLString(publishableKey: String) -> String {
    guard let frontendAPIHost = frontendAPIHost(from: publishableKey) else {
      return "https://api.clerk.com"
    }

    if frontendAPIHost.contains("accountsstage") || frontendAPIHost.contains("clerkstage") {
      return "https://api.clerkstage.dev"
    }

    if frontendAPIHost.contains("lclclerk") {
      return "https://api.lclclerk.com"
    }

    return "https://api.clerk.com"
  }

  private static func frontendAPIHost(from publishableKey: String) -> String? {
    let parts = publishableKey.split(separator: "_", maxSplits: 2, omittingEmptySubsequences: false)
    guard parts.count == 3 else {
      return nil
    }

    var encoded = String(parts[2])
    if encoded.hasSuffix("$") {
      encoded.removeLast()
    }

    encoded = encoded
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")

    let padding = encoded.count % 4
    if padding != 0 {
      encoded += String(repeating: "=", count: 4 - padding)
    }

    guard
      let data = Data(base64Encoded: encoded),
      let decoded = String(data: data, encoding: .utf8)
    else {
      return nil
    }

    return decoded.trimmingCharacters(in: CharacterSet(charactersIn: "$"))
  }

  private func waitForStableTOTPWindow() {
    let period: TimeInterval = 30
    let elapsed = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: period)
    guard elapsed > 24 else { return }

    Thread.sleep(forTimeInterval: period - elapsed + 1)
  }

  private static func currentTOTPCode(secret: String, date: Date = Date()) throws -> String {
    let keyData = try base32DecodedData(secret)
    let key = SymmetricKey(data: keyData)
    let counter = UInt64(date.timeIntervalSince1970 / 30)
    let counterData = withUnsafeBytes(of: counter.bigEndian) { Data($0) }
    let hash = Array(HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key))
    let offset = Int(hash[hash.count - 1] & 0x0F)

    let truncatedHash = UInt32(hash[offset] & 0x7F) << 24
      | UInt32(hash[offset + 1] & 0xFF) << 16
      | UInt32(hash[offset + 2] & 0xFF) << 8
      | UInt32(hash[offset + 3] & 0xFF)
    let code = truncatedHash % 1_000_000

    return String(format: "%06d", code)
  }

  private static func base32DecodedData(_ secret: String) throws -> Data {
    let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
    let lookup = Dictionary(uniqueKeysWithValues: alphabet.enumerated().map { ($0.element, UInt8($0.offset)) })
    let characters = secret
      .uppercased()
      .filter { lookup[$0] != nil }

    guard !characters.isEmpty else {
      throw TOTPError.invalidSecret
    }

    var buffer = 0
    var bitsLeft = 0
    var bytes = [UInt8]()

    for character in characters {
      guard let value = lookup[character] else {
        throw TOTPError.invalidSecret
      }

      buffer = (buffer << 5) | Int(value)
      bitsLeft += 5

      if bitsLeft >= 8 {
        bitsLeft -= 8
        bytes.append(UInt8((buffer >> bitsLeft) & 0xFF))
      }
    }

    guard !bytes.isEmpty else {
      throw TOTPError.invalidSecret
    }

    return Data(bytes)
  }

  private func cleanupAccountIfNeeded(in app: XCUIApplication) {
    if app.staticTexts[E2EIdentifier.signedOut].exists {
      return
    }

    dismissWebAuthenticationSessionIfPresent(in: app)
    dismissSavePasswordPromptIfPresent(in: app, timeout: 1)

    if app.staticTexts[E2EIdentifier.signedOut].exists {
      return
    }

    E2ECleanupCommand.post()
    waitForCleanupComplete(in: app)
    waitForSignedOut(in: app)
  }

  private func dismissWebAuthenticationSessionIfPresent(in app: XCUIApplication) {
    let cancelButton = app.buttons["Cancel"].firstMatch
    if cancelButton.waitForExistence(timeout: 1) {
      cancelButton.tap()
    }
  }
}
