//
//  CacheManagerTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

@testable import ClerkKit
import Foundation
import Testing

/// Mock coordinator for testing CacheManager behavior.
@MainActor
final class MockCacheCoordinator: CacheCoordinator {
  private(set) var environment: Clerk.Environment?

  init(environment: Clerk.Environment? = nil) {
    self.environment = environment
  }

  func setEnvironmentIfNeeded(_ environment: Clerk.Environment) {
    guard self.environment == nil else { return }
    self.environment = environment
  }
}

@MainActor
@Suite(.serialized)
struct CacheManagerTests {
  @Test
  func savedEnvironmentLoadsOnNextLaunch() {
    let keychain = InMemoryKeychain()
    CacheManager(coordinator: MockCacheCoordinator(), keychain: keychain).saveEnvironment(.mock)

    let coordinator = MockCacheCoordinator()
    CacheManager(coordinator: coordinator, keychain: keychain).loadCachedData()

    #expect(coordinator.environment == .mock)
  }

  @Test
  func cachedEnvironmentDoesNotReplaceAFreshOne() {
    let keychain = InMemoryKeychain()
    CacheManager(coordinator: MockCacheCoordinator(), keychain: keychain).saveEnvironment(.mock)
    var fresh = Clerk.Environment.mock
    fresh.displayConfig.applicationName = "Fresh"

    let coordinator = MockCacheCoordinator(environment: fresh)
    CacheManager(coordinator: coordinator, keychain: keychain).loadCachedData()

    #expect(coordinator.environment?.displayConfig.applicationName == "Fresh")
  }

  @Test
  func shutdownIgnoresLaterSaves() throws {
    let keychain = InMemoryKeychain()
    let cacheManager = CacheManager(coordinator: MockCacheCoordinator(), keychain: keychain)

    cacheManager.shutdown()
    cacheManager.saveEnvironment(.mock)

    #expect(try keychain.data(forKey: ClerkKeychainKey.cachedEnvironment.rawValue) == nil)
  }

  @Test
  func missingOrCorruptCacheIsIgnored() throws {
    let keychain = InMemoryKeychain()
    let coordinator = MockCacheCoordinator()
    CacheManager(coordinator: coordinator, keychain: keychain).loadCachedData()
    #expect(coordinator.environment == nil)

    try keychain.set(Data("not json".utf8), forKey: ClerkKeychainKey.cachedEnvironment.rawValue)
    CacheManager(coordinator: coordinator, keychain: keychain).loadCachedData()
    #expect(coordinator.environment == nil)
  }
}
