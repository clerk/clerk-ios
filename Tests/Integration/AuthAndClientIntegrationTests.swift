//
//  AuthAndClientIntegrationTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

@testable import ClerkKit
import Foundation
import Testing

/// Integration tests for SignIn and SignUp domains.
///
/// These tests make real API calls to a Clerk instance and verify that the SDK correctly
/// integrates with the Clerk API. Unlike unit tests which use mocked responses, these
/// tests verify end-to-end functionality including proper JSON decoding.
///
/// Requirements:
/// - Network access
/// - Valid Clerk test instance (configured via `configureClerkForIntegrationTesting(keyName:)`)
/// - Test instance should be stable and not modified by other processes
@MainActor
@Suite(.serialized)
struct AuthAndClientIntegrationTests {
  /// Shared test password used across SignUp and SignIn tests.
  private static let testPassword = "Clerk_iOS_Test_2025_XyZ9#mK2$pL7"

  /// Test verification code used for email code verification in SignUp and SignIn tests.
  private static let testVerificationCode = "424242"

  // MARK: - Auth Tests

  /// Tests the complete SignUp and SignIn flows: create -> prepare -> attempt
  /// Verifies that SignUp and SignIn objects are successfully decoded from the API.
  @Test
  func signUpAndSignIn() async throws {
    let keyName = "with-email-codes"
    guard try configureClerkForIntegrationTesting(keyName: keyName) else {
      return
    }
    let testEmail = Self.makeUniqueTestEmail()
    var capturedError: Error?
    var didCreateSignUp = false

    do {
      // MARK: - SignUp Flow

      // Step 1: Create a SignUp with an email address and password
      // Use a unique test email to avoid collisions across concurrent CI runs.
      let signUp = try await Clerk.shared.auth.signUp(emailAddress: testEmail, password: Self.testPassword)
      didCreateSignUp = true

      // Step 2: Prepare verification (email_code)
      // This will send a code to the email address
      let preparedSignUp = try await signUp.sendEmailCode()

      // Step 3: Attempt verification with the test verification code
      try await preparedSignUp.verifyEmailCode(Self.testVerificationCode)

      // Sign out so that SignIn can sign in with the new account
      try await Clerk.shared.auth.signOut()

      // MARK: - SignIn Flow

      // Step 1: Create a SignIn with the same email used in SignUp
      let signIn = try await Clerk.shared.auth.signIn(testEmail)

      // Step 2: Prepare first factor verification (email_code)
      // This will send a code to the email address
      let preparedSignIn = try await signIn.sendEmailCode()

      // Step 3: Attempt first factor with the test verification code
      try await preparedSignIn.verifyCode(Self.testVerificationCode)
    } catch {
      capturedError = error
    }

    await deleteTestAccountIfExists(email: testEmail, allowPasswordCleanup: didCreateSignUp)

    if let capturedError {
      if try shouldSkipIntegrationTest(capturedError, keyName: keyName) {
        return
      }
      throw capturedError
    }
  }

  private static func makeUniqueTestEmail() -> String {
    let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    return "test+clerk_test_\(suffix)@example.com"
  }

  private func deleteTestAccountIfExists(email: String, allowPasswordCleanup: Bool) async {
    do {
      if let currentUser = Clerk.shared.user {
        try await currentUser.delete()
        return
      }

      guard allowPasswordCleanup else {
        return
      }

      _ = try await Clerk.shared.auth.signInWithPassword(identifier: email, password: Self.testPassword)
      try await Clerk.shared.user?.delete()
    } catch {
      // Best-effort cleanup. Some failure paths may not produce a deletable account.
    }
  }
}
