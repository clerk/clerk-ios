//
//  SignUpIntegrationTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

/// Integration tests for the SignUp domain.
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
struct SignUpIntegrationTests {
  init() {
    configureClerkForIntegrationTesting()
  }

  @Test
  func signUpCreatePrepareAttempt() async throws {
    // Step 1: Create a SignUp with an email address
    // Using a unique email to avoid conflicts with existing users
    let uniqueEmail = "integration-test-\(UUID().uuidString.prefix(8))@clerk.test"
    let signUp = try await SignUp.create(strategy: .standard(emailAddress: uniqueEmail))

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

    // Step 3: Attempt verification with a dummy code
    // This will fail with an incorrect code error, but we're testing that the API
    // response is properly decoded and the error is a proper ClerkAPIError
    do {
      _ = try await preparedSignUp.attemptVerification(strategy: .emailCode(code: "000000"))
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
