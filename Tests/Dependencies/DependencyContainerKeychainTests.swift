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
  func keychainStorageWithoutAccessGroupUsesSystemKeychain() throws {
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(service: "service")
      ),
      runtimeScope: ClerkRuntimeScope()
    )

    #expect(container.keychain is SystemKeychain)
  }

  @Test
  @MainActor
  func cacheWritesStayOnTheCallingThreadOnlyOnMacOS() throws {
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(keychainConfig: .init(service: "service")),
      runtimeScope: ClerkRuntimeScope()
    )

    #if os(macOS)
    #expect(container.cacheWrites.writesOnCallingThread)
    #else
    #expect(!container.cacheWrites.writesOnCallingThread)
    #endif
  }

  @Test
  @MainActor
  func identityIsStoredInTheConfiguredKeychain() throws {
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(keychainConfig: .init(service: "service")),
      runtimeScope: ClerkRuntimeScope()
    )

    #expect(container.identityStore.keychain is SystemKeychain)
    #expect(!container.identityIsInAccessGroup)
  }

  @Test
  @MainActor
  func anAccessGroupSharesTheIdentityAndKeepsPrivateStatePerApp() throws {
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(keychainConfig: .init(service: "service", accessGroup: "group.example")),
      runtimeScope: ClerkRuntimeScope(),
      ownerIdentifierProvider: { "com.example.app" }
    )

    #expect(container.identityIsInAccessGroup)
    let privateStorage = try #require(container.appLocalKeychain as? MigratingKeychainStorage)
    #if os(macOS)
    // On macOS the private state moves to the data protection keychain, from the file-based one.
    let migrating = try #require(privateStorage.primary as? MigratingKeychainStorage)
    let primary = try #require(migrating.primary as? SystemKeychain)
    #expect(primary.useDataProtectionKeychain)
    let previous = try #require(migrating.fallback as? SystemKeychain)
    #expect(previous.service == "com.example.app.clerk.app")
    #expect(previous.accessGroup == nil)
    #expect(!previous.useDataProtectionKeychain)
    #else
    let primary = try #require(privateStorage.primary as? SystemKeychain)
    #endif
    #expect(primary.service == "com.example.app.clerk.app")
    #expect(primary.accessGroup == nil)
    let fallback = try #require(privateStorage.fallback as? SystemKeychain)
    #expect(fallback.service == "service")
    #expect(fallback.accessGroup == nil)
  }

  #if os(macOS)
  @Test
  @MainActor
  func withoutAccessToTheGroupPrivateStateStaysInTheFileBasedKeychain() throws {
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(keychainConfig: .init(service: "service", accessGroup: "group.example")),
      runtimeScope: ClerkRuntimeScope(),
      probesAccessGroupOverride: true,
      ownerIdentifierProvider: { "com.example.app" }
    )

    #expect(!container.identityIsInAccessGroup)
    let privateStorage = try #require(container.appLocalKeychain as? MigratingKeychainStorage)
    let primary = try #require(privateStorage.primary as? SystemKeychain)
    #expect(!primary.useDataProtectionKeychain)
  }
  #endif

  @Test
  @MainActor
  func injectedKeychainHoldsEveryStore() throws {
    let keychain = InMemoryKeychain()
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(),
      runtimeScope: ClerkRuntimeScope(),
      probesAccessGroupOverride: false,
      keychainStorageOverride: keychain
    )

    #expect((container.keychain as? InMemoryKeychain) === keychain)
    #expect((container.appLocalKeychain as? InMemoryKeychain) === keychain)
    #expect((container.identityStore.keychain as? InMemoryKeychain) === keychain)
  }
}
