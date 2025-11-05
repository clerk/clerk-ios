//
//  CacheManagerTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

/// Mock coordinator for testing CacheManager behavior.
@MainActor
final class MockCacheCoordinator: CacheCoordinator {
  var clientSet = LockIsolated(false)
  var environmentSet = LockIsolated(false)
  var hasClientValue = LockIsolated(false)
  var isEnvironmentEmptyValue = LockIsolated(true)

  func setClientIfNeeded(_ client: Client?) {
    if client != nil {
      clientSet.setValue(true)
      hasClientValue.setValue(true)
    }
  }

  func setEnvironmentIfNeeded(_ environment: Clerk.Environment) {
    environmentSet.setValue(true)
    isEnvironmentEmptyValue.setValue(false)
  }

  var hasClient: Bool {
    hasClientValue.value
  }

  var isEnvironmentEmpty: Bool {
    isEnvironmentEmptyValue.value
  }
}

/// Tests for CacheManager caching operations.
@MainActor
@Suite(.serialized)
struct CacheManagerTests {

  init() {
    configureClerkForTesting()
  }

  @Test
  func testSaveClient() async throws {
    let keychain = InMemoryKeychain()

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    let coordinator = MockCacheCoordinator()
    let cacheManager = CacheManager(coordinator: coordinator)

    cacheManager.saveClient(.mock)

    // Verify client was saved to keychain
    let clientData = try keychain.data(forKey: "cachedClient")
    #expect(clientData != nil)

    let decoder = JSONDecoder.clerkDecoder
    let decodedClient = try decoder.decode(Client.self, from: clientData!)
    #expect(decodedClient.id == Client.mock.id)
  }

  @Test
  func testSaveEnvironment() async throws {
    let keychain = InMemoryKeychain()

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    let coordinator = MockCacheCoordinator()
    let cacheManager = CacheManager(coordinator: coordinator)

    cacheManager.saveEnvironment(.mock)

    // Verify environment was saved to keychain
    let envData = try keychain.data(forKey: "cachedEnvironment")
    #expect(envData != nil)

    let decoder = JSONDecoder.clerkDecoder
    let decodedEnv = try decoder.decode(Clerk.Environment.self, from: envData!)
    #expect(decodedEnv == Clerk.Environment.mock)
  }

  @Test
  func testLoadCachedClient() async throws {
    let keychain = InMemoryKeychain()

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    // Save a client to keychain
    let encoder = JSONEncoder.clerkEncoder
    let clientData = try encoder.encode(Client.mock)
    try keychain.set(clientData, forKey: "cachedClient")

    let coordinator = MockCacheCoordinator()
    let cacheManager = CacheManager(coordinator: coordinator)

    await cacheManager.loadCachedData()

    // Verify coordinator was called to set client
    #expect(coordinator.clientSet.value == true)
  }

  @Test
  func testLoadCachedEnvironment() async throws {
    let keychain = InMemoryKeychain()

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    // Save an environment to keychain
    let encoder = JSONEncoder.clerkEncoder
    let envData = try encoder.encode(Clerk.Environment.mock)
    try keychain.set(envData, forKey: "cachedEnvironment")

    let coordinator = MockCacheCoordinator()
    let cacheManager = CacheManager(coordinator: coordinator)

    await cacheManager.loadCachedData()

    // Verify coordinator was called to set environment
    #expect(coordinator.environmentSet.value == true)
  }

  @Test
  func testDoesNotLoadClientWhenAlreadyExists() async throws {
    let keychain = InMemoryKeychain()

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    // Save a client to keychain
    let encoder = JSONEncoder.clerkEncoder
    let clientData = try encoder.encode(Client.mock)
    try keychain.set(clientData, forKey: "cachedClient")

    let coordinator = MockCacheCoordinator()
    coordinator.hasClientValue.setValue(true) // Simulate existing client

    let cacheManager = CacheManager(coordinator: coordinator)

    await cacheManager.loadCachedData()

    // Verify coordinator was NOT called to set client
    #expect(coordinator.clientSet.value == false)
  }

  @Test
  func testDoesNotLoadEnvironmentWhenAlreadyExists() async throws {
    let keychain = InMemoryKeychain()

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    // Save an environment to keychain
    let encoder = JSONEncoder.clerkEncoder
    let envData = try encoder.encode(Clerk.Environment.mock)
    try keychain.set(envData, forKey: "cachedEnvironment")

    let coordinator = MockCacheCoordinator()
    coordinator.isEnvironmentEmptyValue.setValue(false) // Simulate existing environment

    let cacheManager = CacheManager(coordinator: coordinator)

    await cacheManager.loadCachedData()

    // Verify coordinator was NOT called to set environment
    #expect(coordinator.environmentSet.value == false)
  }

  @Test
  func testDeleteClient() async throws {
    let keychain = InMemoryKeychain()

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    // Save a client first
    let encoder = JSONEncoder.clerkEncoder
    let clientData = try encoder.encode(Client.mock)
    try keychain.set(clientData, forKey: "cachedClient")

    let coordinator = MockCacheCoordinator()
    let cacheManager = CacheManager(coordinator: coordinator)

    cacheManager.deleteClient()

    // Verify client was deleted from keychain
    let clientDataAfter = try keychain.data(forKey: "cachedClient")
    #expect(clientDataAfter == nil)
  }

  @Test
  func testHandlesMissingCachedData() async throws {
    let keychain = InMemoryKeychain()

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    let coordinator = MockCacheCoordinator()
    let cacheManager = CacheManager(coordinator: coordinator)

    // Should not crash when no cached data exists
    await cacheManager.loadCachedData()

    #expect(coordinator.clientSet.value == false)
    #expect(coordinator.environmentSet.value == false)
  }
}

