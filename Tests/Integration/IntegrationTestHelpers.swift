//
//  IntegrationTestHelpers.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

@testable import ClerkKit

/// Gets the publishable key for integration tests.
///
/// Reads from `.keys.json` file using the specified `keyName`.
/// Returns an empty string if the key is not found.
///
/// To get keys for local development:
/// - Run `make fetch-test-keys` to populate `.keys.json` from 1Password
/// - Or manually add keys to `.keys.json`: `{ "key-name": { "pk": "pk_test_..." } }`
///
/// In CI, `.keys.json` is created from `CLERK_TEST_KEYS_JSON` GitHub Actions secret.
func getIntegrationTestPublishableKey(keyName: String) -> String {
  // Try to read from .keys.json file
  let keysFilePath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent(".keys.json")

  if let keysData = try? Data(contentsOf: keysFilePath),
     let keysJSON = try? JSONSerialization.jsonObject(with: keysData) as? [String: Any],
     let keyEntry = keysJSON[keyName] as? [String: Any],
     let pk = keyEntry["pk"] as? String,
     !pk.isEmpty
  {
    return pk
  }

  return ""
}

/// Configures Clerk for integration testing with real API calls.
///
/// Unlike `configureClerkForTesting()` which uses mocked responses, this function configures
/// Clerk to make real API calls to a Clerk instance. This is used for integration tests that
/// verify the SDK works correctly with the actual Clerk API.
///
/// Uses an in-memory keychain to avoid affecting the simulator's real keychain state.
/// This ensures integration tests are isolated and don't log out the user or affect
/// cached data on the device.
///
/// This function must be called at the start of each integration test method.
///
/// - Parameter keyName: Key name from `.keys.json` to use (e.g., `"with-email-codes"`, `"with-email-links"`).
/// - Note: Integration tests require network access and a valid Clerk test instance.
/// - Note: Integration tests are slower than unit tests due to real network calls.
@MainActor
func configureClerkForIntegrationTesting(keyName: String) {
  let publishableKey = getIntegrationTestPublishableKey(keyName: keyName)
  Clerk.configure(publishableKey: publishableKey)

  // Replace the dependencies with a container that uses an in-memory keychain
  // but keeps the real API client and services for making actual API calls
  let apiClient = Clerk.shared.dependencies.apiClient

  Clerk.shared.dependencies = MockDependencyContainer(
    apiClient: apiClient,
    keychain: InMemoryKeychain(),
    telemetryCollector: Clerk.shared.dependencies.telemetryCollector,
    clientService: ClientService(apiClient: apiClient),
    userService: UserService(apiClient: apiClient),
    signInService: SignInService(apiClient: apiClient),
    signUpService: SignUpService(apiClient: apiClient),
    sessionService: SessionService(apiClient: apiClient),
    passkeyService: PasskeyService(apiClient: apiClient),
    organizationService: OrganizationService(apiClient: apiClient),
    environmentService: EnvironmentService(apiClient: apiClient),
    clerkService: ClerkService(apiClient: apiClient),
    emailAddressService: EmailAddressService(apiClient: apiClient),
    phoneNumberService: PhoneNumberService(apiClient: apiClient),
    externalAccountService: ExternalAccountService(apiClient: apiClient)
  )
}
