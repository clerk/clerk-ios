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
  var serverFetchDateSet = LockIsolated(false)
  var environmentSet = LockIsolated(false)
  private var client: Client?
  private var serverFetchDate: Date?
  private var environment: Clerk.Environment?

  func setClientIfNeeded(_ client: Client?, serverFetchDate: Date?) {
    guard self.client == nil else { return }
    self.client = client
    if let serverFetchDate {
      self.serverFetchDate = serverFetchDate
    }
    if client != nil {
      clientSet.setValue(true)
    }
  }

  func setServerFetchDateIfNeeded(_ date: Date) {
    guard client == nil, serverFetchDate == nil else { return }
    serverFetchDate = date
    serverFetchDateSet.setValue(true)
  }

  func setEnvironmentIfNeeded(_ environment: Clerk.Environment) {
    guard self.environment == nil else { return }
    self.environment = environment
    environmentSet.setValue(true)
  }
}

/// Tests for CacheManager caching operations.
@MainActor
@Suite(.tags(.unit))
struct CacheManagerTests {
  /// Creates a fresh test setup with keychain, coordinator, and cache manager.
  ///
  /// - Returns: A tuple containing the keychain, coordinator, and cache manager.
  private func createTestSetup() -> (keychain: InMemoryKeychain, coordinator: MockCacheCoordinator, cacheManager: CacheManager) {
    let keychain = InMemoryKeychain()

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
    let originalEnvironment = Clerk.Environment.mock
    var ignoredEnvironment = Clerk.Environment.mock
    ignoredEnvironment.displayConfig.applicationName = "Ignored Environment"

    let encoder = JSONEncoder.clerkEncoder
    let originalEnvironmentData = try encoder.encode(originalEnvironment)
    try keychain.set(originalEnvironmentData, forKey: ClerkKeychainKey.cachedEnvironment.rawValue)

    cacheManager.shutdown()
    cacheManager.saveEnvironment(ignoredEnvironment)

    try await Task.sleep(for: .milliseconds(50))

    let environmentData = try #require(try keychain.data(forKey: ClerkKeychainKey.cachedEnvironment.rawValue))
    let decodedEnvironment = try JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: environmentData)
    #expect(decodedEnvironment == originalEnvironment)
    #expect(decodedEnvironment != ignoredEnvironment)
  }

  @Test
  func shutdownAndDrainCompletesPendingPersistenceRequests() async throws {
    let (keychain, _, cacheManager) = createTestSetup()

    cacheManager.saveEnvironment(Clerk.Environment.mock)
    await cacheManager.shutdownAndDrain()

    let envData = try keychain.data(forKey: "cachedEnvironment")
    #expect(envData != nil)
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
    var data: Data?
    try await waitUntil(
      "key '\(key)' to appear in InMemoryKeychain",
      timeout: timeout
    ) {
      data = try keychain.data(forKey: key)
      return data != nil
    }

    return try #require(data)
  }

  private func waitForKeychainDeletion(
    _ keychain: InMemoryKeychain,
    key: String,
    timeout: Duration = .milliseconds(250)
  ) async throws {
    try await waitUntil(
      "key '\(key)' deletion from InMemoryKeychain",
      timeout: timeout
    ) {
      try keychain.data(forKey: key) == nil
    }
  }
}
