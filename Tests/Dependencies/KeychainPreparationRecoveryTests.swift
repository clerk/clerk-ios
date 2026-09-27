@_spi(FrameworkIntegration) @testable import ClerkKit
import Foundation
import Security
import Testing

@MainActor
@Suite(.serialized)
struct KeychainPreparationRecoveryTests {
  @Test(arguments: [false, true])
  func enablingSyncRecoversAnUnfinishedClearInTheSameSharedBackend(enablesSync: Bool) async throws {
    let fixture = try Fixture()
    let original = Clerk()
    original.dependencies = try fixture.container(clerk: original, sync: false)
    original.identityController.hydrate()
    try original.seedIdentity(deviceToken: "forgotten-group-token", client: .mock)
    try #require(original.dependencies.identityIsInAccessGroup)
    let originalStore = original.dependencies.identityStore
    fixture.storage(fixture.group).failingDataKey = originalStore.key
    #expect(throws: (any Error).self) { try original.identityController.clearIdentity() }
    try #require(try fixture.marker.hasItem(forKey: originalStore.clearIntentKey))
    fixture.storage(fixture.group).failingDataKey = nil

    let restarted = Clerk()
    restarted.dependencies = try fixture.container(clerk: restarted, sync: enablesSync)
    restarted.identityController.hydrate()
    try #require(restarted.dependencies.identityIsInAccessGroup)
    #expect(try await restarted.identityController.captureRequestIdentity().deviceToken == nil)
    #expect(try restarted.dependencies.identityStore.load()?.identity == .signedOut)
    #expect(try !fixture.marker.hasItem(forKey: originalStore.clearIntentKey))
    try restarted.seedIdentity(deviceToken: "new-login", client: .mock)
    let nextLaunch = Clerk()
    nextLaunch.dependencies = try fixture.container(clerk: nextLaunch, sync: enablesSync)
    nextLaunch.identityController.hydrate()
    #expect(nextLaunch.deviceToken == "new-login")
  }

  @Test
  func previousClearScopeMustBeReadableBeforeEnablingSyncPublishesIdentity() async throws {
    let fixture = try Fixture()
    let original = Clerk()
    original.dependencies = try fixture.container(clerk: original, sync: false)
    original.identityController.hydrate()
    try original.seedIdentity(deviceToken: "forgotten-group-token", client: .mock)
    let store = original.dependencies.identityStore
    fixture.storage(fixture.group).failingDataKey = store.key
    #expect(throws: (any Error).self) { try original.identityController.clearIdentity() }
    fixture.storage(fixture.group).failingDataKey = nil
    fixture.marker.failingDataKey = store.clearIntentKey

    let restarted = Clerk()
    restarted.dependencies = try fixture.container(clerk: restarted, sync: true)
    restarted.identityController.hydrate()
    #expect(!restarted.identityController.canPublishIdentity)
    await #expect(throws: (any Error).self) { try await restarted.identityController.captureRequestIdentity() }
    fixture.marker.failingDataKey = nil
    #expect(try await restarted.identityController.captureRequestIdentity().deviceToken == nil)
    #expect(try !fixture.marker.hasItem(forKey: store.clearIntentKey))
    #expect(restarted.identityController.canPublishIdentity)
  }

  @Test
  func unfinishedLocalClearDoesNotClearTheGroupWhenRejoining() throws {
    let fixture = try Fixture()
    let shared = Clerk()
    shared.dependencies = try fixture.container(clerk: shared, sync: true)
    shared.identityController.hydrate()
    try shared.seedIdentity(deviceToken: "shared-token", client: .mock)
    let sharedRecord = try #require(try shared.dependencies.identityStore.load())
    let local = Clerk()
    local.dependencies = try fixture.container(clerk: local, sync: false)
    local.identityController.hydrate()
    let localKeychain = fixture.factory.storage(DependencyContainer.localIdentityService(
      configuredService: fixture.service, ownerIdentifier: fixture.service
    ), nil)
    localKeychain.failingDataKey = local.dependencies.identityStore.key
    #expect(throws: (any Error).self) { try local.identityController.clearIdentity() }
    localKeychain.failingDataKey = nil

    let rejoined = Clerk()
    rejoined.dependencies = try fixture.container(clerk: rejoined, sync: true)
    rejoined.identityController.hydrate()
    #expect(rejoined.deviceToken == "shared-token")
    #expect(try shared.dependencies.identityStore.load() == sharedRecord)
  }

  @Test(arguments: [false, true], [false, true])
  func enablingSharingPreservesTheCurrentRecordAcrossAServiceChange(sameService: Bool, cleared: Bool) throws {
    let fixture = try Fixture()
    let oldService = sameService ? fixture.service : "previous.bundle.service"
    let originalApp = Clerk()
    originalApp.dependencies = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: .init(telemetryEnabled: false, keychainConfig: .init(service: oldService)),
      runtimeScope: originalApp.runtimeScope, migratesPersistentStateOverride: true,
      keychainFactory: { fixture.factory.storage($0, $1) }, ownerIdentifierProvider: { oldService }
    )
    try originalApp.seedIdentity(deviceToken: "local-token", client: .mock, serverDate: Date(timeIntervalSince1970: 100))
    if cleared { try originalApp.identityController.clearIdentity() }
    let original = try #require(try originalApp.dependencies.identityStore.load())
    #expect(try fixture.factory.storage(oldService, nil).string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == nil)

    let shared = Clerk()
    shared.dependencies = try fixture.container(clerk: shared, sync: true, owner: oldService)
    shared.identityController.hydrate()
    let migrated = try #require(try shared.dependencies.identityStore.load())
    #expect(migrated.identity == original.identity)
    #expect(migrated.epoch == original.epoch)
    #expect(migrated.clearEpoch == original.clearEpoch)
    #expect(migrated.watchClearGeneration == original.watchClearGeneration)
    #expect(migrated.watchClearEpoch == original.watchClearEpoch)
  }

  @Test
  func previousCurrentFormatLoginCannotReplaceAnEstablishedSharedClear() throws {
    let fixture = try Fixture()
    let previous = ClerkIdentityStore(keychain: fixture.factory.storage("previous.bundle.service", nil), instanceFingerprint: fixture.fingerprint)
    try previous.save(.init(state: .present, deviceToken: "old-token", client: .mock, serverDate: nil))
    let sharedStore = ClerkIdentityStore(keychain: fixture.storage(fixture.group), instanceFingerprint: fixture.fingerprint)
    let cleared = try sharedStore.clear()
    let app = Clerk()
    app.dependencies = try fixture.container(clerk: app, sync: true, owner: "previous.bundle.service")
    app.identityController.hydrate()
    #expect(try app.dependencies.identityStore.load() == cleared)
    #expect(app.deviceToken == nil)
  }

  @Test
  func previousServicePendingClearIsRecoveredBeforeImportingItsCurrentRecord() throws {
    let fixture = try Fixture()
    let owner = "previous.bundle.service"
    let keychain = fixture.factory.storage(owner, nil)
    let marker = fixture.factory.storage(DependencyContainer.stableIdentityService(
      configuredService: owner, instanceFingerprint: fixture.fingerprint, ownerIdentifier: owner
    ), nil)
    let previous = ClerkIdentityStore(
      keychain: keychain, instanceFingerprint: fixture.fingerprint, clearIntentKeychain: marker,
      clearIntentScope: SharedSessionNamespace.sha256("\(owner)\u{1F}\u{1F}false")
    )
    try previous.save(.init(state: .present, deviceToken: "forgotten-token", client: .mock, serverDate: nil))
    keychain.failingDataKey = previous.key
    #expect(throws: (any Error).self) { try previous.clear() }
    keychain.failingDataKey = nil
    let app = Clerk()
    app.dependencies = try fixture.container(clerk: app, sync: true, owner: owner)
    app.identityController.hydrate()
    #expect(try app.dependencies.identityStore.load()?.identity == .signedOut)
    #expect(try previous.load()?.identity == .signedOut)
    #expect(try marker.data(forKey: previous.clearIntentKey) == nil)
  }

  @Test
  func firstEnablingSharingPreservesTrustedPrivateStateAcrossAServiceChange() throws {
    let fixture = try Fixture()
    let previous = fixture.factory.storage("previous.bundle.service", nil)
    let magicLinks = MagicLinkStore(keychain: previous)
    try magicLinks.save(kind: .signIn, flowId: "pending-flow", codeVerifier: "app-private-verifier")
    let pending = try #require(magicLinks.load())
    try previous.set("app-attest-key", forKey: ClerkKeychainKey.attestKeyId.rawValue)
    try fixture.storage(fixture.group).set("sibling-attest-key", forKey: ClerkKeychainKey.attestKeyId.rawValue)
    let app = Clerk()
    app.dependencies = try fixture.container(clerk: app, sync: true, owner: "previous.bundle.service")
    #expect(app.dependencies.magicLinkStore.load() == pending)
    #expect(try app.dependencies.appLocalKeychain.string(forKey: ClerkKeychainKey.attestKeyId.rawValue) == "app-attest-key")
    let restarted = Clerk()
    restarted.dependencies = try fixture.container(clerk: restarted, sync: true, owner: "previous.bundle.service")
    #expect(restarted.dependencies.magicLinkStore.load() == pending)
    #expect(try restarted.dependencies.appLocalKeychain.string(forKey: ClerkKeychainKey.attestKeyId.rawValue) == "app-attest-key")
  }

  @Test(arguments: [false, true])
  func firstEnablingSharingFindsThePreviousDefaultService(sync: Bool) throws {
    let fixture = try Fixture()
    let previous = fixture.factory.storage("previous.bundle.service", nil)
    try previous.set("existing-login", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try previous.set(JSONEncoder.clerkEncoder.encode(Client.mock), forKey: ClerkKeychainKey.cachedClient.rawValue)
    try previous.set("100", forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)
    let clerk = Clerk()
    clerk.dependencies = try fixture.container(clerk: clerk, sync: sync, owner: "previous.bundle.service")
    clerk.identityController.hydrate()

    #expect(clerk.deviceToken == (sync ? "existing-login" : nil))
    #expect(clerk.client == nil)
    #expect(clerk.lastClientServerFetchDate == nil)
    for key in ClerkIdentityMigration.legacyIdentityKeys {
      #expect(try previous.hasItem(forKey: key.rawValue) == [.clerkDeviceToken, .cachedClient, .cachedClientServerDate].contains(key))
    }
    if sync { try clerk.identityController.clearIdentity() }
    let restarted = Clerk()
    restarted.dependencies = try fixture.container(clerk: restarted, sync: sync, owner: "previous.bundle.service")
    restarted.identityController.hydrate()
    #expect(restarted.deviceToken == nil)
  }

  @Test(arguments: [false, true])
  func previousDefaultServiceDoesNotOverrideCurrentLocalOrGroupIdentity(hasGroupIdentity: Bool) throws {
    let fixture = try Fixture()
    let previous = fixture.factory.storage("previous.bundle.service", nil)
    try previous.set("previous-login", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try fixture.storage(nil).set("current-local-login", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try fixture.storage(fixture.group).set("shared-legacy-login", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    if hasGroupIdentity {
      try ClerkIdentityStore(keychain: fixture.storage(fixture.group), instanceFingerprint: fixture.fingerprint).save(.signedOut)
    }
    let clerk = Clerk()
    clerk.dependencies = try fixture.container(clerk: clerk, sync: true, owner: "previous.bundle.service")
    clerk.identityController.hydrate()

    #expect(clerk.deviceToken == (hasGroupIdentity ? nil : "current-local-login"))
    #expect(try previous.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "previous-login")
  }

  @Test
  func unavailablePreviousDefaultServiceRetriesBeforeAdoptingSharedLegacyCredentials() async throws {
    let fixture = try Fixture()
    let previous = fixture.factory.storage("previous.bundle.service", nil)
    try previous.set("existing-login", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try fixture.storage(fixture.group).set("shared-legacy-login", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    previous.readError = KeychainError.unexpectedStatus(errSecInteractionNotAllowed)
    let clerk = Clerk()
    clerk.dependencies = try fixture.container(clerk: clerk, sync: true, owner: "previous.bundle.service")
    clerk.identityController.hydrate()
    await #expect(throws: (any Error).self) { try await clerk.identityController.captureRequestIdentity() }
    #expect(try fixture.storage(nil).string(forKey: fixture.migrationKey) == nil)

    previous.readError = nil
    #expect(try await clerk.identityController.captureRequestIdentity().deviceToken == "existing-login")
    #expect(try previous.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "existing-login")
  }

  @Test
  func reconfigurationDoesNotImportThePreviousDefaultServiceLogin() throws {
    let fixture = try Fixture()
    let previous = fixture.factory.storage("previous.bundle.service", nil)
    try previous.set("old-login", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    let clerk = Clerk()
    let destination = try fixture.container(clerk: clerk, sync: true, isReconfiguration: true, owner: "previous.bundle.service")
    #expect(try destination.identityStore.load() == nil)
    #expect(try previous.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "old-login")

    try Clerk.clearLocalClerkStorageStrictly(in: destination)
    try destination.finishReconfiguration()

    let restarted = Clerk()
    restarted.dependencies = try fixture.container(clerk: restarted, sync: true, owner: "previous.bundle.service")
    restarted.identityController.hydrate()
    #expect(restarted.deviceToken == nil)
    #expect(try previous.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "old-login")
  }

  @Test(arguments: [false, true])
  func missingGroupEntitlementDoesNotBlockLocalRequestsAfterClearOrRestart(sync: Bool) async throws {
    let fixture = try Fixture()
    fixture.storage(fixture.group).readError = KeychainError.unexpectedStatus(errSecMissingEntitlement)
    let clerk = Clerk()
    clerk.dependencies = try fixture.container(clerk: clerk, sync: sync)
    clerk.identityController.hydrate()
    try clerk.seedIdentity(deviceToken: "local-token", client: .mock)
    #expect(!clerk.options.watchConnectivityEnabled)
    #expect(try fixture.storage(nil).data(forKey: ClerkKeychainKey.watchSyncClearGeneration.rawValue) == nil)

    try clerk.identityController.clearIdentity()

    #expect(try await clerk.identityController.captureRequestIdentity().deviceToken == nil)
    let generation = try WatchSyncClearMarker.generation(in: clerk.dependencies.watchSyncKeychain)
    #expect(generation > 0)
    let restarted = Clerk()
    restarted.dependencies = try fixture.container(clerk: restarted, sync: sync)
    restarted.identityController.hydrate()
    #expect(try await restarted.identityController.captureRequestIdentity().deviceToken == nil)
    #expect(try WatchSyncClearMarker.generation(in: restarted.dependencies.watchSyncKeychain) == generation)
    try restarted.seedIdentity(deviceToken: "new-login", client: .mock)
    #expect(try await restarted.identityController.captureRequestIdentity().deviceToken == "new-login")
  }

  @Test(arguments: [false, true])
  func reconfigurationDoesNotPublishLocalLoginAndPreservesDestinationPeer(hasPeer: Bool) async throws {
    let fixture = try Fixture()
    let source = Clerk()
    source.dependencies = try fixture.container(clerk: source, sync: false, hasAccessGroup: false)
    source.identityController.hydrate()
    try source.seedIdentity(deviceToken: "source-login", client: .mock)
    let sharedStore = ClerkIdentityStore(keychain: fixture.storage(fixture.group), instanceFingerprint: fixture.fingerprint)
    if hasPeer {
      try sharedStore.save(.init(state: .present, deviceToken: "peer-login", client: .mock, serverDate: nil))
    }
    let peerRecord = try sharedStore.load()
    let destination = try fixture.container(clerk: source, sync: true, isReconfiguration: true)
    #expect(try sharedStore.load() == peerRecord)
    #expect(try source.dependencies.identityStore.load()?.identity.deviceToken == "source-login")

    try Clerk.clearLocalClerkStorageStrictly(in: source.dependencies)
    try Clerk.clearLocalClerkStorageStrictly(in: destination)
    try destination.finishReconfiguration()

    let reconfigured = Clerk()
    reconfigured.dependencies = destination
    reconfigured.identityController.hydrate()
    #expect(try await reconfigured.identityController.captureRequestIdentity().deviceToken == (hasPeer ? "peer-login" : nil))
    if hasPeer { #expect(try sharedStore.load() == peerRecord) }
    let restarted = Clerk()
    restarted.dependencies = try fixture.container(clerk: restarted, sync: true)
    restarted.identityController.hydrate()
    #expect(try await restarted.identityController.captureRequestIdentity().deviceToken == (hasPeer ? "peer-login" : nil))
  }

  @Test(arguments: [false, true])
  func reconfigurationBeforeFirstLaunchDoesNotImportLegacyLocalCredentials(sync: Bool) async throws {
    let fixture = try Fixture()
    let oldIdentity = ClerkIdentitySnapshot(state: .present, deviceToken: "legacy-login", client: .mock, serverDate: nil)
    try fixture.marker.set(JSONEncoder.clerkEncoder.encode(oldIdentity), forKey: "clerkSharedSessionLocalIdentityV2")
    let clerk = Clerk()
    let destination = try fixture.container(clerk: clerk, sync: sync, hasAccessGroup: sync, isReconfiguration: true)
    #expect(try destination.identityStore.load() == nil)
    #expect(try fixture.marker.hasItem(forKey: "clerkSharedSessionLocalIdentityV2"))

    try Clerk.clearLocalClerkStorageStrictly(in: destination)
    try destination.finishReconfiguration()

    #expect(try !fixture.marker.hasItem(forKey: "clerkSharedSessionLocalIdentityV2"))
    #expect(try fixture.storage(nil).string(forKey: fixture.migrationKey) == ClerkIdentityMigration.markerValue)
    let restarted = Clerk()
    restarted.dependencies = try fixture.container(clerk: restarted, sync: sync, hasAccessGroup: sync)
    restarted.identityController.hydrate()
    #expect(try await restarted.identityController.captureRequestIdentity().deviceToken == nil)
  }

  @Test
  func reconfigurationDoesNotCopySharedLoginWhenDisablingSharing() async throws {
    let fixture = try Fixture()
    let source = Clerk()
    source.dependencies = try fixture.container(clerk: source, sync: true)
    source.identityController.hydrate()
    try source.seedIdentity(deviceToken: "shared-login", client: .mock)
    let original = try source.dependencies.identityStore.load()
    let destination = try fixture.container(clerk: source, sync: false, isReconfiguration: true)
    #expect(try destination.identityStore.load() == nil)

    try Clerk.clearLocalClerkStorageStrictly(in: source.dependencies)
    try Clerk.clearLocalClerkStorageStrictly(in: destination)
    try destination.finishReconfiguration()

    #expect(try source.dependencies.identityStore.load() == original)
    let restarted = Clerk()
    restarted.dependencies = try fixture.container(clerk: restarted, sync: false)
    restarted.identityController.hydrate()
    #expect(try await restarted.identityController.captureRequestIdentity().deviceToken == nil)
  }

  @Test
  func freshSharedSetupCanEnumerateThroughTheMacOSWrapper() async throws {
    let fixture = try Fixture(wrapShared: true)
    let clerk = Clerk()
    clerk.dependencies = try fixture.container(clerk: clerk, sync: true)
    clerk.identityController.hydrate()

    #expect(try await clerk.identityController.captureRequestIdentity().deviceToken == nil)
    #expect(try fixture.storage(nil).string(forKey: fixture.migrationKey) == ClerkIdentityMigration.markerValue)
  }

  @Test
  func disablingSharingKeepsTheLoginThenStaysIndependentAcrossRestarts() throws {
    let fixture = try Fixture()
    let shared = Clerk()
    shared.dependencies = try fixture.container(clerk: shared, sync: true)
    shared.identityController.hydrate()
    try shared.seedIdentity(deviceToken: "shared-token", client: .mock)
    let original = try #require(try shared.dependencies.identityStore.load())

    let local = Clerk()
    local.dependencies = try fixture.container(clerk: local, sync: false)
    local.identityController.hydrate()
    #expect(local.deviceToken == "shared-token")
    #expect(local.client?.id == original.identity.client?.id)
    #expect(!local.dependencies.identityIsInAccessGroup)
    #expect(try shared.dependencies.identityStore.load() == original)

    try local.clearKeychainItems()
    let restarted = Clerk()
    restarted.dependencies = try fixture.container(clerk: restarted, sync: false)
    restarted.identityController.hydrate()
    #expect(restarted.deviceToken == nil)
    #expect(try shared.dependencies.identityStore.load() == original)

    // Rejoining uses the group's current identity, then a second departure copies that state.
    let rejoined = Clerk()
    rejoined.dependencies = try fixture.container(clerk: rejoined, sync: true)
    rejoined.identityController.hydrate()
    try rejoined.seedIdentity(deviceToken: "new-shared-token", client: .mock)
    let secondDeparture = Clerk()
    secondDeparture.dependencies = try fixture.container(clerk: secondDeparture, sync: false)
    secondDeparture.identityController.hydrate()
    #expect(secondDeparture.deviceToken == "new-shared-token")
  }

  @Test
  func rejoiningPreservesASharedSignOutAndDepartingDoesNotRestoreTheOldLocalLogin() throws {
    let fixture = try Fixture()
    let first = Clerk()
    first.dependencies = try fixture.container(clerk: first, sync: true)
    first.identityController.hydrate()
    try first.seedIdentity(deviceToken: "old-token", client: .mock)
    let local = Clerk()
    local.dependencies = try fixture.container(clerk: local, sync: false)
    local.identityController.hydrate()
    try first.dependencies.identityStore.clear()

    let rejoined = Clerk()
    rejoined.dependencies = try fixture.container(clerk: rejoined, sync: true)
    rejoined.identityController.hydrate()
    #expect(rejoined.deviceToken == nil)
    let departed = Clerk()
    departed.dependencies = try fixture.container(clerk: departed, sync: false)
    departed.identityController.hydrate()
    #expect(departed.deviceToken == nil)
    #expect(try departed.dependencies.identityStore.load()?.identity == .signedOut)
  }

  @Test
  func aFailedHandoffReadRetriesBeforeExposingAnEmptyLocalIdentity() async throws {
    let fixture = try Fixture()
    let first = Clerk()
    first.dependencies = try fixture.container(clerk: first, sync: true)
    first.identityController.hydrate()
    try first.seedIdentity(deviceToken: "shared-token", client: .mock)
    fixture.storage(fixture.group).failingDataKey = first.dependencies.identityStore.key

    let local = Clerk()
    local.dependencies = try fixture.container(clerk: local, sync: false)
    local.identityController.hydrate()
    await #expect(throws: (any Error).self) { try await local.identityController.captureRequestIdentity() }

    fixture.storage(fixture.group).failingDataKey = nil
    #expect(try await local.identityController.captureRequestIdentity().deviceToken == "shared-token")
  }

  @Test
  func enablingSharingSeedsAnEmptyGroupFromTheExistingLocalIdentity() throws {
    let fixture = try Fixture()
    try fixture.marker.set("2", forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue)
    let local = Clerk()
    local.dependencies = try fixture.container(clerk: local, sync: false)
    local.identityController.hydrate()
    try local.seedIdentity(deviceToken: "local-token", client: .mock)

    let shared = Clerk()
    shared.dependencies = try fixture.container(clerk: shared, sync: true)
    shared.identityController.hydrate()
    #expect(shared.deviceToken == "local-token")
    #expect(shared.client?.id == local.client?.id)
    #expect(shared.dependencies.identityIsInAccessGroup)
  }

  @Test
  func departingCompletesAPendingSharedClearBeforeCopyingCredentials() throws {
    let fixture = try Fixture()
    let first = Clerk()
    first.dependencies = try fixture.container(clerk: first, sync: true)
    first.identityController.hydrate()
    try first.seedIdentity(deviceToken: "shared-token", client: .mock)
    fixture.storage(fixture.group).failingDataKey = first.dependencies.identityStore.key
    #expect(throws: (any Error).self) { try first.identityController.clearIdentity() }
    fixture.storage(fixture.group).failingDataKey = nil

    let local = Clerk()
    local.dependencies = try fixture.container(clerk: local, sync: false)
    local.identityController.hydrate()
    #expect(local.deviceToken == nil)
    #expect(try first.dependencies.identityStore.load()?.identity == .signedOut)
    #expect(try local.dependencies.identityStore.load()?.identity == .signedOut)
  }

  @Test
  func handoffMarkerFailureDoesNotReplayOverAnAcceptedLocalClear() async throws {
    let fixture = try Fixture()
    let first = Clerk()
    first.dependencies = try fixture.container(clerk: first, sync: true)
    first.identityController.hydrate()
    try first.seedIdentity(deviceToken: "shared-token", client: .mock)
    fixture.marker.writeError = KeychainError.unexpectedStatus(errSecInteractionNotAllowed)
    let local = Clerk()
    local.dependencies = try fixture.container(clerk: local, sync: false)
    local.identityController.hydrate()
    await #expect(throws: (any Error).self) { try await local.identityController.captureRequestIdentity() }

    let localStore = ClerkIdentityStore(keychain: fixture.factory.storage(DependencyContainer.localIdentityService(
      configuredService: fixture.service, ownerIdentifier: fixture.service
    ), nil), instanceFingerprint: fixture.fingerprint)
    #expect(try localStore.load()?.identity.deviceToken == "shared-token")
    try localStore.clear()
    fixture.marker.writeError = nil
    let restarted = Clerk()
    restarted.dependencies = try fixture.container(clerk: restarted, sync: false)
    restarted.identityController.hydrate()
    #expect(restarted.deviceToken == nil)
    #expect(try first.dependencies.identityStore.load()?.identity.deviceToken == "shared-token")
  }

  @Test(arguments: [false, true])
  func clearBeforeRoutingRecoverySurvivesHydration(restart: Bool) async throws {
    let fixture = try Fixture()
    let shared = fixture.storage(fixture.group)
    let store = ClerkIdentityStore(keychain: shared, instanceFingerprint: fixture.fingerprint)
    try store.save(.init(state: .present, deviceToken: "old-token", client: .mock, serverDate: nil))
    shared.readError = KeychainError.unexpectedStatus(errSecInteractionNotAllowed)
    let clerk = Clerk()
    clerk.dependencies = try fixture.container(clerk: clerk, sync: true)
    clerk.identityController.hydrate()

    #expect(throws: (any Error).self) { try clerk.clearKeychainItems() }
    let journalKey = clerk.dependencies.identityStore.clearIntentKey
    #expect(try fixture.marker.hasItem(forKey: journalKey))
    await #expect(throws: (any Error).self) { try await clerk.identityController.captureRequestIdentity() }

    shared.readError = nil
    let recovered = restart ? Clerk() : clerk
    if restart {
      recovered.dependencies = try fixture.container(clerk: recovered, sync: true)
      recovered.identityController.hydrate()
    }

    #expect(try await recovered.identityController.captureRequestIdentity().deviceToken == nil)
    #expect(recovered.client == nil)
    #expect(try store.load()?.identity == .signedOut)
    #expect(try !fixture.marker.hasItem(forKey: journalKey))
  }

  @Test(arguments: [false, true])
  func unresolvedClearDoesNotFollowAChangedConfiguration(changesGroup: Bool) throws {
    let fixture = try Fixture()
    let shared = fixture.storage(fixture.group)
    let store = ClerkIdentityStore(keychain: shared, instanceFingerprint: fixture.fingerprint)
    try store.save(.init(state: .present, deviceToken: "old-token", client: .mock, serverDate: nil))
    shared.readError = KeychainError.unexpectedStatus(errSecInteractionNotAllowed)
    let original = Clerk()
    original.dependencies = try fixture.container(clerk: original, sync: true)
    original.identityController.hydrate()
    #expect(throws: (any Error).self) { try original.clearKeychainItems() }
    let journalKey = original.dependencies.identityStore.clearIntentKey
    shared.readError = nil

    // Keep the same app and Clerk instance, but select another group or disable sharing.
    let destinationGroup = changesGroup ? "TEAM.other" : fixture.group
    if !changesGroup {
      try fixture.marker.set("2", forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue)
    }
    let destinationStore = ClerkIdentityStore(
      keychain: fixture.storage(changesGroup ? destinationGroup : nil), instanceFingerprint: fixture.fingerprint
    )
    try destinationStore.save(.init(state: .present, deviceToken: "destination-token", client: .mock, serverDate: nil))
    let destination = Clerk()
    destination.dependencies = try fixture.container(clerk: destination, sync: changesGroup, accessGroup: destinationGroup)
    destination.identityController.hydrate()

    #expect(destination.deviceToken == "destination-token")
    #expect(try fixture.marker.hasItem(forKey: journalKey))

    let restarted = Clerk()
    restarted.dependencies = try fixture.container(clerk: restarted, sync: true)
    restarted.identityController.hydrate()
    #expect(try store.load()?.identity == .signedOut)
    #expect(try !fixture.marker.hasItem(forKey: journalKey))
    #expect(try destinationStore.load()?.identity.deviceToken == "destination-token")
  }

  @Test(arguments: [false, true], [false, true])
  func onlySharedIdentityMigrationAdoptsTheOldGroupWinner(sync: Bool, wrapShared: Bool) throws {
    let fixture = try Fixture(wrapShared: wrapShared)
    try fixture.marker.set("2", forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue)
    let localService = "\(fixture.service).clerk.identity.v2.\(fixture.fingerprint)"
    let localIdentity = ClerkIdentitySnapshot(state: .present, deviceToken: "local-token", client: .mock, serverDate: nil)
    try fixture.factory.storage(localService, nil).set(JSONEncoder.clerkEncoder.encode(localIdentity),
                                                       forKey: "clerkSharedSessionLocalIdentityV2")
    let peerIdentity = ClerkIdentitySnapshot(state: .present, deviceToken: "peer-token", client: .mock, serverDate: nil)
    var event = try #require(JSONSerialization.jsonObject(with: JSONEncoder.clerkEncoder.encode(peerIdentity)) as? [String: Any])
    event["id"] = UUID().uuidString
    event["origin_owner_identifier"] = "peer"
    event["generation"] = 2
    let slot: [String: Any] = [
      "schema_version": 2, "instance_fingerprint": fixture.fingerprint,
      "slot_owner_identifier": "peer", "event": event,
    ]
    let slotService = "\(fixture.service).\(SharedSessionNamespace.protocolIdentifier).\(fixture.fingerprint)"
    let seed = "\(SharedSessionNamespace.protocolIdentifier)\u{1F}\(fixture.fingerprint)\u{1F}peer"
    try fixture.factory.storage(slotService, fixture.group).set(
      JSONSerialization.data(withJSONObject: slot), forKey: "owner.\(SharedSessionNamespace.sha256(seed))"
    )
    let clerk = Clerk()
    clerk.dependencies = try fixture.container(clerk: clerk, sync: sync)

    clerk.identityController.hydrate()

    #expect(clerk.deviceToken == (sync ? "peer-token" : "local-token"))
    #expect(clerk.client?.sessions.isEmpty == false)
    #expect(clerk.dependencies.identityIsInAccessGroup == sync)
  }

  @Test(arguments: [false, true])
  func unavailableAdoptionMarkerDefersRoutingUntilItCanBeRead(adopted: Bool) async throws {
    let fixture = try Fixture()
    let local = fixture.storage(nil)
    let shared = fixture.storage(fixture.group)
    let marker = fixture.marker
    try local.set("private-attest", forKey: ClerkKeychainKey.attestKeyId.rawValue)
    if adopted { try marker.set("2", forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue) }
    let localStore = ClerkIdentityStore(keychain: local, instanceFingerprint: fixture.fingerprint)
    let sharedStore = ClerkIdentityStore(keychain: shared, instanceFingerprint: fixture.fingerprint)
    try localStore.save(ClerkIdentitySnapshot(state: .cleared, deviceToken: "local-token", client: nil, serverDate: nil))
    try sharedStore.save(ClerkIdentitySnapshot(state: .cleared, deviceToken: "shared-token", client: nil, serverDate: nil))
    marker.readError = KeychainError.unexpectedStatus(errSecInteractionNotAllowed)
    let clerk = Clerk()
    let dependencies = try fixture.container(clerk: clerk, sync: false)
    clerk.dependencies = dependencies
    clerk.identityController.hydrate()

    #expect(throws: (any Error).self) {
      try dependencies.appLocalKeychain.set("new-attest", forKey: ClerkKeychainKey.attestKeyId.rawValue)
    }
    await #expect(throws: (any Error).self) { try await clerk.identityController.captureRequestIdentity() }
    #expect(try shared.string(forKey: ClerkKeychainKey.attestKeyId.rawValue) == nil)
    #expect(try local.string(forKey: ClerkKeychainKey.attestKeyId.rawValue) == "private-attest")

    marker.readError = nil
    #expect(try await clerk.identityController.captureRequestIdentity().deviceToken == (adopted ? "local-token" : "shared-token"))
    #expect(dependencies.identityIsInAccessGroup == !adopted)
    try dependencies.appLocalKeychain.set("new-attest", forKey: ClerkKeychainKey.attestKeyId.rawValue)
    #expect(try (adopted ? local : shared).string(forKey: ClerkKeychainKey.attestKeyId.rawValue) == "new-attest")
    if adopted { #expect(try shared.string(forKey: ClerkKeychainKey.attestKeyId.rawValue) == nil) }
  }

  @Test
  func migrationRecoversSharedLegacyTokenAfterUnlockInTheSameProcess() async throws {
    let fixture = try Fixture()
    let shared = fixture.storage(fixture.group)
    try shared.set("legacy-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    shared.readError = KeychainError.unexpectedStatus(errSecInteractionNotAllowed)
    let clerk = Clerk()
    let dependencies = try fixture.container(clerk: clerk, sync: true)
    clerk.dependencies = dependencies
    clerk.identityController.hydrate()
    await #expect(throws: (any Error).self) { try await clerk.identityController.captureRequestIdentity() }
    #expect(!dependencies.sharesIdentity)

    shared.readError = nil
    #expect(try await clerk.identityController.captureRequestIdentity().deviceToken == "legacy-token")
    #expect(try dependencies.identityStore.load()?.identity.deviceToken == "legacy-token")
    #expect(dependencies.sharesIdentity)
    #expect(clerk.identityController.isSharingIdentity)
    #expect(try fixture.storage(nil).string(forKey: fixture.migrationKey) == ClerkIdentityMigration.markerValue)
  }

  @Test
  func preparationRechecksSharedAvailabilityAfterLayoutWasResolved() async throws {
    let fixture = try Fixture()
    let shared = fixture.storage(fixture.group)
    try shared.set("legacy-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    shared.failingDataKey = ClerkKeychainKey.clerkDeviceToken.rawValue
    let clerk = Clerk()
    let dependencies = try fixture.container(clerk: clerk, sync: true)
    clerk.dependencies = dependencies
    shared.failingDataKey = nil
    shared.readError = KeychainError.unexpectedStatus(errSecInteractionNotAllowed)
    clerk.identityController.hydrate()
    await #expect(throws: (any Error).self) { try await clerk.identityController.captureRequestIdentity() }
    #expect(try fixture.storage(nil).string(forKey: fixture.migrationKey) == nil)

    shared.readError = nil
    #expect(try await clerk.identityController.captureRequestIdentity().deviceToken == "legacy-token")
  }

  @Test(arguments: [false, true], [false, true])
  func missingEntitlementStillPermitsLocalRecoveryWithoutFinishingMigration(sync: Bool, adopted: Bool) async throws {
    let fixture = try Fixture()
    let shared = fixture.storage(fixture.group)
    try fixture.storage(nil).set("local-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    if adopted {
      try fixture.marker.set("2", forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue)
      try ClerkIdentityStore(keychain: fixture.storage(nil), instanceFingerprint: fixture.fingerprint).save(
        ClerkIdentitySnapshot(state: .cleared, deviceToken: "local-token", client: nil, serverDate: nil)
      )
    }
    shared.readError = KeychainError.unexpectedStatus(errSecMissingEntitlement)
    let clerk = Clerk()
    let dependencies = try fixture.container(clerk: clerk, sync: sync)
    clerk.dependencies = dependencies
    clerk.identityController.hydrate()

    #expect(try await clerk.identityController.captureRequestIdentity().deviceToken == "local-token")
    #expect(!dependencies.sharesIdentity)
    #expect(!dependencies.identityIsInAccessGroup)
    #expect(try fixture.storage(nil).string(forKey: fixture.migrationKey) == nil)
    try dependencies.appLocalKeychain.set("private-attest", forKey: ClerkKeychainKey.attestKeyId.rawValue)
    #expect(try fixture.storage(nil).string(forKey: ClerkKeychainKey.attestKeyId.rawValue) == "private-attest")
    #expect(try shared.backing.data(forKey: ClerkKeychainKey.attestKeyId.rawValue) == nil)
  }

  @MainActor
  private struct Fixture {
    let service = "clerk.recovery.\(UUID().uuidString)"
    let group = "TEAM.review"
    let factory = RecoveryKeychainFactory()
    let fingerprint: String

    init(wrapShared: Bool = false) throws {
      factory.wrapShared = wrapShared
      let config = ConfigurationManager()
      try config.configure(publishableKey: testPublishableKey, options: .init())
      fingerprint = SharedSessionNamespace(frontendApiUrl: config.frontendApiUrl, publishableKey: testPublishableKey).fingerprint
    }

    var marker: RecoveryKeychain {
      factory.storage(DependencyContainer.stableIdentityService(
        configuredService: service, instanceFingerprint: fingerprint, ownerIdentifier: service
      ), nil)
    }

    var migrationKey: String {
      ClerkIdentityMigration.markerKey(instanceFingerprint: fingerprint, ownerIdentifier: service)
    }

    func storage(_ group: String?) -> RecoveryKeychain {
      factory.storage(service, group)
    }

    func container(clerk: Clerk, sync: Bool, accessGroup: String? = nil,
                   hasAccessGroup: Bool = true, isReconfiguration: Bool = false, owner: String? = nil) throws -> DependencyContainer
    {
      try DependencyContainer(
        publishableKey: testPublishableKey,
        options: .init(telemetryEnabled: false, keychainConfig: .init(service: service, accessGroup: hasAccessGroup ? accessGroup ?? group : nil),
                       sharedSessionSync: sync ? .enabled : nil),
        runtimeScope: clerk.runtimeScope, isReconfiguration: isReconfiguration, migratesPersistentStateOverride: true,
        keychainFactory: { [factory] service, group in
          if factory.wrapShared, group != nil {
            return MigratingKeychainStorage(primary: factory.storage(service, group),
                                            fallback: factory.storage("\(service).legacy", group))
          }
          return factory.storage(service, group)
        }, ownerIdentifierProvider: { owner ?? service }
      )
    }
  }
}

private final class RecoveryKeychainFactory: @unchecked Sendable {
  var wrapShared = false
  private let lock = NSLock()
  private var stores: [String: RecoveryKeychain] = [:]

  func storage(_ service: String, _ group: String?) -> RecoveryKeychain {
    lock.withLock {
      let key = "\(service)|\(group ?? "")"
      if let store = stores[key] { return store }
      let store = RecoveryKeychain()
      stores[key] = store
      return store
    }
  }
}

private final class RecoveryKeychain: KeychainStorage, @unchecked Sendable {
  let backing = InMemoryKeychain()
  var readError: (any Error)?
  var writeError: (any Error)?
  var failingDataKey: String?

  func data(forKey key: String) throws -> Data? {
    if let readError { throw readError }
    if key == failingDataKey { throw KeychainError.unexpectedStatus(errSecInteractionNotAllowed) }
    return try backing.data(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    if let readError { throw readError }
    return try backing.hasItem(forKey: key)
  }

  func allItems() throws -> [String: Data] {
    if let readError { throw readError }
    return try backing.allItems()
  }

  func set(_ data: Data, forKey key: String) throws {
    if let writeError { throw writeError }
    try backing.set(data, forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    try backing.deleteItem(forKey: key)
  }

  func compareAndSwap(_ data: Data, forKey key: String, expectedRevision: UUID?, newRevision: UUID) throws -> Bool {
    try backing.compareAndSwap(data, forKey: key, expectedRevision: expectedRevision, newRevision: newRevision)
  }
}
