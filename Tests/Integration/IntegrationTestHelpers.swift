//
//  IntegrationTestHelpers.swift
//  Clerk
//
//  Created on 2025-01-27.
//

@testable import ClerkKit
import Foundation

private enum IntegrationTestConfigurationError: LocalizedError {
  case missingPublishableKey(String)
  case unsupportedInstance(String)

  var errorDescription: String? {
    switch self {
    case .missingPublishableKey(let keyName):
      "Missing integration test publishable key for '\(keyName)'."
    case .unsupportedInstance(let keyName):
      "Integration test instance '\(keyName)' does not support the required Native API flows."
    }
  }
}

private var isRunningInCI: Bool {
  ProcessInfo.processInfo.environment["CI"] != nil
}

var isIntegrationTestingEnabled: Bool {
  guard let value = ProcessInfo.processInfo.environment["CLERK_RUN_INTEGRATION_TESTS"]?
    .trimmingCharacters(in: .whitespacesAndNewlines)
    .lowercased()
  else {
    return false
  }

  return ["1", "true", "yes"].contains(value)
}

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

/// Creates a local Clerk instance for integration testing with real API calls.
///
/// Unlike unit-test helpers that use mocked responses, this function creates
/// a fresh `Clerk` instance backed by the real API client for a Clerk instance.
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
func configureClerkForIntegrationTesting(keyName: String) throws -> Clerk? {
  let publishableKey = getIntegrationTestPublishableKey(keyName: keyName)
  guard !publishableKey.isEmpty else {
    if isRunningInCI {
      throw IntegrationTestConfigurationError.missingPublishableKey(keyName)
    }
    return nil
  }

  let dependencies = try DependencyContainer(
    publishableKey: publishableKey,
    options: .init()
  )

  // Keep the real API client and services, but replace the keychain with in-memory storage.
  let apiClient = dependencies.apiClient
  let emailAddressService = EmailAddressService(apiClient: apiClient)
  let phoneNumberService = PhoneNumberService(apiClient: apiClient)
  let passkeyService = PasskeyService(apiClient: apiClient)

  let container = MockDependencyContainer(
    apiClient: apiClient,
    keychain: InMemoryKeychain(),
    telemetryCollector: dependencies.telemetryCollector,
    clientService: ClientService(apiClient: apiClient),
    userService: UserService(apiClient: apiClient),
    signInService: SignInService(apiClient: apiClient),
    signUpService: SignUpService(apiClient: apiClient),
    sessionService: SessionService(apiClient: apiClient),
    passkeyService: passkeyService,
    organizationService: OrganizationService(apiClient: apiClient),
    environmentService: EnvironmentService(apiClient: apiClient),
    emailAddressService: emailAddressService,
    phoneNumberService: phoneNumberService,
    externalAccountService: ExternalAccountService(apiClient: apiClient)
  )

  try container.configurationManager.configure(publishableKey: publishableKey, options: .init())

  let clerk = Clerk(dependencies: container)
  clerk.client = nil
  clerk.environment = nil
  clerk.sessionsByUserId = [:]

  return clerk
}

func shouldSkipIntegrationTest(_ error: Error, keyName: String) throws -> Bool {
  if let clerkError = error as? ClerkAPIError,
     clerkError.code == "native_api_disabled"
  {
    if isRunningInCI {
      throw IntegrationTestConfigurationError.unsupportedInstance(keyName)
    }
    return true
  }

  return false
}
