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

final class E2EHostE2ETests: XCTestCase {
  private static let defaultPublishableKeyName = "with-email-codes"
  private static let legalConsentPublishableKeyName = "with-legal-consent"
  private static let setupMfaPublishableKeyName = "with-session-tasks-setup-mfa"

  private let verificationCode = "424242"
  private let testPassword = "ClerkIOS2026E2ETestPassword9!"

  private var app: XCUIApplication?
  private var cleanupLaunchConfiguration: E2ELaunchConfiguration?

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  override func tearDownWithError() throws {
    if let app, let testRun, testRun.failureCount > 0 {
      add(XCTAttachment(screenshot: app.screenshot()))
    }

    if let app {
      deleteAccountIfPossible(in: app)
      cleanupAccountOnLaunchIfNeeded(after: app)
    }

    app?.terminate()
    app = nil
    cleanupLaunchConfiguration = nil
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

  func testSignUpCompletesSetupMfaTask() throws {
    let publishableKey = try requiredPublishableKey(named: Self.setupMfaPublishableKeyName)
    let email = Self.makeUniqueTestEmail()
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"

    app = launchApp(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.setupMfaPublishableKeyName,
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

  func testOAuthSignUpCompletesLegalConsent() throws {
    let publishableKey = try requiredPublishableKey(named: Self.legalConsentPublishableKeyName)
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"

    app = launchApp(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.legalConsentPublishableKeyName,
      keychainService: keychainService
    )
    guard let signUpApp = app else { return }

    openAuth(in: signUpApp)
    completeE2EOAuthLegalConsentSignUp(in: signUpApp)
    waitForSignedIn(in: signUpApp)
    waitForSessionActive(in: signUpApp)

    tap(E2EIdentifier.deleteAccount, in: signUpApp)
    waitForSignedOut(in: signUpApp)
  }

  func testCleanupOnLaunchDeletesRestoredPendingUser() throws {
    let publishableKey = try requiredPublishableKey(named: Self.setupMfaPublishableKeyName)
    let email = Self.makeUniqueTestEmail()
    let keychainService = "com.clerk.E2EHost.\(UUID().uuidString)"
    let configuration = E2ELaunchConfiguration(
      authMode: "signUp",
      publishableKey: publishableKey,
      publishableKeyName: Self.setupMfaPublishableKeyName,
      keychainService: keychainService
    )

    cleanupLaunchConfiguration = configuration
    app = launchApp(configuration: configuration)
    guard let signUpApp = app else { return }
    waitForSignedOut(in: signUpApp)

    openAuth(in: signUpApp)
    completeEmailCodeSignUp(email: email, in: signUpApp)
    waitForSignedIn(in: signUpApp)
    waitForSessionPending(in: signUpApp)
    dismissSavePasswordPromptIfPresent(in: signUpApp)
    signUpApp.terminate()

    let cleanupApp = launchApp(configuration: configuration, cleanupOnLaunch: true)
    app = cleanupApp
    waitForCleanupComplete(in: cleanupApp)
    waitForSignedOut(in: cleanupApp)
  }
}

extension E2EHostE2ETests {
  fileprivate enum E2EIdentifier {
    static let authStartIdentifier = "clerk.auth.start.identifier"
    static let authStartContinue = "clerk.auth.start.continue"
    static let e2eOAuthProvider = "Continue with E2E OAuth Provider"
    static let signUpCode = "clerk.auth.signUp.code"
    static let signUpPassword = "clerk.auth.signUp.password"
    static let signUpContinue = "clerk.auth.signUp.continue"
    static let signUpCompleteProfileContinue = "clerk.auth.signUp.completeProfile.continue"
    static let signUpLegalAccepted = "clerk.auth.signUp.legalAccepted"
    static let signInPassword = "clerk.auth.signIn.password"
    static let signInContinue = "clerk.auth.signIn.continue"
    static let signedIn = "e2e.auth.signedIn"
    static let signedOut = "e2e.auth.signedOut"
    static let sessionActive = "e2e.auth.sessionActive"
    static let sessionPending = "e2e.auth.sessionPending"
    static let sessionStatus = "e2e.auth.sessionStatus"
    static let pendingTasks = "e2e.auth.pendingTasks"
    static let cleanupComplete = "e2e.auth.cleanupComplete"
    static let signOut = "e2e.auth.signOut"
    static let deleteAccount = "e2e.auth.deleteAccount"
    static let setupMfaAuthenticatorApp = "clerk.auth.sessionTask.setupMfa.authenticatorApp"
    static let totpSecret = "clerk.auth.sessionTask.totp.secret"
    static let totpContinue = "clerk.auth.sessionTask.totp.continue"
    static let totpCode = "clerk.auth.sessionTask.totp.code"
    static let backupCodesContinue = "clerk.auth.sessionTask.backupCodes.continue"
  }

  fileprivate enum TOTPError: Error {
    case invalidSecret
  }

  fileprivate static func makeUniqueTestEmail() -> String {
    let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    return "clerk_ios_e2e+clerk_test_\(suffix)@example.com"
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
    cleanupLaunchConfiguration = configuration

    let app = launchApp(configuration: configuration)
    waitForSignedOut(in: app)
    return app
  }

  private func launchApp(
    configuration: E2ELaunchConfiguration,
    cleanupOnLaunch: Bool = false
  ) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "-AppleLanguages", "(en)",
      "-AppleLocale", "en_US",
    ]
    var launchEnvironment = [
      "CLERK_PUBLISHABLE_KEY": configuration.publishableKey,
      "CLERK_E2E_MODE": "1",
      "CLERK_E2E_KEY_NAME": configuration.publishableKeyName,
      "CLERK_E2E_AUTH_MODE": configuration.authMode,
      "CLERK_E2E_KEYCHAIN_SERVICE": configuration.keychainService,
    ]

    if cleanupOnLaunch {
      launchEnvironment["CLERK_E2E_CLEANUP_ON_LAUNCH"] = "1"
    }

    app.launchEnvironment = launchEnvironment
    app.launch()
    return app
  }

  private func openAuth(in app: XCUIApplication) {
    let signInButton = app.buttons["Sign in"].firstMatch
    XCTAssertTrue(signInButton.waitForExistence(timeout: 20), "Expected the E2EHost sign-in button.")
    signInButton.tap()
  }

  private func completeEmailCodeSignUp(email: String, in app: XCUIApplication) {
    enterText(email, into: E2EIdentifier.authStartIdentifier, in: app)
    tap(E2EIdentifier.authStartContinue, in: app)
    waitForSignUpCodePrepared(in: app)
    enterText(verificationCode, into: E2EIdentifier.signUpCode, in: app)
    completePasswordCollectionIfNeeded(in: app)
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

  private func completeE2EOAuthLegalConsentSignUp(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let providerButton = app.buttons[E2EIdentifier.e2eOAuthProvider].firstMatch
    XCTAssertTrue(
      providerButton.waitForExistence(timeout: 30),
      "Expected the E2E OAuth provider button.",
      file: file,
      line: line
    )
    providerButton.tap()

    continueWebAuthenticationSessionIfNeeded(in: app)
    let legalAccepted = app.descendants(matching: .any)[E2EIdentifier.signUpLegalAccepted]
    XCTAssertTrue(
      legalAccepted.waitForExistence(timeout: 60),
      "Expected legal consent after the E2E OAuth redirect.",
      file: file,
      line: line
    )
    legalAccepted.tap()
    tap(E2EIdentifier.signUpCompleteProfileContinue, in: app, file: file, line: line)
  }

  private func continueWebAuthenticationSessionIfNeeded(in app: XCUIApplication) {
    let predicate = NSPredicate(format: "label == %@ AND enabled == true", "Continue")
    let appContinueButton = app.buttons.matching(predicate).firstMatch
    if appContinueButton.waitForExistence(timeout: 10) {
      appContinueButton.tap()
      return
    }

    let springboardContinueButton = XCUIApplication(bundleIdentifier: "com.apple.springboard")
      .buttons
      .matching(predicate)
      .firstMatch
    if springboardContinueButton.waitForExistence(timeout: 2) {
      springboardContinueButton.tap()
    }
  }

  private func waitForSignUpCodePrepared(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let resendCooldown = app.buttons.matching(
      NSPredicate(format: "label CONTAINS %@", "Resend (")
    ).firstMatch

    XCTAssertTrue(
      resendCooldown.waitForExistence(timeout: 30),
      "Expected sign-up email code preparation to finish before entering the verification code.",
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
    let element = inputElement(withIdentifier: identifier, in: app)
    XCTAssertTrue(element.waitForExistence(timeout: 30), "Expected input '\(identifier)'.", file: file, line: line)
    element.tap()
    app.typeText(text)
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
    XCTAssertTrue(element.waitForExistence(timeout: 30), "Expected tappable element '\(identifier)'.", file: file, line: line)
    element.tap()
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

  private func waitForCleanupComplete(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertTrue(
      app.staticTexts[E2EIdentifier.cleanupComplete].waitForExistence(timeout: 45),
      "Expected E2EHost cleanup-on-launch to finish.",
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
    let notNowButton = app.buttons["Not Now"].firstMatch
    guard notNowButton.waitForExistence(timeout: timeout) else { return }

    notNowButton.tap()
    _ = notNowButton.waitForNonExistence(timeout: 5)
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
    enterText(code, into: E2EIdentifier.totpCode, in: app, file: file, line: line)

    let backupCodesContinue = app.descendants(matching: .any)[E2EIdentifier.backupCodesContinue]
    if backupCodesContinue.waitForExistence(timeout: 10) {
      backupCodesContinue.tap()
    }
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

  private func deleteAccountIfPossible(in app: XCUIApplication) {
    if app.staticTexts[E2EIdentifier.signedOut].exists {
      return
    }

    dismissSavePasswordPromptIfPresent(in: app, timeout: 1)

    if app.staticTexts[E2EIdentifier.signedOut].exists {
      return
    }

    let deleteAccountButton = app.descendants(matching: .any)[E2EIdentifier.deleteAccount]
    guard deleteAccountButton.waitForExistence(timeout: 1) else { return }

    deleteAccountButton.tap()
    _ = app.staticTexts[E2EIdentifier.signedOut].waitForExistence(timeout: 15)
  }

  private func cleanupAccountOnLaunchIfNeeded(after app: XCUIApplication) {
    guard !app.staticTexts[E2EIdentifier.signedOut].exists,
          let cleanupLaunchConfiguration
    else {
      return
    }

    app.terminate()

    let cleanupApp = launchApp(
      configuration: cleanupLaunchConfiguration,
      cleanupOnLaunch: true
    )
    self.app = cleanupApp

    _ = cleanupApp.staticTexts[E2EIdentifier.cleanupComplete].waitForExistence(timeout: 45)
    _ = cleanupApp.staticTexts[E2EIdentifier.signedOut].waitForExistence(timeout: 15)
  }
}
