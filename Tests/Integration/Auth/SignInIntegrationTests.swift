//
//  SignInIntegrationTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

/// Integration tests for the SignIn domain.
///
/// These tests make real API calls to a Clerk instance and verify that the SDK correctly
/// integrates with the Clerk API. Unlike unit tests which use mocked responses, these
/// tests verify end-to-end functionality including proper JSON decoding.
///
/// Requirements:
/// - Network access
/// - Valid Clerk test instance (configured via `integrationTestPublishableKey`)
/// - Test instance should be stable and not modified by other processes
@MainActor
@Suite(.serialized)
struct SignInIntegrationTests {
  init() {
    configureClerkForIntegrationTesting()
  }

  @Test
  func signInCreatePrepareAttempt() async throws {
    // Step 1: Create a SignIn with an identifier
    // Using a test email that should exist in the test instance
    let signIn = try await SignIn.create(strategy: .identifier("integration-test@clerk.test"))

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

    // Step 3: Attempt first factor with a dummy code
    // This will fail with an incorrect code error, but we're testing that the API
    // response is properly decoded and the error is a proper ClerkAPIError
    do {
      _ = try await preparedSignIn.attemptFirstFactor(strategy: .emailCode(code: "000000"))
      // If we get here, the code somehow worked (unlikely with dummy code)
      // but the response decoded successfully which is what we're testing
    } catch let error as ClerkAPIError {
      // Expected: The attempt failed with a Clerk API error
      // This proves the error response was properly decoded
      #expect(error.code != nil || error.message != nil, "ClerkAPIError should have code or message")
    } catch {
      // If it's a different type of error, the decoding might have failed
      Issue.record("Unexpected error type: \(type(of: error)) - \(error)")
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
