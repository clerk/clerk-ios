//
//  ClientIntegrationTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

/// Integration tests for the Client domain.
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
struct ClientIntegrationTests {
  init() {
    configureClerkForIntegrationTesting()
  }

  @Test
  func getClient() async throws {
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

  private func verifySessionStatus(_ status: Session.SessionStatus) {
    switch status {
    case .abandoned, .active, .pending, .ended, .expired, .removed, .replaced, .revoked:
      break // Valid cases
    case .unknown(let value):
      Issue.record("Session.SessionStatus returned unknown value: \(value)")
      #expect(Bool(false), "Session.SessionStatus should not be unknown, got: \(value)")
    }
  }

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
