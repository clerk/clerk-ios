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
  func sharedConfigurationRecordsExactRecoveryTopology() throws {
    let owner = "com.clerk.tests.recovery.\(UUID().uuidString)"
    let options = Clerk.Options(
      keychainConfig: .init(
        service: "com.clerk.tests.service",
        accessGroup: "  TEAMID.com.clerk.tests.shared\n"
      ),
      sharedSessionSync: .enabled
    )
    let container = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: options,
      runtimeScope: ClerkRuntimeScope(epoch: .initial),
      ownerIdentifierProvider: { owner }
    )
    let namespace = SharedSessionNamespace(
      frontendApiUrl: container.configurationManager.frontendApiUrl,
      publishableKey: container.configurationManager.publishableKey
    )
    let intent = try #require(
      container.sharedSessionOwnerSlotClearRecovery?.currentIntent
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
