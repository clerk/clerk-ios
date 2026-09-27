//
//  DependencyContainerKeychainTests.swift
//  Clerk
//

@testable import ClerkKit
import Foundation
import Testing

struct DependencyContainerKeychainTests {
  #if os(macOS)
  /// The package's iOS test runner has no Keychain entitlement. Exercise the real
  /// container and SystemKeychain here; the in-memory restart regression runs on both platforms.
  @Test(arguments: [false, true])
  @MainActor
  func identityMigrationDistinguishesPrivateAdoptionFromLegacyIdentityAdoption(legacyIdentityWasAdopted: Bool) throws {
    let service = "clerk.sync-review.\(UUID().uuidString)"
    let options = Clerk.Options(telemetryEnabled: false, keychainConfig: .init(service: service))
    let initial = try DependencyContainer(
      publishableKey: testPublishableKey, options: options,
      runtimeScope: ClerkRuntimeScope(epoch: .initial), migratesPersistentStateOverride: false,
      ownerIdentifierProvider: { service }
    )
    let fingerprint = initial.identityStore.instanceFingerprint
    let marker = SystemKeychain(service: DependencyContainer.stableIdentityService(
      configuredService: service, instanceFingerprint: fingerprint, ownerIdentifier: service
    ))
    defer {
      for key in ClerkKeychainKey.allCases {
        try? initial.keychain.deleteItem(forKey: key.rawValue)
        try? marker.deleteItem(forKey: key.rawValue)
      }
      try? initial.keychain.deleteItem(forKey: initial.identityStore.key)
      try? initial.keychain.deleteItem(forKey: "\(ClerkKeychainKey.identityMigrated.rawValue).\(fingerprint)")
    }
    try initial.keychain.set("legacy-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    if legacyIdentityWasAdopted {
      // SDK 1.5 already adopted or cleared this login. The separate token is stale.
      try marker.set("2", forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue)
    }
    try AppLocalStateAdoption(
      markerKeychain: marker, appLocal: initial.appLocalKeychain, shared: initial.keychain
    ).adoptIfNeeded()

    // Restart after private-state adoption but before creating the new identity record.
    let restarted = try DependencyContainer(
      publishableKey: testPublishableKey, options: options,
      runtimeScope: ClerkRuntimeScope(epoch: .initial), migratesPersistentStateOverride: true,
      ownerIdentifierProvider: { service }
    )

    #expect(try restarted.identityStore.load()?.identity.deviceToken == (legacyIdentityWasAdopted ? nil : "legacy-token"))
    #expect(try AppLocalStateAdoption.usesAppLocalStorage(in: marker))
    #expect(try AppLocalStateAdoption.hasLegacyIdentityAdoption(in: marker) == legacyIdentityWasAdopted)
    #expect(try initial.keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == false)
  }
  #endif

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
  func anAppThatWritesTheGroupRecordSharesItWithoutTheSyncOption() throws {
    // An extension that shares the access group without the option still writes the record, so it
    // must also re-read it, or it could write back an identity another app cleared.
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(keychainConfig: .init(service: "service", accessGroup: "group.example")),
      runtimeScope: ClerkRuntimeScope(epoch: .initial),
      ownerIdentifierProvider: { "com.example.extension" }
    )

    #expect(container.identityIsInAccessGroup)
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
