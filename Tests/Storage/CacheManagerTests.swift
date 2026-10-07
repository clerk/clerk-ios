//
//  CacheManagerTests.swift
//  Clerk
//
//  Created on 2025-01-27.
//

@testable import ClerkKit
import Foundation
import Testing

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
  func savedEnvironmentLoadsOnNextLaunch() async {
    let keychain = InMemoryKeychain()
    let writes = KeychainWriteQueue()
    CacheManager(coordinator: MockCacheCoordinator(), keychain: keychain, writes: writes).saveEnvironment(.mock)
    await writes.waitForPendingWrites()

    let coordinator = MockCacheCoordinator()
    CacheManager(coordinator: coordinator, keychain: keychain, writes: writes).loadCachedData()

    #expect(coordinator.environment == .mock)
  }

  @Test
  func cachedEnvironmentDoesNotReplaceAFreshOne() async {
    let keychain = InMemoryKeychain()
    let writes = KeychainWriteQueue()
    CacheManager(coordinator: MockCacheCoordinator(), keychain: keychain, writes: writes).saveEnvironment(.mock)
    await writes.waitForPendingWrites()
    var fresh = Clerk.Environment.mock
    fresh.displayConfig.applicationName = "Fresh"

    let coordinator = MockCacheCoordinator(environment: fresh)
    CacheManager(coordinator: coordinator, keychain: keychain, writes: writes).loadCachedData()

    #expect(coordinator.environment?.displayConfig.applicationName == "Fresh")
  }

  @Test
  func shutdownIgnoresLaterSaves() async throws {
    let keychain = InMemoryKeychain()
    let writes = KeychainWriteQueue()
    let cacheManager = CacheManager(coordinator: MockCacheCoordinator(), keychain: keychain, writes: writes)

    cacheManager.shutdown()
    cacheManager.saveEnvironment(.mock)
    await writes.waitForPendingWrites()

    #expect(try keychain.data(forKey: ClerkKeychainKey.cachedEnvironment.rawValue) == nil)
  }

  @Test
  func savingTheEnvironmentDoesNotWriteOnTheMainThread() async {
    let keychain = ThreadRecordingKeychain()
    let writes = KeychainWriteQueue()
    CacheManager(coordinator: MockCacheCoordinator(), keychain: keychain, writes: writes).saveEnvironment(.mock)
    await writes.waitForPendingWrites()

    #expect(keychain.mainThreadWrites.isEmpty)
    #expect(keychain.backgroundWrites == [ClerkKeychainKey.cachedEnvironment.rawValue])
  }

  @Test
  func missingOrCorruptCacheIsIgnored() throws {
    let keychain = InMemoryKeychain()
    let writes = KeychainWriteQueue()
    let coordinator = MockCacheCoordinator()
    CacheManager(coordinator: coordinator, keychain: keychain, writes: writes).loadCachedData()
    #expect(coordinator.environment == nil)

    try keychain.set(Data("not json".utf8), forKey: ClerkKeychainKey.cachedEnvironment.rawValue)
    CacheManager(coordinator: coordinator, keychain: keychain, writes: writes).loadCachedData()
    #expect(coordinator.environment == nil)
  }
}
