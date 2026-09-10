import ClerkKit
import Foundation

private enum IntegrationTestConfigurationError: LocalizedError {
  case missingPublishableKey(String)
  case developmentInstanceRequired

  var errorDescription: String? {
    switch self {
    case .missingPublishableKey(let keyName):
      "Missing integration test publishable key for '\(keyName)'."
    case .developmentInstanceRequired:
      "Integration tests require a pk_test_ development instance."
    }
  }
}

private var isRunningInCI: Bool {
  ProcessInfo.processInfo.environment["CI"] != nil
}

/// `make fetch-test-keys` or CI populates this file. Never log its contents.
/// An explicit path also supports test runners whose working directory differs
/// from the repository. The source checkout is the default for Xcode and SwiftPM.
func getIntegrationTestPublishableKey(keyName: String) -> String {
  let repository = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  let path = ProcessInfo.processInfo.environment["CLERK_TEST_KEYS_PATH"]
  let keysURL = path.map { URL(fileURLWithPath: $0) } ?? repository.appendingPathComponent(".keys.json")
  guard let data = try? Data(contentsOf: keysURL),
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let entry = json[keyName] as? [String: Any],
        let key = entry["pk"] as? String else { return "" }
  return key.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Local runs without keys are explicitly disabled. CI must fail on missing keys.
func integrationTestsEnabled(keyName: String) -> Bool {
  isRunningInCI || !getIntegrationTestPublishableKey(keyName: keyName).isEmpty
}

private actor IntegrationCredentialStorage: CredentialStorage {
  private var value: String?
  func read() async throws -> String? {
    value
  }

  func write(_ value: String) async throws {
    self.value = value
  }

  func remove() async throws {
    value = nil
  }
}

/// Uses real ephemeral HTTP with memory-only credentials. No Keychain,
/// installation marker, browser, passkey or biometric capability is configured.
@MainActor
func connectClerkForIntegrationTesting(keyName: String) async throws -> Clerk {
  let key = getIntegrationTestPublishableKey(keyName: keyName)
  guard !key.isEmpty else { throw IntegrationTestConfigurationError.missingPublishableKey(keyName) }
  guard key.hasPrefix("pk_test_") else { throw IntegrationTestConfigurationError.developmentInstanceRequired }
  let configuration = try ClerkConfiguration(
    publishableKey: key,
    callbackURL: URL(string: "clerk-integration-test://auth/callback")!
  )
  let capabilities = try AppleCapabilities(
    publishableKey: configuration.publishableKey,
    frontendAPI: configuration.frontendAPI,
    storage: IntegrationCredentialStorage(),
    authStorage: IntegrationCredentialStorage()
  )
  return try await Clerk.connect(configuration: configuration, capabilities: capabilities)
}
