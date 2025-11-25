//
//  AuthAndClientIntegrationTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

/// Integration tests for SignIn, SignUp, and Client domains.
///
/// These tests make real API calls to a Clerk instance and verify that the SDK correctly
/// integrates with the Clerk API. Unlike unit tests which use mocked responses, these
/// tests verify end-to-end functionality including proper JSON decoding.
///
/// Tests are ordered so that Client.get() runs after SignIn and SignUp tests,
/// allowing verification of the client state after auth operations.
///
/// Requirements:
/// - Network access
/// - Valid Clerk test instance (configured via `integrationTestPublishableKey`)
/// - Test instance should be stable and not modified by other processes
@MainActor
@Suite(.serialized)
struct AuthAndClientIntegrationTests {
  /// Shared test email used across SignUp and SignIn tests.
  /// Using a fixed email so SignIn can authenticate with the account created by SignUp.
  private static let testEmail = "test+clerk_test@example.com"

  init() {
    configureClerkForIntegrationTesting()
  }

  // MARK: - SignUp Test

  /// Tests the complete SignUp flow: create -> prepare -> attempt
  /// Verifies all enum values are properly decoded without unknown cases.
  /// This test runs first to create an account that SignIn will use.
  @Test
  func test1_signUpCreatePrepareAttempt() async throws {
    // Sign out first to ensure a clean slate
    try? await Clerk.shared.signOut()

    // Step 1: Create a SignUp with an email address
    // Using test email format - test+clerk_test@email.com emails are test emails
    let signUp = try await SignUp.create(strategy: .standard(emailAddress: Self.testEmail))

    // Verify SignUp status is not unknown
    verifySignUpStatus(signUp.status)

    // Verify required fields don't contain unknown values
    for field in signUp.requiredFields {
      verifySignUpField(field)
    }

    // Verify optional fields don't contain unknown values
    for field in signUp.optionalFields {
      verifySignUpField(field)
    }

    // Verify missing fields don't contain unknown values
    for field in signUp.missingFields {
      verifySignUpField(field)
    }

    // Verify unverified fields don't contain unknown values
    for field in signUp.unverifiedFields {
      verifySignUpField(field)
    }

    // Verify verifications don't contain unknown values
    for (_, verification) in signUp.verifications {
      if let verification = verification {
        if let status = verification.status {
          verifyVerificationStatus(status)
        }
        if let strategy = verification.strategy {
          verifyFactorStrategy(strategy)
        }
      }
    }

    // Step 2: Prepare verification (email_code)
    // This will send a code to the email address
    let preparedSignUp = try await signUp.prepareVerification(strategy: .emailCode)

    // Verify status after prepare
    verifySignUpStatus(preparedSignUp.status)

    // Verify fields after prepare
    for field in preparedSignUp.requiredFields {
      verifySignUpField(field)
    }
    for field in preparedSignUp.optionalFields {
      verifySignUpField(field)
    }
    for field in preparedSignUp.missingFields {
      verifySignUpField(field)
    }
    for field in preparedSignUp.unverifiedFields {
      verifySignUpField(field)
    }

    // Verify verifications after prepare
    for (_, verification) in preparedSignUp.verifications {
      if let verification = verification {
        if let status = verification.status {
          verifyVerificationStatus(status)
        }
        if let strategy = verification.strategy {
          verifyFactorStrategy(strategy)
        }
      }
    }

    // Step 3: Attempt verification with the test verification code
    // For test emails (test+clerk_test@...), the code 424242 always works
    let attemptedSignUp = try await preparedSignUp.attemptVerification(strategy: .emailCode(code: "424242"))

    // Verify status after attempt
    verifySignUpStatus(attemptedSignUp.status)

    // Verify fields after attempt
    for field in attemptedSignUp.requiredFields {
      verifySignUpField(field)
    }
    for field in attemptedSignUp.optionalFields {
      verifySignUpField(field)
    }
    for field in attemptedSignUp.missingFields {
      verifySignUpField(field)
    }
    for field in attemptedSignUp.unverifiedFields {
      verifySignUpField(field)
    }

    // Verify verifications after attempt
    for (_, verification) in attemptedSignUp.verifications {
      if let verification = verification {
        if let status = verification.status {
          verifyVerificationStatus(status)
        }
        if let strategy = verification.strategy {
          verifyFactorStrategy(strategy)
        }
      }
    }

    // Sign out so that SignIn test can sign in with the new account
    try await Clerk.shared.signOut()
  }

  // MARK: - SignIn Test

  /// Tests the complete SignIn flow: create -> prepare -> attempt
  /// Verifies all enum values are properly decoded without unknown cases.
  /// This test runs after SignUp to sign in with the newly created account.
  @Test
  func test2_signInCreatePrepareAttempt() async throws {
    // Step 1: Create a SignIn with the same email used in SignUp
    // Using test email format - test+clerk_test@email.com emails are test emails
    let signIn = try await SignIn.create(strategy: .identifier(Self.testEmail))

    // Verify SignIn status is not unknown
    verifySignInStatus(signIn.status)

    // Verify supported identifiers don't contain unknown values
    if let supportedIdentifiers = signIn.supportedIdentifiers {
      for identifier in supportedIdentifiers {
        verifySignInIdentifier(identifier)
      }
    }

    // Verify supported first factors don't contain unknown strategies
    if let supportedFirstFactors = signIn.supportedFirstFactors {
      for factor in supportedFirstFactors {
        verifyFactorStrategy(factor.strategy)
      }
    }

    // Verify supported second factors don't contain unknown strategies
    if let supportedSecondFactors = signIn.supportedSecondFactors {
      for factor in supportedSecondFactors {
        verifyFactorStrategy(factor.strategy)
      }
    }

    // Verify first factor verification status if present
    if let verification = signIn.firstFactorVerification {
      if let status = verification.status {
        verifyVerificationStatus(status)
      }
      if let strategy = verification.strategy {
        verifyFactorStrategy(strategy)
      }
    }

    // Step 2: Prepare first factor verification (email_code)
    // This will send a code to the email address
    let preparedSignIn = try await signIn.prepareFirstFactor(strategy: .emailCode())

    // Verify status after prepare
    verifySignInStatus(preparedSignIn.status)

    // Verify first factor verification is set up correctly
    if let verification = preparedSignIn.firstFactorVerification {
      if let status = verification.status {
        verifyVerificationStatus(status)
      }
      if let strategy = verification.strategy {
        verifyFactorStrategy(strategy)
      }
    }

    // Verify supported factors after prepare
    if let supportedFirstFactors = preparedSignIn.supportedFirstFactors {
      for factor in supportedFirstFactors {
        verifyFactorStrategy(factor.strategy)
      }
    }

    // Step 3: Attempt first factor with the test verification code
    // For test emails (test+clerk_test@...), the code 424242 always works
    let attemptedSignIn = try await preparedSignIn.attemptFirstFactor(strategy: .emailCode(code: "424242"))

    // Verify status after attempt
    verifySignInStatus(attemptedSignIn.status)

    // Verify first factor verification after attempt
    if let verification = attemptedSignIn.firstFactorVerification {
      if let status = verification.status {
        verifyVerificationStatus(status)
      }
      if let strategy = verification.strategy {
        verifyFactorStrategy(strategy)
      }
    }

    // Verify supported factors after attempt
    if let supportedFirstFactors = attemptedSignIn.supportedFirstFactors {
      for factor in supportedFirstFactors {
        verifyFactorStrategy(factor.strategy)
      }
    }

    if let supportedSecondFactors = attemptedSignIn.supportedSecondFactors {
      for factor in supportedSecondFactors {
        verifyFactorStrategy(factor.strategy)
      }
    }
  }

  // MARK: - Client Test

  /// Tests Client.get() and verifies all enum values are properly decoded.
  /// This test runs after SignIn and SignUp tests to verify client state.
  @Test
  func test3_getClient() async throws {
    // Get the current client
    let client = try await Client.get()

    // Client may be nil if no client exists yet, which is valid
    guard let client = client else {
      // No client exists, which is a valid state - nothing more to verify
      return
    }

    // Verify all sessions have valid status values
    for session in client.sessions {
      verifySessionStatus(session.status)
    }

    // Verify SignIn if present
    if let signIn = client.signIn {
      verifySignInStatus(signIn.status)

      // Verify supported identifiers
      if let supportedIdentifiers = signIn.supportedIdentifiers {
        for identifier in supportedIdentifiers {
          verifySignInIdentifier(identifier)
        }
      }

      // Verify supported first factors
      if let supportedFirstFactors = signIn.supportedFirstFactors {
        for factor in supportedFirstFactors {
          verifyFactorStrategy(factor.strategy)
        }
      }

      // Verify supported second factors
      if let supportedSecondFactors = signIn.supportedSecondFactors {
        for factor in supportedSecondFactors {
          verifyFactorStrategy(factor.strategy)
        }
      }

      // Verify first factor verification
      if let verification = signIn.firstFactorVerification {
        if let status = verification.status {
          verifyVerificationStatus(status)
        }
        if let strategy = verification.strategy {
          verifyFactorStrategy(strategy)
        }
      }

      // Verify second factor verification
      if let verification = signIn.secondFactorVerification {
        if let status = verification.status {
          verifyVerificationStatus(status)
        }
        if let strategy = verification.strategy {
          verifyFactorStrategy(strategy)
        }
      }
    }

    // Verify SignUp if present
    if let signUp = client.signUp {
      verifySignUpStatus(signUp.status)

      // Verify required fields
      for field in signUp.requiredFields {
        verifySignUpField(field)
      }

      // Verify optional fields
      for field in signUp.optionalFields {
        verifySignUpField(field)
      }

      // Verify missing fields
      for field in signUp.missingFields {
        verifySignUpField(field)
      }

      // Verify unverified fields
      for field in signUp.unverifiedFields {
        verifySignUpField(field)
      }

      // Verify verifications
      for (_, verification) in signUp.verifications {
        if let verification = verification {
          if let status = verification.status {
            verifyVerificationStatus(status)
          }
          if let strategy = verification.strategy {
            verifyFactorStrategy(strategy)
          }
        }
      }
    }
  }

  // MARK: - Helper Methods

  private func verifySignInStatus(_ status: SignIn.Status) {
    switch status {
    case .complete, .needsIdentifier, .needsFirstFactor, .needsSecondFactor, .needsNewPassword:
      break // Valid cases
    case .unknown(let value):
      Issue.record("SignIn.Status returned unknown value: \(value)")
      #expect(Bool(false), "SignIn.Status should not be unknown, got: \(value)")
    }
  }

  private func verifySignInIdentifier(_ identifier: SignIn.Identifier) {
    switch identifier {
    case .emailAddress, .phoneNumber, .web3Wallet, .username, .passkey:
      break // Valid cases
    case .unknown(let value):
      Issue.record("SignIn.Identifier returned unknown value: \(value)")
      #expect(Bool(false), "SignIn.Identifier should not be unknown, got: \(value)")
    }
  }

  private func verifySignUpStatus(_ status: SignUp.Status) {
    switch status {
    case .abandoned, .missingRequirements, .complete:
      break // Valid cases
    case .unknown(let value):
      Issue.record("SignUp.Status returned unknown value: \(value)")
      #expect(Bool(false), "SignUp.Status should not be unknown, got: \(value)")
    }
  }

  private func verifySignUpField(_ field: SignUpField) {
    switch field {
    case .emailAddress, .phoneNumber, .web3Wallet, .username, .passkey, .password,
         .authenticatorApp, .ticket, .backupCode, .firstName, .lastName,
         .saml, .enterpriseSSO, .legalAccepted, .customAction:
      break // Valid cases
    case .unknown(let value):
      Issue.record("SignUpField returned unknown value: \(value)")
      #expect(Bool(false), "SignUpField should not be unknown, got: \(value)")
    }
  }

  private func verifySessionStatus(_ status: Session.SessionStatus) {
    switch status {
    case .abandoned, .active, .pending, .ended, .expired, .removed, .replaced, .revoked:
      break // Valid cases
    case .unknown(let value):
      Issue.record("Session.SessionStatus returned unknown value: \(value)")
      #expect(Bool(false), "Session.SessionStatus should not be unknown, got: \(value)")
    }
  }

  private func verifyFactorStrategy(_ strategy: FactorStrategy) {
    switch strategy {
    case .password, .emailCode, .phoneCode, .passkey, .totp, .backupCode, .ticket,
         .resetPasswordEmailCode, .resetPasswordPhoneCode, .saml, .enterpriseSSO,
         .oauth:
      break // Valid cases
    case .unknown(let value):
      Issue.record("FactorStrategy returned unknown value: \(value)")
      #expect(Bool(false), "FactorStrategy should not be unknown, got: \(value)")
    }
  }

  private func verifyVerificationStatus(_ status: Verification.Status) {
    switch status {
    case .unverified, .verified, .transferable, .failed, .expired:
      break // Valid cases
    case .unknown(let value):
      Issue.record("Verification.Status returned unknown value: \(value)")
      #expect(Bool(false), "Verification.Status should not be unknown, got: \(value)")
    }
  }
}
