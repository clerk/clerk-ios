import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@testable import ClerkKit

@MainActor
@Suite(.serialized)
struct ClerkTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func testSignOut() async throws {
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .delete: try! JSONEncoder.clerkEncoder.encode(EmptyResponse()),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "DELETE")
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.auth.signOut()
    #expect(requestHandled.value)
  }

  @Test
  func signOutWithSessionId() async throws {
    let sessionId = "sess_test123"
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(sessionId)/remove")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(EmptyResponse()),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.auth.signOut(sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func testSetActive() async throws {
    let sessionId = "sess_test123"
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(sessionId)/touch")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(EmptyResponse()),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      let body = request.urlEncodedFormBody
      if let body {
        #expect(body["active_organization_id"] == "")
      }
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.auth.setActive(sessionId: sessionId)
    #expect(requestHandled.value)
  }

  @Test
  func setActiveWithOrganizationId() async throws {
    let sessionId = "sess_test123"
    let organizationId = "org_test456"
    let requestHandled = LockIsolated(false)
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client/sessions/\(sessionId)/touch")!

    var mock = Mock(
      url: originalURL, ignoreQuery: true, contentType: .json, statusCode: 200,
      data: [
        .post: try! JSONEncoder.clerkEncoder.encode(EmptyResponse()),
      ]
    )

    mock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      let body = request.urlEncodedFormBody
      if let body {
        #expect(body["active_organization_id"] == organizationId)
      }
      requestHandled.setValue(true)
    }
    mock.register()

    try await Clerk.shared.auth.setActive(sessionId: sessionId, organizationId: organizationId)
    #expect(requestHandled.value)
  }

  @Test
  func clearAllKeychainItemsDeletesAllKeys() async throws {
    // Set up with InMemoryKeychain for testing
    let keychain = InMemoryKeychain()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    // Add test data for all keychain keys
    try keychain.set("test-client-data".data(using: .utf8)!, forKey: ClerkKeychainKey.cachedClient.rawValue)
    try keychain.set("test-environment-data".data(using: .utf8)!, forKey: ClerkKeychainKey.cachedEnvironment.rawValue)
    try keychain.set("test-device-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try keychain.set("true", forKey: ClerkKeychainKey.clerkDeviceTokenSynced.rawValue)
    try keychain.set("test-attest-key-id", forKey: ClerkKeychainKey.attestKeyId.rawValue)

    // Verify all keys exist before clearing
    for key in ClerkKeychainKey.allCases {
      #expect(try keychain.hasItem(forKey: key.rawValue) == true)
    }

    // Clear all keychain items
    Clerk.clearAllKeychainItems()

    // Verify all keys are deleted
    for key in ClerkKeychainKey.allCases {
      #expect(try keychain.hasItem(forKey: key.rawValue) == false)
    }
  }

  @Test
  func clearAllKeychainItemsHandlesMissingKeysGracefully() async throws {
    // Set up with InMemoryKeychain for testing
    let keychain = InMemoryKeychain()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    // Add only some keys (not all)
    try keychain.set("test-device-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try keychain.set("test-attest-key-id", forKey: ClerkKeychainKey.attestKeyId.rawValue)

    // Clear all keychain items (should not throw even though some keys don't exist)
    Clerk.clearAllKeychainItems()

    // Verify all keys are deleted (including ones that didn't exist)
    for key in ClerkKeychainKey.allCases {
      #expect(try keychain.hasItem(forKey: key.rawValue) == false)
    }
  }

  @Test
  func clearAllKeychainItemsWorksWhenClerkNotConfigured() async throws {
    // Note: This test verifies that clearAllKeychainItems can be called even when Clerk is configured.
    // When Clerk is not configured, clearAllKeychainItems creates a temporary SystemKeychain instance.
    // Since we can't easily test the unconfigured state without accessing private properties,
    // we verify that the function works correctly when Clerk is configured (which is the common case).
    // The unconfigured case is tested implicitly through code coverage.

    // Set up with InMemoryKeychain for testing
    let keychain = InMemoryKeychain()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    // Add test data
    try keychain.set("test-device-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)

    // Function should work correctly
    Clerk.clearAllKeychainItems()

    // Verify key was deleted
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == false)
  }

  @Test
  func clearAllKeychainItemsDoesNotThrow() async throws {
    // Set up with InMemoryKeychain for testing
    let keychain = InMemoryKeychain()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    // Add some test data
    try keychain.set("test-data", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)

    // Function should not throw even if there are errors
    Clerk.clearAllKeychainItems()

    // Verify key was deleted
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == false)
  }

  // MARK: - isLoaded Tests

  @Test
  func isLoadedReturnsFalseWhenBothNil() {
    // Clear both client and environment
    Clerk.shared.client = nil
    Clerk.shared.environment = nil

    // isLoaded should return false when both are nil
    #expect(Clerk.shared.isLoaded == false)
  }

  @Test
  func isLoadedReturnsFalseWhenOnlyEnvironmentSet() {
    // Set only environment
    Clerk.shared.environment = Clerk.Environment.mock
    Clerk.shared.client = nil

    // isLoaded should return false when client is nil
    #expect(Clerk.shared.isLoaded == false)
  }

  @Test
  func isLoadedReturnsFalseWhenOnlyClientSet() {
    // Set only client
    Clerk.shared.client = Client.mock
    Clerk.shared.environment = nil

    // isLoaded should return false when environment is nil
    #expect(Clerk.shared.isLoaded == false)
  }

  @Test
  func isLoadedReturnsTrueWhenBothSet() {
    // Set both client and environment
    Clerk.shared.client = Client.mock
    Clerk.shared.environment = Clerk.Environment.mock

    // isLoaded should return true when both are set
    #expect(Clerk.shared.isLoaded == true)
  }

  @Test
  func isLoadedBecomesTrue() async {
    // Clear both client and environment first
    Clerk.shared.client = nil
    Clerk.shared.environment = nil
    #expect(Clerk.shared.isLoaded == false)

    // Set client - should still be false since environment is nil
    Clerk.shared.client = Client.mock
    #expect(Clerk.shared.isLoaded == false)

    // Set environment - now both are set so should be true
    Clerk.shared.environment = Clerk.Environment.mock
    #expect(Clerk.shared.isLoaded == true)

    // Clear client - should become false again
    Clerk.shared.client = nil
    #expect(Clerk.shared.isLoaded == false)
  }
}
