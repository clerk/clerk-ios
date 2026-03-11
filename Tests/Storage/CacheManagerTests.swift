//
//  CacheManagerTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

/// Mock coordinator for testing CacheManager behavior.
@MainActor
final class MockCacheCoordinator: CacheCoordinator {
  var clientSet = LockIsolated(false)
  var environmentSet = LockIsolated(false)
  private var client: Client?
  private var environment: Clerk.Environment?

  func setClientIfNeeded(_ client: Client?, serverFetchDate _: Date?) {
    guard self.client == nil else { return }
    self.client = client
    if client != nil {
      clientSet.setValue(true)
    }
  }

  func setEnvironmentIfNeeded(_ environment: Clerk.Environment) {
    guard self.environment == nil else { return }
    self.environment = environment
    environmentSet.setValue(true)
  }
}

/// Tests for CacheManager caching operations.
@MainActor
@Suite(.serialized)
struct CacheManagerTests {
  init() {
    configureClerkForTesting()
  }

  /// Creates a fresh test setup with keychain, coordinator, and cache manager.
  ///
  /// - Returns: A tuple containing the keychain, coordinator, and cache manager.
  private func createTestSetup() -> (keychain: InMemoryKeychain, coordinator: MockCacheCoordinator, cacheManager: CacheManager) {
    let keychain = InMemoryKeychain()

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    let coordinator = MockCacheCoordinator()
    let cacheManager = CacheManager(coordinator: coordinator, keychain: keychain)

    return (keychain, coordinator, cacheManager)
  }

  @Test
  func testSaveClient() async throws {
    let (keychain, _, cacheManager) = createTestSetup()

    cacheManager.saveClient(Client.mock, serverFetchDate: nil)
    let clientData = try await waitForKeychainData(
      keychain,
      key: "cachedClient"
    )

    let decoder = JSONDecoder.clerkDecoder
    let decodedClient = try decoder.decode(Client.self, from: clientData)
    #expect(decodedClient.id == Client.mock.id)
  }

  @Test
  func testSaveEnvironment() async throws {
    let (keychain, _, cacheManager) = createTestSetup()

    cacheManager.saveEnvironment(Clerk.Environment.mock)
    let envData = try await waitForKeychainData(
      keychain,
      key: "cachedEnvironment"
    )

    let decoder = JSONDecoder.clerkDecoder
    let decodedEnv = try decoder.decode(Clerk.Environment.self, from: envData)
    #expect(decodedEnv == Clerk.Environment.mock)
  }

  @Test
  func loadCachedClient() throws {
    let (keychain, coordinator, cacheManager) = createTestSetup()

    // Save a client to keychain
    let encoder = JSONEncoder.clerkEncoder
    let clientData = try encoder.encode(Client.mock)
    try keychain.set(clientData, forKey: "cachedClient")

    cacheManager.loadCachedData()

    // Verify coordinator was called to set client
    #expect(coordinator.clientSet.value == true)
  }

  @Test
  func loadCachedEnvironment() throws {
    let (keychain, coordinator, cacheManager) = createTestSetup()

    // Save an environment to keychain
    let encoder = JSONEncoder.clerkEncoder
    let envData = try encoder.encode(Clerk.Environment.mock)
    try keychain.set(envData, forKey: "cachedEnvironment")

    cacheManager.loadCachedData()

    // Verify coordinator was called to set environment
    #expect(coordinator.environmentSet.value == true)
  }

  @Test
  func doesNotLoadClientWhenAlreadyExists() throws {
    let (keychain, coordinator, cacheManager) = createTestSetup()

    // Save a client to keychain
    let encoder = JSONEncoder.clerkEncoder
    let clientData = try encoder.encode(Client.mock)
    try keychain.set(clientData, forKey: "cachedClient")

    // Simulate existing client by setting one directly
    coordinator.setClientIfNeeded(Client.mock, serverFetchDate: nil)
    coordinator.clientSet.setValue(false) // Reset to test that it's not set again

    cacheManager.loadCachedData()

    // Verify coordinator was NOT called to set client
    #expect(coordinator.clientSet.value == false)
  }

  @Test
  func doesNotLoadEnvironmentWhenAlreadyExists() throws {
    let (keychain, coordinator, cacheManager) = createTestSetup()

    // Save an environment to keychain
    let encoder = JSONEncoder.clerkEncoder
    let envData = try encoder.encode(Clerk.Environment.mock)
    try keychain.set(envData, forKey: "cachedEnvironment")

    // Simulate existing environment by setting one directly
    coordinator.setEnvironmentIfNeeded(Clerk.Environment.mock)
    coordinator.environmentSet.setValue(false) // Reset to test that it's not set again

    cacheManager.loadCachedData()

    // Verify coordinator was NOT called to set environment
    #expect(coordinator.environmentSet.value == false)
  }

  @Test
  func testDeleteClient() async throws {
    let (keychain, _, cacheManager) = createTestSetup()

    // Save a client first
    let encoder = JSONEncoder.clerkEncoder
    let clientData = try encoder.encode(Client.mock)
    try keychain.set(clientData, forKey: "cachedClient")

    cacheManager.deleteClient()
    try await waitForKeychainDeletion(keychain, key: "cachedClient")
  }

  @Test
  func shutdownIgnoresFuturePersistenceRequests() async throws {
    let (keychain, _, cacheManager) = createTestSetup()

    cacheManager.shutdown()
    cacheManager.saveEnvironment(Clerk.Environment.mock)

    try await Task.sleep(for: .milliseconds(50))

    #expect(try keychain.data(forKey: "cachedEnvironment") == nil)
  }

  @Test
  func handlesMissingCachedData() {
    let (_, coordinator, cacheManager) = createTestSetup()

    // Should not crash when no cached data exists
    cacheManager.loadCachedData()

    #expect(coordinator.clientSet.value == false)
    #expect(coordinator.environmentSet.value == false)
  }

  private func waitForKeychainData(
    _ keychain: InMemoryKeychain,
    key: String,
    timeout: Duration = .milliseconds(500)
  ) async throws -> Data {
    enum TimeoutError: Error {
      case timedOut(String)
    }

    let deadline = ContinuousClock.now + timeout

    while ContinuousClock.now < deadline {
      if let data = try keychain.data(forKey: key) {
        return data
      }

      try await Task.sleep(for: .milliseconds(10))
    }

    if let data = try keychain.data(forKey: key) {
      return data
    }

    throw TimeoutError.timedOut("Timed out waiting for key '\(key)' to appear in InMemoryKeychain")
  }

  private func waitForKeychainDeletion(
    _ keychain: InMemoryKeychain,
    key: String,
    timeout: Duration = .milliseconds(250)
  ) async throws {
    let deadline = ContinuousClock.now + timeout

    while ContinuousClock.now < deadline {
      if try keychain.data(forKey: key) == nil {
        return
      }

      try await Task.sleep(for: .milliseconds(10))
    }

    enum TimeoutError: Error {
      case timedOut(String)
    }

    if try keychain.data(forKey: key) != nil {
      throw TimeoutError.timedOut("Timed out waiting for key '\(key)' deletion from InMemoryKeychain")
    }
  }
}
