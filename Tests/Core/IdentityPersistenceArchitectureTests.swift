@testable import ClerkKit
import Foundation
import Security
import Testing

@MainActor
@Suite(.serialized)
struct IdentityPersistenceArchitectureTests {
  struct FailureMatrixCase: CustomTestStringConvertible {
    let identityCapability: IdentityPersistenceCapability
    let sharedCapability: SharedSessionCapability
    let blockReason: Clerk.PersistenceBlockReason?
    let expectedStatus: Clerk.PersistenceStatus
    let label: String

    var testDescription: String {
      label
    }
  }

  struct ReconciliationCase: CustomTestStringConvertible {
    let localDate: Date?
    let baseGeneration: UInt64?
    let sharedGeneration: UInt64?
    let sharedDate: Date?
    let expected: SharedSessionRecoveryReconciler.Decision
    let label: String

    var testDescription: String {
      label
    }
  }

  @Test
  func transitionOwnershipRejectsStaleIDsAndEpochs() {
    let clerk = Clerk()
    let coordinator = clerk.identityPersistenceOperationCoordinator
    let ownership = coordinator.beginBootstrap(epoch: clerk.configurationEpoch)
    let staleOwnership = PersistenceTransitionOwnership(
      id: UUID(),
      configurationEpoch: clerk.configurationEpoch
    )

    #expect(throws: CancellationError.self) {
      try coordinator.advanceBootstrap(
        staleOwnership,
        to: .establishingLocalIdentity
      )
    }

    clerk.setConfigurationEpoch(to: clerk.nextConfigurationEpoch)

    #expect(throws: CancellationError.self) {
      try coordinator.advanceBootstrap(
        ownership,
        to: .establishingLocalIdentity
      )
    }
  }

  @Test
  func typedTransitionsExposeOnlyOperationSpecificPhases() throws {
    let clerk = Clerk()
    let coordinator = clerk.identityPersistenceOperationCoordinator
    let ownership = try coordinator.beginClear(epoch: clerk.configurationEpoch)

    try coordinator.advanceClear(ownership, to: .recordingIntent)

    guard case .running(.clear(let transition)) =
      coordinator.transitionState
    else {
      Issue.record("Expected a clear transition")
      return
    }
    #expect(transition.phase == .recordingIntent)
    #expect(transition.ownership == ownership)
  }

  @Test(
    arguments: [
      FailureMatrixCase(
        identityCapability: .durable,
        sharedCapability: .unavailable(.missingEntitlement),
        blockReason: nil,
        expectedStatus: .init(
          identityStorage: .durable,
          sharedSession: .unavailable(.missingEntitlement),
          readiness: .ready
        ),
        label: "shared entitlement failure keeps local durability ready"
      ),
      FailureMatrixCase(
        identityCapability: .volatile(.temporarilyUnavailable),
        sharedCapability: .disabled,
        blockReason: nil,
        expectedStatus: .init(
          identityStorage: .volatile(.temporarilyUnavailable),
          sharedSession: .disabled,
          readiness: .ready
        ),
        label: "local availability failure permits volatile-ready"
      ),
      FailureMatrixCase(
        identityCapability: .volatile(.missingEntitlement),
        sharedCapability: .disabled,
        blockReason: nil,
        expectedStatus: .init(
          identityStorage: .volatile(.missingEntitlement),
          sharedSession: .disabled,
          readiness: .ready
        ),
        label: "local entitlement failure is observable"
      ),
      FailureMatrixCase(
        identityCapability: .durable,
        sharedCapability: .active,
        blockReason: .pendingClear,
        expectedStatus: .init(
          identityStorage: .durable,
          sharedSession: .active,
          readiness: .blocked(.pendingClear)
        ),
        label: "pending clear blocks otherwise durable identity"
      ),
      FailureMatrixCase(
        identityCapability: .durable,
        sharedCapability: .disabled,
        blockReason: .incompatibleStoredData,
        expectedStatus: .init(
          identityStorage: .durable,
          sharedSession: .disabled,
          readiness: .blocked(.incompatibleStoredData)
        ),
        label: "incompatible durable state fails closed"
      ),
    ]
  )
  func capabilityAndReadinessFailureMatrix(
    _ testCase: FailureMatrixCase
  ) {
    let clerk = Clerk()
    let coordinator = clerk.identityPersistenceOperationCoordinator
    coordinator.reset(
      identityCapability: testCase.identityCapability,
      sharedSessionCapability: testCase.sharedCapability
    )

    if let blockReason = testCase.blockReason {
      let ownership = coordinator.beginBootstrap(
        epoch: clerk.configurationEpoch
      )
      coordinator.block(ownership, reason: blockReason)
    }

    #expect(clerk.persistenceStatus == testCase.expectedStatus)
  }

  @Test
  func blockedIdentityIsNotLoaded() {
    let clerk = Clerk()
    clerk.environment = .mock
    clerk.client = .mock
    let ownership = clerk.identityPersistenceOperationCoordinator
      .beginBootstrap(epoch: clerk.configurationEpoch)
    clerk.identityPersistenceOperationCoordinator.block(
      ownership,
      reason: .storageUnavailable
    )

    #expect(!clerk.isLoaded)
    #expect(
      clerk.persistenceStatus.readiness
        == .blocked(.storageUnavailable)
    )
  }

  @Test
  func sharedFailureKeepsDurableIdentityAndWatchAvailable() throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let identity = makeIdentity(serverDate: Date(timeIntervalSince1970: 100))
    try identityStore.save(identity)
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      appLocalKeychain: keychain,
      identityKeychain: keychain,
      atomicIdentityStore: identityStore
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(service: "local-only-test"),
        watchConnectivityEnabled: true,
        sharedSessionSync: .enabled
      )
    )

    try clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }

    #expect(
      clerk.persistenceStatus.identityStorage == .durable
    )
    #expect(
      clerk.persistenceStatus.sharedSession == .unavailable(.unexpected)
    )
    #expect(clerk.persistenceStatus.readiness == .ready)
    #expect(clerk.client?.id == identity.client?.id)
    #expect(clerk.isWatchConnectivityInstalled)
  }

  @Test
  func volatileIdentityDoesNotInstallWatchConnectivity() throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      atomicIdentityStore: SharedSessionLocalIdentityStore(
        keychain: keychain
      ),
      usesVolatileIdentityPersistence: true
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(watchConnectivityEnabled: true)
    )

    try clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }

    #expect(
      clerk.persistenceStatus.identityStorage
        == .volatile(.temporarilyUnavailable)
    )
    #expect(clerk.persistenceStatus.readiness == .ready)
    #expect(!clerk.isWatchConnectivityInstalled)
  }

  @Test
  func missingEntitlementWithoutAppContainerIntentInstallsStableVolatileRuntime()
    async throws
  {
    let clerk = Clerk()
    let ownerIdentifier = "com.example.app"
    let options = Clerk.Options(
      keychainConfig: .init(
        service: "com.example.clerk",
        accessGroup: "TEAMID.com.example.shared"
      ),
      sharedSessionSync: .enabled
    )
    let journal = MissingEntitlementJournal()
    let durableDependencies = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: options,
      runtimeScope: clerk.runtimeScope,
      deferSharedSessionAdoption: true,
      persistentAdoptionEnabledOverride: true,
      ownerIdentifierProvider: { ownerIdentifier },
      ownerSlotClearRecoveryProvider: { _, _ in
        SharedSessionOwnerSlotClearRecovery.Context(
          journal: journal,
          currentIntent: nil,
          targetProvider: UnusedClearRecoveryTargets()
        )
      }
    )
    #expect(journal.readCount == 0)

    let failure: PersistenceFailureKind
    do {
      try SharedSessionOwnerSlotClearRecovery.recoverIfNeeded(
        in: durableDependencies.sharedSessionOwnerSlotClearRecovery
      )
      Issue.record("Expected the pending-clear journal read to fail.")
      return
    } catch {
      failure = PersistenceFailureKind.classify(error)
    }
    #expect(journal.readCount == 1)
    #expect(failure == .missingEntitlement)

    let volatileDependencies = try DependencyContainer(
      publishableKey: testPublishableKey,
      options: options,
      runtimeScope: clerk.runtimeScope,
      deferSharedSessionAdoption: true,
      persistentAdoptionEnabledOverride: false,
      forceVolatileIdentityPersistence: failure,
      ownerIdentifierProvider: { ownerIdentifier }
    )
    clerk.installConfiguration(dependencies: volatileDependencies)
    defer { clerk.cleanupManagers() }

    #expect(
      clerk.persistenceStatus == .init(
        identityStorage: .volatile(.missingEntitlement),
        sharedSession: .unavailable(.missingEntitlement),
        readiness: .ready
      )
    )

    await clerk.onWillEnterForeground()
    await Task.yield()

    #expect(clerk.dependencies === volatileDependencies)
    #expect(clerk.persistenceStatus.identityStorage == .volatile(.missingEntitlement))
  }

  @Test
  func completedAuthenticationRemainsUsableInTheVolatileRuntime() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let store = SharedSessionLocalIdentityStore(keychain: keychain)
    let volatileDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      atomicIdentityStore: store,
      usesVolatileIdentityPersistence: true,
      clientService: MockClientService(get: { nil })
    )
    try volatileDependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init()
    )
    clerk.installConfiguration(dependencies: volatileDependencies)
    defer { clerk.cleanupManagers() }

    var authenticatedClient = Client.mock
    authenticatedClient.id = "volatile-client"

    try await clerk.identityController.applyNetworkResponse(
      ClientSyncResponseContext(
        update: .client(authenticatedClient),
        deviceTokenUpdate: .set("volatile-token"),
        requestDeviceToken: nil,
        baseGeneration: 0,
        serverDate: Date(timeIntervalSince1970: 200),
        isCanonicalClientRequest: false,
        clientResponseGeneration: clerk.clientResponseGeneration,
        responseSequence: 1
      )
    )
    await Task.yield()

    #expect(clerk.dependencies === volatileDependencies)
    #expect(clerk.client?.id == "volatile-client")
    #expect(clerk.identityController.currentDeviceToken == "volatile-token")
    #expect(try store.load()?.client?.id == "volatile-client")
    #expect(
      clerk.persistenceStatus.identityStorage
        == .volatile(.temporarilyUnavailable)
    )
  }

  @Test
  func failedVolatileClearSurvivesProcessDeathAndBlocksRelaunch()
    async throws
  {
    let temporaryRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }
    let fileURL = temporaryRoot.appendingPathComponent(
      "pending-clear.json",
      isDirectory: false
    )
    let unavailableRecovery = AppContainerIdentityClearRecovery(
      storageProvider: { _ in
        throw KeychainError.unexpectedStatus(errSecMissingEntitlement)
      }
    )

    let firstClerk = Clerk()
    firstClerk.appContainerIdentityClearIntentStore =
      FileAppContainerIdentityClearIntentStore(fileURL: fileURL)
    firstClerk.appContainerIdentityClearRecovery = unavailableRecovery
    let firstKeychain = InMemoryKeychain()
    let firstIdentityStore = SharedSessionLocalIdentityStore(
      keychain: firstKeychain
    )
    let firstDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: firstClerk.runtimeScope),
      keychain: firstKeychain,
      appLocalKeychain: firstKeychain,
      identityKeychain: firstKeychain,
      atomicIdentityStore: firstIdentityStore,
      usesVolatileIdentityPersistence: true
    )
    try firstDependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(service: "com.example.clear")
      )
    )
    try firstClerk.performConfiguration(dependencies: firstDependencies)
    defer { firstClerk.cleanupManagers() }

    let identity = makeIdentity(serverDate: Date(timeIntervalSince1970: 100))
    try firstIdentityStore.save(identity)
    firstClerk.hydrateIdentityIfNeeded(identity)
    #expect(firstClerk.client?.id == identity.client?.id)

    await #expect(throws: (any Error).self) {
      try await firstClerk.clearAllKeychainItemsAndWait()
    }

    #expect(firstClerk.client == nil)
    #expect(firstClerk.identityController.currentDeviceToken == nil)
    #expect(
      firstClerk.persistenceStatus.readiness == .blocked(.pendingClear)
    )
    let firstStoredIntent = try #require(
      try FileAppContainerIdentityClearIntentStore(fileURL: fileURL).load()
    )
    firstClerk.cleanupManagers()

    let relaunchedClerk = Clerk()
    let relaunchedStore = FileAppContainerIdentityClearIntentStore(
      fileURL: fileURL
    )
    relaunchedClerk.appContainerIdentityClearIntentStore = relaunchedStore
    relaunchedClerk.appContainerIdentityClearRecovery = unavailableRecovery
    let relaunchedKeychain = InMemoryKeychain()
    let relaunchedDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(
        runtimeScope: relaunchedClerk.runtimeScope
      ),
      keychain: relaunchedKeychain,
      appLocalKeychain: relaunchedKeychain,
      identityKeychain: relaunchedKeychain,
      atomicIdentityStore: SharedSessionLocalIdentityStore(
        keychain: relaunchedKeychain
      ),
      usesVolatileIdentityPersistence: true
    )
    try relaunchedDependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(service: "com.example.current-clear")
      )
    )

    try relaunchedClerk.performConfiguration(
      dependencies: relaunchedDependencies
    )
    defer { relaunchedClerk.cleanupManagers() }

    #expect(
      relaunchedClerk.persistenceStatus.identityStorage
        == .volatile(.temporarilyUnavailable)
    )
    #expect(
      relaunchedClerk.persistenceStatus.readiness == .blocked(.pendingClear)
    )
    #expect(relaunchedClerk.client == nil)
    #expect(relaunchedClerk.identityController.currentDeviceToken == nil)
    #expect(try relaunchedStore.load() == firstStoredIntent)

    let dependenciesBeforeRetry = relaunchedClerk.dependencies
    let currentIntent = try relaunchedClerk
      .makeAppContainerIdentityClearIntent()
    #expect(!firstStoredIntent.hasSameRecoveryTopology(as: currentIntent))
    var retriedTargets = Set<
      AppContainerIdentityClearIntent.KeychainTarget
    >()
    relaunchedClerk.appContainerIdentityClearRecovery =
      AppContainerIdentityClearRecovery(
        storageProvider: { target in
          retriedTargets.insert(target)
          return relaunchedKeychain
        }
      )

    await relaunchedClerk.onWillEnterForeground()

    #expect(try relaunchedStore.load() == nil)
    #expect(relaunchedClerk.persistenceStatus.readiness == .ready)
    #expect(relaunchedClerk.dependencies === dependenciesBeforeRetry)
    #expect(relaunchedClerk.client == nil)
    #expect(relaunchedClerk.identityController.currentDeviceToken == nil)
    #expect(retriedTargets.contains(firstStoredIntent.configuredShared))
    #expect(retriedTargets.contains(currentIntent.configuredShared))
  }

  @Test
  func pendingAppContainerClearRunsBeforeBootstrapIdentityHydration()
    throws
  {
    let temporaryRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }
    let intentStore = FileAppContainerIdentityClearIntentStore(
      fileURL: temporaryRoot.appendingPathComponent(
        "pending-clear.json",
        isDirectory: false
      )
    )
    let clerk = Clerk()
    clerk.appContainerIdentityClearIntentStore = intentStore
    let keychain = OperationRecordingKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      appLocalKeychain: keychain,
      identityKeychain: keychain,
      atomicIdentityStore: identityStore
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(service: "com.example.clear")
      )
    )
    clerk.dependencies = dependencies
    let intent = try clerk.makeAppContainerIdentityClearIntent()
    try intentStore.record(intent)
    let identity = makeIdentity(serverDate: Date(timeIntervalSince1970: 100))
    try identityStore.save(identity)
    keychain.resetOperations()
    let otherRecoveryStorage = InMemoryKeychain()
    clerk.appContainerIdentityClearRecovery =
      AppContainerIdentityClearRecovery(
        storageProvider: { target in
          if target == intent.stableIdentity {
            return keychain
          }
          return otherRecoveryStorage
        }
      )

    try clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }

    let identityOperations = keychain.operations.filter {
      $0.key == SharedSessionLocalIdentityStore.storageKey
    }
    #expect(try intentStore.load() == nil)
    #expect(try identityStore.load() == nil)
    #expect(clerk.client == nil)
    #expect(clerk.identityController.currentDeviceToken == nil)
    #expect(clerk.persistenceStatus.readiness == .ready)
    let firstDeleteIndex = try #require(
      identityOperations.firstIndex { $0.kind == .delete }
    )
    let finalReadIndex = try #require(
      identityOperations.lastIndex { $0.kind == .read }
    )
    #expect(firstDeleteIndex < finalReadIndex)
  }

  @Test
  func legacyAccessGroupClearDoesNotSynthesizeSharedAdoption()
    throws
  {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      appLocalKeychain: keychain,
      identityKeychain: keychain,
      atomicIdentityStore: SharedSessionLocalIdentityStore(
        keychain: keychain
      ),
      sharedSessionOwnerIdentifier: "com.example.app",
      usesVolatileIdentityPersistence: true
    )
    let options = Clerk.Options(
      keychainConfig: .init(
        service: "com.example.legacy",
        accessGroup: "TEAMID.com.example.shared",
        appLocalAccessGroup: "TEAMID.com.example.app"
      )
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: options
    )

    let intent = try Clerk.makeAppContainerIdentityClearIntent(
      dependencies: dependencies,
      options: options,
      frontendApiUrl: dependencies.configurationManager.frontendApiUrl,
      publishableKey: dependencies.configurationManager.publishableKey
    )
    #expect(intent.ownerSlot == nil)

    try AppContainerIdentityClearRecovery(
      storageProvider: { _ in keychain }
    ).recover(intent)

    #expect(
      try keychain.hasItem(
        forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
      ) == false
    )
  }

  @Test
  func pendingClearProtectsRecordedAndChangedCurrentTopologies()
    throws
  {
    let clerk = Clerk()
    let ownerIdentifier = "com.example.app"
    let oldOptions = Clerk.Options(
      keychainConfig: .init(
        service: "com.example.old",
        accessGroup: "OLDTEAM.com.example.shared",
        appLocalAccessGroup: "OLDTEAM.com.example.app"
      ),
      sharedSessionSync: .enabled
    )
    let currentOptions = Clerk.Options(
      keychainConfig: .init(
        service: "com.example.current",
        accessGroup: "NEWTEAM.com.example.shared",
        appLocalAccessGroup: "NEWTEAM.com.example.app"
      )
    )
    let oldShapeDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      sharedSessionOwnerIdentifier: ownerIdentifier
    )
    try oldShapeDependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: oldOptions
    )
    let oldIntent = try Clerk.makeAppContainerIdentityClearIntent(
      dependencies: oldShapeDependencies,
      options: oldOptions,
      frontendApiUrl:
      oldShapeDependencies.configurationManager.frontendApiUrl,
      publishableKey:
      oldShapeDependencies.configurationManager.publishableKey
    )

    let currentShapeDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      atomicIdentityStore: SharedSessionLocalIdentityStore(
        keychain: InMemoryKeychain()
      ),
      sharedSessionOwnerIdentifier: ownerIdentifier
    )
    try currentShapeDependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: currentOptions
    )
    let currentIntent = try Clerk.makeAppContainerIdentityClearIntent(
      dependencies: currentShapeDependencies,
      options: currentOptions,
      frontendApiUrl:
      currentShapeDependencies.configurationManager.frontendApiUrl,
      publishableKey:
      currentShapeDependencies.configurationManager.publishableKey
    )

    #expect(oldIntent.instanceFingerprint == currentIntent.instanceFingerprint)
    #expect(!oldIntent.hasSameRecoveryTopology(as: currentIntent))

    let oldTargets =
      oldIntent.uniqueKeychainTargets
        + [oldIntent.clearJournal].compactMap(\.self)
    let currentTargets =
      currentIntent.uniqueKeychainTargets
        + [currentIntent.clearJournal].compactMap(\.self)
    var storageByTarget: [
      AppContainerIdentityClearIntent.KeychainTarget: InMemoryKeychain
    ] = [:]
    for target in oldTargets + currentTargets {
      #expect(storageByTarget[target] == nil)
      storageByTarget[target] = InMemoryKeychain()
    }

    let oldStableStorage = try #require(
      storageByTarget[oldIntent.stableIdentity]
    )
    let currentStableStorage = try #require(
      storageByTarget[currentIntent.stableIdentity]
    )
    try SharedSessionLocalIdentityStore(
      keychain: oldStableStorage
    ).save(makeIdentity(serverDate: Date(timeIntervalSince1970: 100)))
    try SharedSessionLocalIdentityStore(
      keychain: currentStableStorage
    ).save(makeIdentity(serverDate: Date(timeIntervalSince1970: 200)))
    for target in
      oldIntent.uniqueKeychainTargets
      + currentIntent.uniqueKeychainTargets
    {
      let storage = try #require(storageByTarget[target])
      try storage.set(
        Data("credential".utf8),
        forKey: ClerkKeychainKey.cachedClient.rawValue
      )
    }
    if let oldClearJournal = oldIntent.clearJournal {
      try storageByTarget[oldClearJournal]?.set(
        Data("journal".utf8),
        forKey: SharedSessionOwnerSlotClearRecovery.storageKey
      )
    }
    if let currentClearJournal = currentIntent.clearJournal {
      try storageByTarget[currentClearJournal]?.set(
        Data("journal".utf8),
        forKey: SharedSessionOwnerSlotClearRecovery.storageKey
      )
    }
    let watchTargets =
      oldIntent.uniqueAppLocalKeychainTargets
        + currentIntent.uniqueAppLocalKeychainTargets
    let wallClockWatchVersion = Int(
      Date().timeIntervalSince1970 * 1000
    )
    let futureWatchVersion = wallClockWatchVersion + 86_400_000
    var maximumWatchVersion = wallClockWatchVersion
    for (index, target) in watchTargets.enumerated() {
      let version = futureWatchVersion + ((index + 1) * 10)
      let deviceTokenVersion =
        index == watchTargets.indices.last ? version : index + 1
      let authVersion =
        index == watchTargets.indices.last ? index + 1 : version
      maximumWatchVersion = max(
        maximumWatchVersion,
        max(deviceTokenVersion, authVersion)
      )
      let storage = try #require(storageByTarget[target])
      try WatchSyncMetadataStore(keychain: storage).save(
        WatchSyncMetadataRecord(
          deviceTokenState: .set,
          deviceTokenVersion: deviceTokenVersion,
          authState: .set,
          authVersion: authVersion
        )
      )
    }

    guard let currentSharedStorage =
      storageByTarget[currentIntent.configuredShared],
      let currentAppLocalStorage =
      storageByTarget[currentIntent.configuredAppLocal]
    else {
      throw IdentityPersistenceBootstrapTestError.unexpectedTargetLookup
    }
    let currentDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: currentSharedStorage,
      appLocalKeychain: currentAppLocalStorage,
      identityKeychain: currentStableStorage,
      atomicIdentityStore: SharedSessionLocalIdentityStore(
        keychain: currentStableStorage
      ),
      sharedSessionOwnerIdentifier: ownerIdentifier
    )
    try currentDependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: currentOptions
    )

    let intentStore = InMemoryAppContainerIdentityClearIntentStore(
      intent: oldIntent
    )
    let oldOwnerSlot = try #require(oldIntent.ownerSlot)
    let currentOwnerSlot = try #require(currentIntent.ownerSlot)
    let oldSlotStore = RecordingAppContainerSlotStore()
    let currentSlotStore = RecordingAppContainerSlotStore()
    clerk.appContainerIdentityClearIntentStore = intentStore
    clerk.appContainerIdentityClearRecovery =
      AppContainerIdentityClearRecovery(
        storageProvider: { target in
          guard let storage = storageByTarget[target] else {
            throw IdentityPersistenceBootstrapTestError
              .unexpectedTargetLookup
          }
          return storage
        },
        slotStoreProvider: { intent in
          if intent == oldOwnerSlot {
            return oldSlotStore
          }
          if intent == currentOwnerSlot {
            return currentSlotStore
          }
          throw IdentityPersistenceBootstrapTestError.unexpectedTargetLookup
        }
      )

    let minimumExpectedWatchClearVersion = Int(
      Date().timeIntervalSince1970 * 1000
    )
    try clerk.performConfiguration(dependencies: currentDependencies)
    defer { clerk.cleanupManagers() }

    #expect(try intentStore.load() == nil)
    #expect(try SharedSessionLocalIdentityStore(
      keychain: oldStableStorage
    ).load() == nil)
    #expect(try SharedSessionLocalIdentityStore(
      keychain: currentStableStorage
    ).load() == nil)
    #expect(oldSlotStore.deleteCount == 1)
    #expect(currentSlotStore.deleteCount == 1)
    #expect(
      try oldStableStorage.string(
        forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
      ) == SharedSessionSyncAdoption.markerValue
    )
    #expect(
      try currentStableStorage.string(
        forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
      ) == SharedSessionSyncAdoption.markerValue
    )
    for target in
      oldIntent.uniqueKeychainTargets
      + currentIntent.uniqueKeychainTargets
    {
      let storage = try #require(storageByTarget[target])
      #expect(
        try storage.data(
          forKey: ClerkKeychainKey.cachedClient.rawValue
        ) == nil
      )
    }
    for clearJournal in
      [oldIntent.clearJournal, currentIntent.clearJournal].compactMap(\.self)
    {
      let storage = try #require(storageByTarget[clearJournal])
      #expect(
        try storage.data(
          forKey: SharedSessionOwnerSlotClearRecovery.storageKey
        ) == nil
      )
    }
    for target in watchTargets {
      let storage = try #require(storageByTarget[target])
      let metadata = try WatchSyncMetadataStore(keychain: storage).load()
      #expect(metadata.deviceTokenState == .cleared)
      #expect(metadata.authState == .cleared)
      #expect(metadata.deviceTokenVersion == maximumWatchVersion + 1)
      #expect(metadata.authVersion == maximumWatchVersion + 1)
      #expect(
        metadata.authVersion ?? 0
          >= minimumExpectedWatchClearVersion
      )
    }
    #expect(clerk.client == nil)
    #expect(clerk.identityController.currentDeviceToken == nil)
    #expect(clerk.persistenceStatus.readiness == .ready)
  }

  @Test
  func appContainerRecoveryUsesWallClockWatchBarrierForMissingOrCorruptMetadata()
    throws
  {
    let clerk = Clerk()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      atomicIdentityStore: SharedSessionLocalIdentityStore(
        keychain: InMemoryKeychain()
      ),
      sharedSessionOwnerIdentifier: "com.example.app"
    )
    let options = Clerk.Options(
      keychainConfig: .init(service: "com.example.watch-clear")
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: options
    )
    let intent = try Clerk.makeAppContainerIdentityClearIntent(
      dependencies: dependencies,
      options: options,
      frontendApiUrl: dependencies.configurationManager.frontendApiUrl,
      publishableKey: dependencies.configurationManager.publishableKey
    )
    let storageByTarget = Dictionary(
      uniqueKeysWithValues: intent.uniqueKeychainTargets.map {
        ($0, InMemoryKeychain())
      }
    )
    let corruptTarget = try #require(
      intent.uniqueAppLocalKeychainTargets.first
    )
    try storageByTarget[corruptTarget]?.set(
      Data("{".utf8),
      forKey: ClerkKeychainKey.watchSyncMetadata.rawValue
    )
    let minimumClearVersion = Int(
      Date().timeIntervalSince1970 * 1000
    )

    try AppContainerIdentityClearRecovery(
      storageProvider: { target in
        guard let storage = storageByTarget[target] else {
          throw IdentityPersistenceBootstrapTestError
            .unexpectedTargetLookup
        }
        return storage
      }
    ).recover(intent)

    for target in intent.uniqueAppLocalKeychainTargets {
      let storage = try #require(storageByTarget[target])
      let metadata = try WatchSyncMetadataStore(keychain: storage).load()
      #expect(metadata.deviceTokenState == .cleared)
      #expect(metadata.authState == .cleared)
      #expect(metadata.deviceTokenVersion == metadata.authVersion)
      #expect(metadata.authVersion ?? 0 >= minimumClearVersion)
    }
  }

  @Test
  func malformedAppContainerClearFailsClosedWithoutHydratingIdentity()
    throws
  {
    let temporaryRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }
    let fileURL = temporaryRoot.appendingPathComponent(
      "pending-clear.json",
      isDirectory: false
    )
    try FileManager.default.createDirectory(
      at: temporaryRoot,
      withIntermediateDirectories: true
    )
    try Data("{".utf8).write(to: fileURL, options: .atomic)

    let clerk = Clerk()
    clerk.appContainerIdentityClearIntentStore =
      FileAppContainerIdentityClearIntentStore(fileURL: fileURL)
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let identity = makeIdentity(serverDate: Date(timeIntervalSince1970: 100))
    try identityStore.save(identity)
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      appLocalKeychain: keychain,
      identityKeychain: keychain,
      atomicIdentityStore: identityStore
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init()
    )

    try clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }

    #expect(
      clerk.persistenceStatus.readiness
        == .blocked(.incompatibleStoredData)
    )
    #expect(clerk.client == nil)
    #expect(clerk.identityController.currentDeviceToken == nil)
    #expect(try identityStore.load() == identity)
    #expect(FileManager.default.fileExists(atPath: fileURL.path))
  }

  @Test
  func semanticallyInvalidAppContainerClearFailsClosed()
    throws
  {
    let temporaryRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }
    let fileURL = temporaryRoot.appendingPathComponent(
      "pending-clear.json",
      isDirectory: false
    )
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      appLocalKeychain: keychain,
      identityKeychain: keychain,
      atomicIdentityStore: identityStore,
      sharedSessionOwnerIdentifier: "com.example.app"
    )
    let options = Clerk.Options(
      keychainConfig: .init(
        service: "com.example.clear",
        accessGroup: "TEAMID.com.example.shared",
        appLocalAccessGroup: "TEAMID.com.example.app"
      )
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: options
    )
    let validIntent = try Clerk.makeAppContainerIdentityClearIntent(
      dependencies: dependencies,
      options: options,
      frontendApiUrl: dependencies.configurationManager.frontendApiUrl,
      publishableKey: dependencies.configurationManager.publishableKey
    )
    let validOwnerSlot = try #require(validIntent.ownerSlot)
    let invalidOwnerSlot = SharedSessionOwnerSlotClearRecovery.Intent(
      localIdentityService: validOwnerSlot.localIdentityService,
      localIdentityAccessGroup: validOwnerSlot.localIdentityAccessGroup,
      slotService: "\(validOwnerSlot.slotService).tampered",
      slotAccessGroup: validOwnerSlot.slotAccessGroup,
      slotAccount: validOwnerSlot.slotAccount,
      instanceFingerprint: validOwnerSlot.instanceFingerprint,
      ownerIdentifier: validOwnerSlot.ownerIdentifier
    )
    let invalidIntent = AppContainerIdentityClearIntent(
      instanceFingerprint: validIntent.instanceFingerprint,
      ownerIdentifier: validIntent.ownerIdentifier,
      configuredShared: validIntent.configuredShared,
      configuredAppLocal: validIntent.configuredAppLocal,
      stableIdentity: validIntent.stableIdentity,
      previousAppLocal: validIntent.previousAppLocal,
      clearJournal: validIntent.clearJournal,
      ownerSlot: invalidOwnerSlot
    )
    let invalidLocalOwnerSlot =
      SharedSessionOwnerSlotClearRecovery.Intent(
        localIdentityService:
        "\(validOwnerSlot.localIdentityService).tampered",
        localIdentityAccessGroup:
        validOwnerSlot.localIdentityAccessGroup,
        slotService: validOwnerSlot.slotService,
        slotAccessGroup: validOwnerSlot.slotAccessGroup,
        slotAccount: validOwnerSlot.slotAccount,
        instanceFingerprint: validOwnerSlot.instanceFingerprint,
        ownerIdentifier: validOwnerSlot.ownerIdentifier
      )
    let invalidLocalIntent = AppContainerIdentityClearIntent(
      instanceFingerprint: validIntent.instanceFingerprint,
      ownerIdentifier: validIntent.ownerIdentifier,
      configuredShared: validIntent.configuredShared,
      configuredAppLocal: validIntent.configuredAppLocal,
      stableIdentity: .init(
        kind: validIntent.stableIdentity.kind,
        service: invalidLocalOwnerSlot.localIdentityService,
        accessGroup: validIntent.stableIdentity.accessGroup,
        legacyAccessGroups: validIntent.stableIdentity.legacyAccessGroups
      ),
      previousAppLocal: validIntent.previousAppLocal,
      clearJournal: validIntent.clearJournal,
      ownerSlot: invalidLocalOwnerSlot
    )
    #expect(throws: AppContainerIdentityClearIntentError.invalidIntent) {
      try invalidLocalIntent.validated()
    }
    try FileManager.default.createDirectory(
      at: temporaryRoot,
      withIntermediateDirectories: true
    )
    try JSONEncoder.clerkEncoder.encode(invalidIntent)
      .write(to: fileURL, options: .atomic)

    let identity = makeIdentity(serverDate: Date(timeIntervalSince1970: 100))
    try identityStore.save(identity)
    clerk.appContainerIdentityClearIntentStore =
      FileAppContainerIdentityClearIntentStore(fileURL: fileURL)

    try clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }

    #expect(
      clerk.persistenceStatus.readiness
        == .blocked(.incompatibleStoredData)
    )
    #expect(clerk.client == nil)
    #expect(try identityStore.load() == identity)
    #expect(FileManager.default.fileExists(atPath: fileURL.path))
  }

  @Test
  func failedAppContainerIntentRecordLeavesVolatileIdentityUntouched()
    async throws
  {
    let clerk = Clerk()
    clerk.appContainerIdentityClearIntentStore =
      FailingAppContainerIdentityClearIntentStore()
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      appLocalKeychain: keychain,
      identityKeychain: keychain,
      atomicIdentityStore: identityStore,
      usesVolatileIdentityPersistence: true
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init()
    )
    try clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }
    let identity = makeIdentity(serverDate: Date(timeIntervalSince1970: 100))
    try identityStore.save(identity)
    clerk.hydrateIdentityIfNeeded(identity)

    await #expect(throws: (any Error).self) {
      try await clerk.clearAllKeychainItemsAndWait()
    }

    #expect(clerk.client == identity.client)
    #expect(
      clerk.identityController.currentDeviceToken == identity.deviceToken
    )
    #expect(try identityStore.load() == identity)
    #expect(clerk.persistenceStatus.readiness == .ready)
  }

  @Test
  func finalIntentRemovalFailureKeepsClearBlockedUntilRetry()
    async throws
  {
    let clerk = Clerk()
    let intentStore = FailOnceRemovalAppContainerIdentityClearIntentStore()
    clerk.appContainerIdentityClearIntentStore = intentStore
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      appLocalKeychain: keychain,
      identityKeychain: keychain,
      atomicIdentityStore: identityStore
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(service: "com.example.clear")
      )
    )
    clerk.appContainerIdentityClearRecovery =
      AppContainerIdentityClearRecovery(
        storageProvider: { _ in keychain }
      )
    try clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }
    let identity = makeIdentity(serverDate: Date(timeIntervalSince1970: 100))
    try identityStore.save(identity)
    clerk.hydrateIdentityIfNeeded(identity)

    await #expect(throws: (any Error).self) {
      try await clerk.clearAllKeychainItemsAndWait()
    }

    #expect(try intentStore.load() != nil)
    #expect(clerk.client == nil)
    #expect(clerk.identityController.currentDeviceToken == nil)
    #expect(clerk.persistenceStatus.readiness == .blocked(.pendingClear))

    try await clerk.clearAllKeychainItemsAndWait()

    #expect(try intentStore.load() == nil)
    #expect(clerk.persistenceStatus.readiness == .ready)
    #expect(clerk.client == nil)
    #expect(clerk.identityController.currentDeviceToken == nil)
  }

  @Test
  func bootstrapIntentRemovalFailureBlocksHydrationUntilForegroundRetry()
    async throws
  {
    let clerk = Clerk()
    let intentStore = FailOnceRemovalAppContainerIdentityClearIntentStore()
    clerk.appContainerIdentityClearIntentStore = intentStore
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      appLocalKeychain: keychain,
      identityKeychain: keychain,
      atomicIdentityStore: identityStore
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(service: "com.example.bootstrap-clear")
      )
    )
    clerk.dependencies = dependencies
    let intent = try clerk.makeAppContainerIdentityClearIntent()
    try intentStore.record(intent)
    try identityStore.save(
      makeIdentity(serverDate: Date(timeIntervalSince1970: 100))
    )
    clerk.appContainerIdentityClearRecovery =
      AppContainerIdentityClearRecovery(
        storageProvider: { _ in keychain }
      )

    try clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }

    #expect(try intentStore.load() == intent)
    #expect(try identityStore.load() == nil)
    #expect(clerk.client == nil)
    #expect(clerk.identityController.currentDeviceToken == nil)
    #expect(clerk.persistenceStatus.readiness == .blocked(.pendingClear))

    await clerk.onWillEnterForeground()

    #expect(try intentStore.load() == nil)
    #expect(clerk.client == nil)
    #expect(clerk.identityController.currentDeviceToken == nil)
    #expect(clerk.persistenceStatus.readiness == .ready)
  }

  @Test
  func foregroundRetryDoesNotReleaseLegacyRuntimeAfterAdoptionBarrierWrite()
    async throws
  {
    let clerk = Clerk()
    let ownerIdentifier = "com.example.app"
    let keychainConfig = Clerk.Options.KeychainConfig(
      service: "com.example.routing-clear",
      accessGroup: "TEAMID.com.example.shared",
      appLocalAccessGroup: "TEAMID.com.example.app"
    )
    let recordedOptions = Clerk.Options(
      keychainConfig: keychainConfig,
      sharedSessionSync: .enabled
    )
    let recordedDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      atomicIdentityStore: SharedSessionLocalIdentityStore(
        keychain: InMemoryKeychain()
      ),
      sharedSessionOwnerIdentifier: ownerIdentifier
    )
    try recordedDependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: recordedOptions
    )
    let recordedIntent = try Clerk.makeAppContainerIdentityClearIntent(
      dependencies: recordedDependencies,
      options: recordedOptions,
      frontendApiUrl:
      recordedDependencies.configurationManager.frontendApiUrl,
      publishableKey:
      recordedDependencies.configurationManager.publishableKey
    )
    #expect(recordedIntent.ownerSlot != nil)

    let legacyDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      sharedSessionOwnerIdentifier: ownerIdentifier
    )
    try legacyDependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(keychainConfig: keychainConfig)
    )
    let intentStore = InMemoryAppContainerIdentityClearIntentStore(
      intent: recordedIntent
    )
    let recoveryKeychain = FailFirstAdoptionMarkerWriteKeychain()
    clerk.appContainerIdentityClearIntentStore = intentStore
    clerk.appContainerIdentityClearRecovery =
      AppContainerIdentityClearRecovery(
        storageProvider: { _ in recoveryKeychain },
        slotStoreProvider: { _ in
          RecordingAppContainerSlotStore()
        }
      )

    try clerk.performConfiguration(dependencies: legacyDependencies)
    defer { clerk.cleanupManagers() }

    #expect(clerk.persistenceStatus.readiness == .blocked(.pendingClear))
    #expect(try intentStore.load() == recordedIntent)
    #expect(
      try recoveryKeychain.hasItem(
        forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
      ) == false
    )

    await clerk.onWillEnterForeground()

    #expect(clerk.dependencies === legacyDependencies)
    #expect(clerk.persistenceStatus.readiness == .blocked(.pendingClear))
    #expect(try intentStore.load() == recordedIntent)
    #expect(
      try recoveryKeychain.string(
        forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
      ) == SharedSessionSyncAdoption.markerValue
    )
  }

  @Test
  func blockedProductionBootstrapUsesVolatileRoutingUntilAdoptionRetry()
    async throws
  {
    let clerk = Clerk()
    let ownerIdentifier = "com.example.production-app"
    let keychainConfig = Clerk.Options.KeychainConfig(
      service: "com.example.production-routing.\(UUID().uuidString)",
      accessGroup: "TEAMID.com.example.shared",
      appLocalAccessGroup: "TEAMID.\(ownerIdentifier)"
    )
    let recordedOptions = Clerk.Options(
      keychainConfig: keychainConfig,
      sharedSessionSync: .enabled
    )
    let recordedDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      atomicIdentityStore: SharedSessionLocalIdentityStore(
        keychain: InMemoryKeychain()
      ),
      sharedSessionOwnerIdentifier: ownerIdentifier
    )
    try recordedDependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: recordedOptions
    )
    let recordedIntent = try Clerk.makeAppContainerIdentityClearIntent(
      dependencies: recordedDependencies,
      options: recordedOptions,
      frontendApiUrl:
      recordedDependencies.configurationManager.frontendApiUrl,
      publishableKey:
      recordedDependencies.configurationManager.publishableKey
    )
    let intentStore = InMemoryAppContainerIdentityClearIntentStore(
      intent: recordedIntent
    )
    let recoveryKeychain = FailFirstAdoptionMarkerWriteKeychain()
    clerk.appContainerIdentityClearIntentStore = intentStore
    clerk.appContainerIdentityClearRecovery =
      AppContainerIdentityClearRecovery(
        storageProvider: { _ in recoveryKeychain },
        slotStoreProvider: { _ in
          RecordingAppContainerSlotStore()
        }
      )
    let runtimeScope = clerk.runtimeScope
    let productionKeychain = InMemoryKeychain()
    var forcedPersistenceFailures: [PersistenceFailureKind?] = []
    let dependencyFactory: Clerk.ConfigurationDependencyFactory = {
      publishableKey,
      options,
      forceVolatileIdentityPersistence in
      forcedPersistenceFailures.append(
        forceVolatileIdentityPersistence
      )
      return try DependencyContainer(
        publishableKey: publishableKey,
        options: options,
        runtimeScope: runtimeScope,
        deferSharedSessionAdoption: true,
        persistentAdoptionEnabledOverride: false,
        keychainStorageOverride: productionKeychain,
        persistenceFailureBehavior: .useVolatileStorage,
        forceVolatileIdentityPersistence:
        forceVolatileIdentityPersistence,
        ownerIdentifierProvider: { ownerIdentifier }
      )
    }

    try clerk.performConfiguration(
      publishableKey: testPublishableKey,
      options: .init(keychainConfig: keychainConfig),
      dependencyFactory: dependencyFactory
    )
    defer { clerk.cleanupManagers() }

    #expect(
      clerk.persistenceStatus.identityStorage
        == .volatile(.temporarilyUnavailable)
    )
    #expect(clerk.persistenceStatus.readiness == .blocked(.pendingClear))
    #expect(try intentStore.load() == recordedIntent)
    #expect(forcedPersistenceFailures.count == 3)
    #expect(
      forcedPersistenceFailures.last == .temporarilyUnavailable
    )

    await clerk.onWillEnterForeground()

    #expect(
      clerk.persistenceStatus.identityStorage
        == .volatile(.temporarilyUnavailable)
    )
    #expect(clerk.persistenceStatus.readiness == .ready)
    #expect(try intentStore.load() == nil)
  }

  @Test
  func unrelatedPendingClearDoesNotChangeCurrentProductionRouting()
    async throws
  {
    let clerk = Clerk()
    let ownerIdentifier = "com.example.old-app"
    let recordedOptions = Clerk.Options(
      keychainConfig: .init(
        service: "com.example.old-routing-clear",
        accessGroup: "TEAMID.com.example.old-shared",
        appLocalAccessGroup: "TEAMID.com.example.old-app"
      ),
      sharedSessionSync: .enabled
    )
    let recordedDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      atomicIdentityStore: SharedSessionLocalIdentityStore(
        keychain: InMemoryKeychain()
      ),
      sharedSessionOwnerIdentifier: ownerIdentifier
    )
    try recordedDependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: recordedOptions
    )
    let recordedIntent = try Clerk.makeAppContainerIdentityClearIntent(
      dependencies: recordedDependencies,
      options: recordedOptions,
      frontendApiUrl:
      recordedDependencies.configurationManager.frontendApiUrl,
      publishableKey:
      recordedDependencies.configurationManager.publishableKey
    )
    let intentStore = InMemoryAppContainerIdentityClearIntentStore(
      intent: recordedIntent
    )
    let recoveryKeychain = FailFirstAdoptionMarkerWriteKeychain()
    clerk.appContainerIdentityClearIntentStore = intentStore
    clerk.appContainerIdentityClearRecovery =
      AppContainerIdentityClearRecovery(
        storageProvider: { _ in recoveryKeychain },
        slotStoreProvider: { _ in
          RecordingAppContainerSlotStore()
        }
      )
    let currentHost = "current-routing.clerk.example.com"
    let encodedHost = Data("\(currentHost)$".utf8)
      .base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
    let currentPublishableKey = "pk_test_\(encodedHost)"
    let currentService =
      "com.example.current-routing.\(UUID().uuidString)"

    try clerk.performConfiguration(
      publishableKey: currentPublishableKey,
      options: .init(
        keychainConfig: .init(service: currentService)
      )
    )
    defer { clerk.cleanupManagers() }

    #expect(
      clerk.publishableKey == currentPublishableKey
    )
    #expect(clerk.persistenceStatus.identityStorage == .durable)
    #expect(clerk.dependencies.atomicIdentityStore == nil)
    #expect(clerk.persistenceStatus.readiness == .blocked(.pendingClear))
    #expect(try intentStore.load() == recordedIntent)

    await clerk.onWillEnterForeground()

    #expect(clerk.persistenceStatus.identityStorage == .durable)
    #expect(clerk.dependencies.atomicIdentityStore == nil)
    #expect(clerk.persistenceStatus.readiness == .ready)
    #expect(try intentStore.load() == nil)
  }

  @Test
  func durableAtomicBootstrapPerformsThreeSynchronousReads() throws {
    let clerk = Clerk()
    let keychain = ReadCountingKeychain()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      appLocalKeychain: keychain,
      identityKeychain: keychain,
      atomicIdentityStore: SharedSessionLocalIdentityStore(keychain: keychain)
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init()
    )

    try clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }

    #expect(keychain.readCount == 3)
    #expect(
      keychain.readCount(forKey: SharedSessionLocalIdentityStore.storageKey)
        == 2
    )
    #expect(
      keychain.readCount(
        forKey: ClerkKeychainKey.cachedEnvironment.rawValue
      ) == 1
    )
  }

  @Test
  func legacyBootstrapProbesOneIdentityKeyAndHydratesEnvironmentBestEffort()
    throws
  {
    let clerk = Clerk()
    let keychain = ReadCountingKeychain()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      appLocalKeychain: keychain,
      identityKeychain: keychain
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init()
    )

    try clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }

    #expect(keychain.readCount == 4)
    #expect(
      keychain.readCount(forKey: ClerkKeychainKey.cachedClient.rawValue)
        == 1
    )
    #expect(
      keychain.readCount(
        forKey: ClerkKeychainKey.cachedClientServerDate.rawValue
      ) == 1
    )
    #expect(
      keychain.readCount(
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      ) == 1
    )
    #expect(
      keychain.readCount(
        forKey: ClerkKeychainKey.cachedEnvironment.rawValue
      ) == 1
    )
  }

  @Test
  func legacyProbeChecksUnavailableTokenWhenClientIsAbsent() throws {
    let keychain = ReadCountingKeychain(
      readError: KeychainError.unexpectedStatus(
        errSecInteractionNotAllowed
      ),
      failingReadKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )
    let clerk = Clerk()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      appLocalKeychain: keychain,
      identityKeychain: keychain
    )

    do {
      try dependencies.probeLocalIdentityPersistence()
      Issue.record("Expected the unavailable device token probe to fail.")
    } catch {
      #expect(
        PersistenceFailureKind.classify(error)
          == .temporarilyUnavailable
      )
    }

    #expect(
      keychain.readCount(
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      ) == 1
    )
    #expect(
      keychain.readCount(forKey: ClerkKeychainKey.cachedClient.rawValue)
        == 0
    )
  }

  @Test
  func unavailableEnvironmentCacheDoesNotBlockDurableIdentityBootstrap()
    throws
  {
    let clerk = Clerk()
    let identityKeychain = ReadCountingKeychain()
    let environmentKeychain = ReadCountingKeychain(
      readError: KeychainError.unexpectedStatus(
        errSecMissingEntitlement
      )
    )
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: identityKeychain,
      appLocalKeychain: environmentKeychain,
      identityKeychain: identityKeychain,
      atomicIdentityStore: SharedSessionLocalIdentityStore(
        keychain: identityKeychain
      )
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init()
    )

    try clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }

    #expect(identityKeychain.readCount == 2)
    #expect(environmentKeychain.readCount == 1)
    #expect(clerk.persistenceStatus.identityStorage == .durable)
    #expect(clerk.persistenceStatus.readiness == .ready)
  }

  @Test
  func missingEntitlementFallbackSequencePerformsThreeBoundedReads() throws {
    let clerk = Clerk()
    let durableKeychain = ReadCountingKeychain(
      readError: KeychainError.unexpectedStatus(
        errSecMissingEntitlement
      )
    )
    let durableDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: durableKeychain,
      appLocalKeychain: durableKeychain,
      identityKeychain: durableKeychain,
      atomicIdentityStore: SharedSessionLocalIdentityStore(
        keychain: durableKeychain
      )
    )

    do {
      try durableDependencies.probeLocalIdentityPersistence()
      Issue.record("Expected the durable identity probe to fail.")
    } catch {
      #expect(PersistenceFailureKind.classify(error) == .missingEntitlement)
    }

    // This is the same install phase used after production configuration
    // replaces an unavailable durable container with volatile dependencies.
    let volatileKeychain = ReadCountingKeychain()
    let volatileDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: volatileKeychain,
      appLocalKeychain: volatileKeychain,
      identityKeychain: volatileKeychain,
      atomicIdentityStore: SharedSessionLocalIdentityStore(
        keychain: volatileKeychain
      ),
      usesVolatileIdentityPersistence: true
    )
    try volatileDependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init()
    )

    clerk.installConfiguration(dependencies: volatileDependencies)
    defer { clerk.cleanupManagers() }

    #expect(durableKeychain.readCount == 1)
    #expect(volatileKeychain.readCount == 2)
    #expect(
      durableKeychain.readCount + volatileKeychain.readCount == 3
    )
  }

  @Test
  func sharedSessionBootstrapPerformsFourSynchronousLocalReads() throws {
    let clerk = Clerk()
    let keychain = ReadCountingKeychain()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      appLocalKeychain: keychain,
      identityKeychain: keychain,
      atomicIdentityStore: SharedSessionLocalIdentityStore(keychain: keychain),
      sharedSessionOwnerIdentifier: "com.example.app"
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(
          service: "com.example.clerk",
          accessGroup: "TEAMID.com.example.shared"
        ),
        sharedSessionSync: .enabled
      )
    )

    try clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }

    #expect(keychain.readCount == 4)
    #expect(
      keychain.readCount(forKey: SharedSessionLocalIdentityStore.storageKey)
        == 3
    )
    #expect(
      keychain.readCount(
        forKey: ClerkKeychainKey.cachedEnvironment.rawValue
      ) == 1
    )
  }

  @Test(
    arguments: [
      ReconciliationCase(
        localDate: nil,
        baseGeneration: nil,
        sharedGeneration: nil,
        sharedDate: nil,
        expected: .publishLocal,
        label: "no shared winner"
      ),
      ReconciliationCase(
        localDate: nil,
        baseGeneration: 5,
        sharedGeneration: 5,
        sharedDate: nil,
        expected: .publishLocal,
        label: "shared identity did not advance beyond base"
      ),
      ReconciliationCase(
        localDate: nil,
        baseGeneration: 5,
        sharedGeneration: 6,
        sharedDate: nil,
        expected: .acceptShared,
        label: "ambiguous newer shared generation"
      ),
      ReconciliationCase(
        localDate: Date(timeIntervalSince1970: 200),
        baseGeneration: 5,
        sharedGeneration: 6,
        sharedDate: Date(timeIntervalSince1970: 100),
        expected: .publishLocal,
        label: "newer local server date"
      ),
      ReconciliationCase(
        localDate: Date(timeIntervalSince1970: 100),
        baseGeneration: 5,
        sharedGeneration: 6,
        sharedDate: Date(timeIntervalSince1970: 200),
        expected: .acceptShared,
        label: "newer shared server date"
      ),
    ]
  )
  func degradedLocalIdentityReconcilesDeterministically(
    _ testCase: ReconciliationCase
  ) {
    let local = makeIdentity(serverDate: testCase.localDate)
    let sharedWinner = testCase.sharedGeneration.map {
      makeEvent(
        generation: $0,
        serverDate: testCase.sharedDate
      )
    }

    #expect(
      SharedSessionRecoveryReconciler.decision(
        local: local,
        baseGeneration: testCase.baseGeneration,
        sharedWinner: sharedWinner
      ) == testCase.expected
    )
  }

  @Test
  func localMutationRecordsItsSharedBaseGeneration() throws {
    let store = SharedSessionLocalIdentityStore(
      keychain: InMemoryKeychain()
    )
    let identity = makeIdentity(serverDate: Date(timeIntervalSince1970: 300))

    try store.saveUnpublishedLocalIdentity(
      identity,
      baseGeneration: 12
    )

    let record = try #require(try store.loadRecord())
    #expect(record.acceptedIdentity == identity)
    #expect(record.hasUnpublishedLocalMutation)
    #expect(record.sharedSessionBaseGeneration == 12)
  }

  private func makeIdentity(serverDate: Date?) -> ClerkIdentitySnapshot {
    var client = Client.mockSignedOut
    client.id = "local-client"
    return ClerkIdentitySnapshot(
      state: .present,
      deviceToken: "local-token",
      client: client,
      serverDate: serverDate
    )
  }

  private func makeEvent(
    generation: UInt64,
    serverDate: Date?
  ) -> SharedSessionIdentityEvent {
    var client = Client.mockSignedOut
    client.id = "shared-client"
    return SharedSessionIdentityEvent(
      id: UUID(),
      originOwnerIdentifier: "peer.app",
      generation: generation,
      state: .present,
      deviceToken: "shared-token",
      client: client,
      serverDate: serverDate
    )
  }
}

private enum IdentityPersistenceBootstrapTestError: Error {
  case unexpectedMutation
  case unexpectedTargetLookup
}

private final class RecordingAppContainerSlotStore:
  @unchecked Sendable,
  SharedSessionSlotStoring
{
  private let lock = NSLock()
  private var deletions = 0

  var deleteCount: Int {
    lock.withLock { deletions }
  }

  func loadOwnSlot() throws -> SharedSessionOwnerSlot? {
    nil
  }

  func loadAllSlots() throws -> [SharedSessionOwnerSlot] {
    []
  }

  func saveOwnSlot(_: SharedSessionOwnerSlot) throws {}

  func deleteOwnSlot() throws {
    lock.withLock {
      deletions += 1
    }
  }
}

private final class OperationRecordingKeychain:
  @unchecked Sendable,
  KeychainStorage
{
  struct Operation: Equatable {
    enum Kind: Equatable {
      case set
      case read
      case delete
      case hasItem
    }

    let kind: Kind
    let key: String
  }

  private let lock = NSLock()
  private var storage: [String: Data] = [:]
  private var recordedOperations: [Operation] = []

  var operations: [Operation] {
    lock.withLock { recordedOperations }
  }

  func resetOperations() {
    lock.withLock {
      recordedOperations.removeAll()
    }
  }

  func set(_ data: Data, forKey key: String) throws {
    lock.withLock {
      recordedOperations.append(.init(kind: .set, key: key))
      storage[key] = data
    }
  }

  func data(forKey key: String) throws -> Data? {
    lock.withLock {
      recordedOperations.append(.init(kind: .read, key: key))
      return storage[key]
    }
  }

  func deleteItem(forKey key: String) throws {
    lock.withLock {
      recordedOperations.append(.init(kind: .delete, key: key))
      storage[key] = nil
    }
  }

  func hasItem(forKey key: String) throws -> Bool {
    lock.withLock {
      recordedOperations.append(.init(kind: .hasItem, key: key))
      return storage[key] != nil
    }
  }
}

private final class FailFirstAdoptionMarkerWriteKeychain:
  @unchecked Sendable,
  KeychainStorage
{
  private let lock = NSLock()
  private let backing = InMemoryKeychain()
  private var shouldFailAdoptionMarkerWrite = true

  func set(_ data: Data, forKey key: String) throws {
    let shouldFail = lock.withLock {
      guard shouldFailAdoptionMarkerWrite,
            key == ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
      else {
        return false
      }
      shouldFailAdoptionMarkerWrite = false
      return true
    }
    if shouldFail {
      throw KeychainError.unexpectedStatus(errSecNotAvailable)
    }
    try backing.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    try backing.data(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    try backing.deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try backing.hasItem(forKey: key)
  }
}

@MainActor
private final class FailingAppContainerIdentityClearIntentStore:
  AppContainerIdentityClearIntentStoring
{
  func load() throws -> AppContainerIdentityClearIntent? {
    nil
  }

  func record(_: AppContainerIdentityClearIntent) throws {
    throw IdentityPersistenceBootstrapTestError.unexpectedMutation
  }

  func remove(matching _: UUID) throws {
    throw IdentityPersistenceBootstrapTestError.unexpectedMutation
  }
}

@MainActor
private final class FailOnceRemovalAppContainerIdentityClearIntentStore:
  AppContainerIdentityClearIntentStoring
{
  private let backing = InMemoryAppContainerIdentityClearIntentStore()
  private var shouldFailRemoval = true

  func load() throws -> AppContainerIdentityClearIntent? {
    try backing.load()
  }

  func record(_ intent: AppContainerIdentityClearIntent) throws {
    try backing.record(intent)
  }

  func remove(matching transactionID: UUID) throws {
    if shouldFailRemoval {
      shouldFailRemoval = false
      throw IdentityPersistenceBootstrapTestError.unexpectedMutation
    }
    try backing.remove(matching: transactionID)
  }
}

private final class ReadCountingKeychain:
  @unchecked Sendable,
  KeychainStorage
{
  private let lock = NSLock()
  private let readError: (any Error)?
  private let failingReadKey: String?
  private var storage: [String: Data] = [:]
  private var readsByKey: [String: Int] = [:]

  init(
    readError: (any Error)? = nil,
    failingReadKey: String? = nil
  ) {
    self.readError = readError
    self.failingReadKey = failingReadKey
  }

  var readCount: Int {
    lock.withLock {
      readsByKey.values.reduce(0, +)
    }
  }

  func readCount(forKey key: String) -> Int {
    lock.withLock {
      readsByKey[key, default: 0]
    }
  }

  func set(_ data: Data, forKey key: String) throws {
    lock.withLock {
      storage[key] = data
    }
  }

  func data(forKey key: String) throws -> Data? {
    try lock.withLock {
      readsByKey[key, default: 0] += 1
      if let readError,
         failingReadKey == nil || failingReadKey == key
      {
        throw readError
      }
      return storage[key]
    }
  }

  func deleteItem(forKey key: String) throws {
    lock.withLock {
      storage[key] = nil
    }
  }

  func hasItem(forKey key: String) throws -> Bool {
    try data(forKey: key) != nil
  }
}

private final class MissingEntitlementJournal:
  @unchecked Sendable,
  KeychainStorage
{
  private let lock = NSLock()
  private var reads = 0

  var readCount: Int {
    lock.withLock { reads }
  }

  func set(_: Data, forKey _: String) throws {
    throw IdentityPersistenceBootstrapTestError.unexpectedMutation
  }

  func data(forKey _: String) throws -> Data? {
    lock.withLock { reads += 1 }
    throw KeychainError.unexpectedStatus(errSecMissingEntitlement)
  }

  func deleteItem(forKey _: String) throws {
    throw IdentityPersistenceBootstrapTestError.unexpectedMutation
  }

  func hasItem(forKey _: String) throws -> Bool {
    lock.withLock { reads += 1 }
    throw KeychainError.unexpectedStatus(errSecMissingEntitlement)
  }
}

private struct UnusedClearRecoveryTargets:
  SharedSessionClearRecoveryTargets
{
  func localIdentityStore(
    for _: SharedSessionOwnerSlotClearRecovery.Intent
  ) throws -> any SharedSessionLocalIdentityStoring {
    throw IdentityPersistenceBootstrapTestError.unexpectedTargetLookup
  }

  func slotStore(
    for _: SharedSessionOwnerSlotClearRecovery.Intent
  ) throws -> any SharedSessionSlotStoring {
    throw IdentityPersistenceBootstrapTestError.unexpectedTargetLookup
  }

  func preventLegacyIdentityReadoption(
    for _: SharedSessionOwnerSlotClearRecovery.Intent
  ) throws {
    throw IdentityPersistenceBootstrapTestError.unexpectedTargetLookup
  }
}
