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
    _ = try await Clerk.shared.refreshEnvironment()
  }
}
