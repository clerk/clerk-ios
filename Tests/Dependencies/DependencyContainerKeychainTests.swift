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
  func disabledPersistentAdoptionDoesNotInstallLiveClearRecovery() throws {
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(),
      runtimeScope: ClerkRuntimeScope(epoch: .initial),
      persistentAdoptionEnabledOverride: false,
      ownerIdentifierProvider: { "com.clerk.tests.app" }
    )

    #expect(container.sharedSessionOwnerSlotClearRecovery == nil)
  }

  @Test
  @MainActor
  func constructionCompletesClearRecoveryBeforeReturning() throws {
    let owner = "com.clerk.tests.deferred-recovery.\(UUID().uuidString)"
    let recovery = try #require(
      SharedSessionOwnerSlotClearRecovery.liveContext(
        ownerIdentifier: owner,
        currentIntent: nil
      )
    )
    defer {
      try? recovery.journal.deleteItem(
        forKey: SharedSessionOwnerSlotClearRecovery.storageKey
      )
    }
    try recovery.journal.set(
      Data("invalid recovery journal".utf8),
      forKey: SharedSessionOwnerSlotClearRecovery.storageKey
    )

    #expect(throws: DecodingError.self) {
      try DependencyContainer(
        publishableKey: testPublishableKey,
        options: .init(),
        runtimeScope: ClerkRuntimeScope(epoch: .initial),
        persistentAdoptionEnabledOverride: true,
        ownerIdentifierProvider: { owner }
      )
    }
  }

  #if os(macOS)
  @Test
  @MainActor
  func keychainStorageWithAccessGroupUsesMigratingStorage() throws {
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(
          service: "service",
          accessGroup: "group.example"
        )
      ),
      runtimeScope: ClerkRuntimeScope(epoch: .initial)
    )

    #expect(container.keychain is MigratingKeychainStorage)
  }
  #endif

  @Test
  @MainActor
  func disabledConfigurationWithoutAdoptionMarkerKeepsLegacyPersistenceBoundary() throws {
    let configuredService = "com.clerk.tests.legacy.\(UUID().uuidString)"
    let owner = "com.clerk.tests.app.\(UUID().uuidString)"
    let options = Clerk.Options(
      keychainConfig: .init(service: configuredService)
    )
    let legacyKeychain = SystemKeychain(service: configuredService)
    let configuration = ConfigurationManager()
    try configuration.configure(publishableKey: testPublishableKey, options: options)
    let namespace = SharedSessionNamespace(
      frontendApiUrl: configuration.frontendApiUrl,
      publishableKey: configuration.publishableKey
    )
    let stableIdentityKeychain = SystemKeychain(
      service: DependencyContainer.stableIdentityService(
        configuredService: configuredService,
        instanceFingerprint: namespace.fingerprint,
        ownerIdentifier: owner
      )
    )
    defer {
      for key in [
        ClerkKeychainKey.clerkDeviceToken.rawValue,
        ClerkKeychainKey.cachedClient.rawValue,
        ClerkKeychainKey.cachedClientServerDate.rawValue,
        ClerkKeychainKey.cachedEnvironment.rawValue,
      ] {
        try? legacyKeychain.deleteItem(forKey: key)
      }
      try? stableIdentityKeychain.deleteItem(
        forKey: SharedSessionLocalIdentityStore.storageKey
      )
      try? stableIdentityKeychain.deleteItem(
        forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
      )
    }

    var legacyClient = Client.mock
    legacyClient.id = "legacy-client"
    let environmentData = try JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock)
    try legacyKeychain.set(
      "legacy-token",
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )
    try legacyKeychain.set(
      JSONEncoder.clerkEncoder.encode(legacyClient),
      forKey: ClerkKeychainKey.cachedClient.rawValue
    )
    try legacyKeychain.set(
      "100",
      forKey: ClerkKeychainKey.cachedClientServerDate.rawValue
    )
    try legacyKeychain.set(
      environmentData,
      forKey: ClerkKeychainKey.cachedEnvironment.rawValue
    )

    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: options,
      runtimeScope: ClerkRuntimeScope(epoch: .initial),
      persistentAdoptionEnabledOverride: true,
      ownerIdentifierProvider: { owner }
    )
    try container.discardPendingPublicationWhenSharedSyncDisabled()

    #expect(container.atomicIdentityStore == nil)
    #expect(!container.shouldHydrateProvisionalLegacyClient)
    #expect(
      try container.identityKeychain.string(
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      ) == "legacy-token"
    )
    let cachedClientData = try #require(
      try container.identityKeychain.data(
        forKey: ClerkKeychainKey.cachedClient.rawValue
      )
    )
    #expect(
      try JSONDecoder.clerkDecoder.decode(Client.self, from: cachedClientData).id
        == "legacy-client"
    )
    #expect(
      try container.identityKeychain.string(
        forKey: ClerkKeychainKey.cachedClientServerDate.rawValue
      ) == "100"
    )
    #expect(
      try container.appLocalKeychain.data(
        forKey: ClerkKeychainKey.cachedEnvironment.rawValue
      ) == environmentData
    )
    #expect(
      try stableIdentityKeychain.data(
        forKey: SharedSessionLocalIdentityStore.storageKey
      ) == nil
    )
    #expect(
      try stableIdentityKeychain.string(
        forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
      ) == nil
    )
  }

  @Test
  @MainActor
  func sharedConfigurationBuildsExactRecoveryTopology() throws {
    let owner = "com.clerk.tests.recovery.\(UUID().uuidString)"
    let options = Clerk.Options(
      keychainConfig: .init(
        service: "com.clerk.tests.service",
        accessGroup: "  TEAMID.com.clerk.tests.shared\n"
      ),
      sharedSessionSync: .enabled
    )
    let configuration = ConfigurationManager()
    try configuration.configure(publishableKey: testPublishableKey, options: options)
    let namespace = SharedSessionNamespace(
      frontendApiUrl: configuration.frontendApiUrl,
      publishableKey: configuration.publishableKey
    )
    let intent = try #require(
      DependencyContainer.makeOwnerSlotClearRecovery(
        configuration: configuration,
        ownerIdentifier: owner
      )?.currentIntent
    )

    #expect(intent.localIdentityService == DependencyContainer.stableIdentityService(
      configuredService: options.keychainConfig.service,
      instanceFingerprint: namespace.fingerprint,
      ownerIdentifier: owner
    ))
    #expect(intent.slotService == SharedSessionOwnerSlotStore.service(
      configuredService: options.keychainConfig.service,
      instanceFingerprint: namespace.fingerprint
    ))
    #expect(intent.slotAccessGroup == "TEAMID.com.clerk.tests.shared")
    #expect(intent.slotAccount == SharedSessionOwnerSlotStore.account(
      instanceFingerprint: namespace.fingerprint,
      ownerIdentifier: owner
    ))
    #expect(intent.instanceFingerprint == namespace.fingerprint)
    #expect(intent.ownerIdentifier == owner)
  }

  @Test
  @MainActor
  func constructingDisabledTransportDoesNotClearPendingPublication() throws {
    let configuredService = "com.clerk.tests.pending.\(UUID().uuidString)"
    let owner = "com.clerk.tests.app"
    let options = Clerk.Options(
      keychainConfig: .init(
        service: configuredService,
        accessGroup: "TEAMID.com.clerk.tests.shared"
      )
    )
    let configuration = ConfigurationManager()
    try configuration.configure(publishableKey: testPublishableKey, options: options)
    let namespace = SharedSessionNamespace(
      frontendApiUrl: configuration.frontendApiUrl,
      publishableKey: configuration.publishableKey
    )
    let identityKeychain = SystemKeychain(
      service: DependencyContainer.stableIdentityService(
        configuredService: configuredService,
        instanceFingerprint: namespace.fingerprint,
        ownerIdentifier: owner
      )
    )
    let store = SharedSessionLocalIdentityStore(keychain: identityKeychain)
    defer {
      try? store.delete()
      try? identityKeychain.deleteItem(
        forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
      )
    }
    try identityKeychain.set(
      SharedSessionSyncAdoption.markerValue,
      forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
    )
    let accepted = ClerkIdentitySnapshot(
      state: .cleared,
      deviceToken: "accepted-token",
      client: nil,
      serverDate: nil
    )
    try store.save(accepted)
    try store.stagePendingPublication(
      SharedSessionIdentityEvent(
        id: UUID(),
        originOwnerIdentifier: owner,
        generation: 1,
        state: .cleared,
        deviceToken: "pending-token",
        client: nil,
        serverDate: nil
      )
    )

    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: options,
      runtimeScope: ClerkRuntimeScope(epoch: .initial),
      persistentAdoptionEnabledOverride: true,
      ownerIdentifierProvider: { owner }
    )

    #expect(try container.atomicIdentityStore?.loadPendingPublication() != nil)
    try container.discardPendingPublicationWhenSharedSyncDisabled()
    #expect(try container.atomicIdentityStore?.loadPendingPublication() == nil)
    #expect(try container.atomicIdentityStore?.load() == accepted)
  }
}
