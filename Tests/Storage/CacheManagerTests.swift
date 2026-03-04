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

  func setClientIfNeeded(_ client: Client?) {
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

final class BlockingDeleteKeychain: @unchecked Sendable, KeychainStorage {
  private let lock = NSLock()
  private var items: [String: Data] = [:]
  private var shouldBlockDelete = false
  private let deleteBlocker = DispatchSemaphore(value: 0)

  func blockDelete() {
    lock.lock()
    shouldBlockDelete = true
    lock.unlock()
  }

  func unblockDelete() {
    lock.lock()
    let wasBlocking = shouldBlockDelete
    shouldBlockDelete = false
    lock.unlock()

    if wasBlocking {
      deleteBlocker.signal()
    }
  }

  func set(_ data: Data, forKey key: String) throws {
    lock.lock()
    defer { lock.unlock() }
    items[key] = data
  }

  func data(forKey key: String) throws -> Data? {
    lock.lock()
    defer { lock.unlock() }
    return items[key]
  }

  func deleteItem(forKey key: String) throws {
    lock.lock()
    let shouldBlock = shouldBlockDelete
    lock.unlock()

    if shouldBlock {
      deleteBlocker.wait()
    }

    lock.lock()
    defer { lock.unlock() }
    items.removeValue(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return items[key] != nil
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
  func testSaveEnvironment() throws {
    let (keychain, _, cacheManager) = createTestSetup()

    cacheManager.saveEnvironment(Clerk.Environment.mock)

    // Verify environment was saved to keychain
    let envData = try keychain.data(forKey: "cachedEnvironment")
    #expect(envData != nil)

    let decoder = JSONDecoder.clerkDecoder
    let decodedEnv = try decoder.decode(Clerk.Environment.self, from: #require(envData))
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
    coordinator.setClientIfNeeded(Client.mock)
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
  func handlesMissingCachedData() {
    let (_, coordinator, cacheManager) = createTestSetup()

    // Should not crash when no cached data exists
    cacheManager.loadCachedData()

    #expect(coordinator.clientSet.value == false)
    #expect(coordinator.environmentSet.value == false)
  }

  @Test
  func flushClientPersistenceWaitsForDeleteMutation() async throws {
    let keychain = BlockingDeleteKeychain()
    let coordinator = MockCacheCoordinator()
    let cacheManager = CacheManager(coordinator: coordinator, keychain: keychain)

    let clientData = try JSONEncoder.clerkEncoder.encode(Client.mock)
    try keychain.set(clientData, forKey: "cachedClient")

    keychain.blockDelete()
    cacheManager.deleteClient()

    let flushCompleted = LockIsolated(false)
    let flushTask = Task { @MainActor in
      await cacheManager.flushClientPersistence()
      flushCompleted.setValue(true)
    }

    try? await Task.sleep(for: .milliseconds(50))
    #expect(flushCompleted.value == false)

    keychain.unblockDelete()
    await flushTask.value

    #expect(flushCompleted.value == true)
    #expect(try keychain.data(forKey: "cachedClient") == nil)
  }
}
