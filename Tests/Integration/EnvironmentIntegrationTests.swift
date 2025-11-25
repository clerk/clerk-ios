//
//  EnvironmentIntegrationTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

/// Integration tests for the Environment domain.
///
/// These tests make real API calls to a Clerk instance and verify that the SDK correctly
/// integrates with the Clerk API. Unlike unit tests which use mocked responses, these
/// tests verify end-to-end functionality.
///
/// Requirements:
/// - Network access
/// - Valid Clerk test instance (configured via `configureClerkForIntegrationTesting(keyName:)`)
/// - Test instance should be stable and not modified by other processes
@MainActor
@Suite(.serialized)
struct EnvironmentIntegrationTests {
  @Test
  func fetchAndDecodeEnvironment() async throws {
    configureClerkForIntegrationTesting(keyName: "with-email-codes")

    // Test that we can fetch and decode the environment from a real Clerk instance
    let environment = try await Clerk.Environment.get()

    // Verify enum values are not unknown cases (ensures API contract adherence)

    // InstanceEnvironmentType should be .production or .development
    switch environment.displayConfig.instanceEnvironmentType {
    case .production, .development:
      break // Valid cases
    case .unknown(let value):
      Issue.record("instanceEnvironmentType returned unknown value: \(value)")
      #expect(Bool(false), "instanceEnvironmentType should not be unknown, got: \(value)")
    }

    // PreferredSignInStrategy should be .password or .otp
    switch environment.displayConfig.preferredSignInStrategy {
    case .password, .otp:
      break // Valid cases
    case .unknown(let value):
      Issue.record("preferredSignInStrategy returned unknown value: \(value)")
      #expect(Bool(false), "preferredSignInStrategy should not be unknown, got: \(value)")
    }

    // DeviceAttestationMode should be .disabled, .onboarding, or .enforced
    switch environment.fraudSettings.native.deviceAttestationMode {
    case .disabled, .onboarding, .enforced:
      break // Valid cases
    case .unknown(let value):
      Issue.record("deviceAttestationMode returned unknown value: \(value)")
      #expect(Bool(false), "deviceAttestationMode should not be unknown, got: \(value)")
    }
  }
}
