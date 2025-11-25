//
//  AuthAndClientIntegrationTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

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
  /// Shared test email used across SignUp and SignIn tests.
  /// Using a fixed email so SignIn can authenticate with the account created by SignUp.
  private static let testEmail = "test+clerk_test@example.com"

  /// Shared test password used across SignUp and SignIn tests.
  private static let testPassword = "Clerk_iOS_Test_2025_XyZ9#mK2$pL7"

  /// Test verification code used for email code verification in SignUp and SignIn tests.
  private static let testVerificationCode = "424242"

  // MARK: - Auth Tests

  /// Tests the complete SignUp and SignIn flows: create -> prepare -> attempt
  /// Verifies that SignUp and SignIn objects are successfully decoded from the API.
  @Test
  func signUpAndSignIn() async throws {
    configureClerkForIntegrationTesting(keyName: "with-email-codes")
    // Delete any existing test account to ensure a clean slate
    await deleteTestAccountIfExists()

    // MARK: - SignUp Flow

    // Step 1: Create a SignUp with an email address and password
    // Using test email format - test+clerk_test@email.com emails are test emails
    let signUp = try await SignUp.create(strategy: .standard(emailAddress: Self.testEmail, password: Self.testPassword))

    // Step 2: Prepare verification (email_code)
    // This will send a code to the email address
    let preparedSignUp = try await signUp.prepareVerification(strategy: .emailCode)

    // Step 3: Attempt verification with the test verification code
    try await preparedSignUp.attemptVerification(strategy: .emailCode(code: Self.testVerificationCode))

    // Sign out so that SignIn can sign in with the new account
    try await Clerk.shared.signOut()

    // MARK: - SignIn Flow

    // Step 1: Create a SignIn with the same email used in SignUp
    let signIn = try await SignIn.create(strategy: .identifier(Self.testEmail))

    // Step 2: Prepare first factor verification (email_code)
    // This will send a code to the email address
    let preparedSignIn = try await signIn.prepareFirstFactor(strategy: .emailCode())

    // Step 3: Attempt first factor with the test verification code
    try await preparedSignIn.attemptFirstFactor(strategy: .emailCode(code: Self.testVerificationCode))

    // Sign out after completing sign in
    try await Clerk.shared.user?.delete()
  }

  // MARK: - Helper Methods

  /// Deletes the test account if it exists by attempting to sign in and then deleting.
  /// This ensures a clean slate before starting sign up.
  private func deleteTestAccountIfExists() async {
    // Try to sign in with the test email
    do {
      try await SignIn.create(strategy: .identifier(Self.testEmail, password: Self.testPassword))
      try await Clerk.shared.user?.delete()
    } catch {
      // Account doesn't exist or sign in failed, which is fine
    }
  }
}
