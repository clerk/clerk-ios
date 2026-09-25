//
//  DependencyContainerKeychainTests.swift
//  Clerk
//

@testable import ClerkKit
import Foundation
import Testing

struct DependencyContainerKeychainTests {
  @Test
  @MainActor
  func sharedSessionSyncFailsClosedWithoutAccessGroup() {
    #expect(throws: ClerkClientError.self) {
      try DependencyContainer(
        publishableKey: testPublishableKey,
        options: .init(sharedSessionSync: .enabled),
        runtimeScope: ClerkRuntimeScope(epoch: .initial)
      )
    }
  }

  @Test
  @MainActor
  func sharedSessionSyncFailsClosedWithoutOwnerIdentifier() {
    #expect(throws: ClerkClientError.self) {
      try DependencyContainer(
        publishableKey: testPublishableKey,
        options: .init(
          keychainConfig: .init(service: "service", accessGroup: "group.example"),
          sharedSessionSync: .enabled
        ),
        runtimeScope: ClerkRuntimeScope(epoch: .initial),
        ownerIdentifierProvider: { nil }
      )
    }
  }

  @Test
  @MainActor
  func keychainStorageWithoutAccessGroupUsesSystemKeychain() throws {
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(service: "service")
      ),
      runtimeScope: ClerkRuntimeScope(epoch: .initial)
    )

    #expect(container.keychain is SystemKeychain)
  }

  @Test
  @MainActor
  func identityIsStoredInTheConfiguredKeychainForThisInstance() throws {
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(keychainConfig: .init(service: "service")),
      runtimeScope: ClerkRuntimeScope(epoch: .initial)
    )
    let fingerprint = SharedSessionNamespace(
      frontendApiUrl: container.configurationManager.frontendApiUrl,
      publishableKey: testPublishableKey
    ).fingerprint

    #expect(container.identityStore.keychain is SystemKeychain)
    #expect(container.identityStore.instanceFingerprint == fingerprint)
    #expect(!container.identityIsInAccessGroup)
    #expect(!container.sharesIdentity)
  }

  @Test
  @MainActor
  func sharedSessionSyncSharesTheIdentity() throws {
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(service: "service", accessGroup: "group.example"),
        sharedSessionSync: .enabled
      ),
      runtimeScope: ClerkRuntimeScope(epoch: .initial),
      ownerIdentifierProvider: { "com.example.app" }
    )

    #expect(container.sharesIdentity)
  }

  @Test
  @MainActor
  func injectedKeychainCannotBeUsedWithSharedSessionSync() {
    #expect(throws: ClerkClientError.self) {
      try DependencyContainer(
        publishableKey: testPublishableKey,
        options: .init(
          keychainConfig: .init(service: "service", accessGroup: "group.example"),
          sharedSessionSync: .enabled
        ),
        runtimeScope: ClerkRuntimeScope(epoch: .initial),
        migratesPersistentStateOverride: false,
        keychainStorageOverride: InMemoryKeychain(),
        ownerIdentifierProvider: { "com.example.app" }
      )
    }
  }

  @Test
  @MainActor
  func injectedKeychainHoldsEveryStore() throws {
    let keychain = InMemoryKeychain()
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(),
      runtimeScope: ClerkRuntimeScope(epoch: .initial),
      migratesPersistentStateOverride: false,
      keychainStorageOverride: keychain
    )

    #expect((container.keychain as? InMemoryKeychain) === keychain)
    #expect((container.appLocalKeychain as? InMemoryKeychain) === keychain)
    #expect((container.identityStore.keychain as? InMemoryKeychain) === keychain)
  }
}
