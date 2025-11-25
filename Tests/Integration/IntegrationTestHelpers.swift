//
//  IntegrationTestHelpers.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

@testable import ClerkKit

/// Publishable key for the integration test Clerk instance.
///
/// To get the key for local development:
/// - Get the key from your Clerk Dashboard or ask a team member for the integration test instance key
/// - Add it to `.env` file: `CLERK_INTEGRATION_TEST_PUBLISHABLE_KEY=pk_test_...`
///
/// In CI, the environment variable is automatically set from GitHub Actions secrets.
let integrationTestPublishableKey: String = {
  if let envKey = ProcessInfo.processInfo.environment["CLERK_INTEGRATION_TEST_PUBLISHABLE_KEY"],
     !envKey.isEmpty
  {
    return envKey
  }

  return ""
}()

/// Configures Clerk for integration testing with real API calls.
///
/// Unlike `configureClerkForTesting()` which uses mocked responses, this function configures
/// Clerk to make real API calls to a Clerk instance. This is used for integration tests that
/// verify the SDK works correctly with the actual Clerk API.
///
/// This function should be called at the start of each integration test suite or test.
///
/// - Note: Integration tests require network access and a valid Clerk test instance.
/// - Note: Integration tests are slower than unit tests due to real network calls.
@MainActor
func configureClerkForIntegrationTesting() {
  Clerk.configure(publishableKey: integrationTestPublishableKey)
}
