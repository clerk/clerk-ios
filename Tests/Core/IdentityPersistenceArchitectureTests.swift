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
      try coordinator.validate(
        staleOwnership,
        operation: .bootstrap
      )
    }

    let mismatchedEpochOwnership = PersistenceTransitionOwnership(
      id: ownership.id,
      configurationEpoch: clerk.nextConfigurationEpoch
    )
    #expect(throws: CancellationError.self) {
      try coordinator.validate(
        mismatchedEpochOwnership,
        operation: .bootstrap,
        expectedEpoch: clerk.configurationEpoch
      )
    }

    clerk.setConfigurationEpoch(to: clerk.nextConfigurationEpoch)

    #expect(throws: CancellationError.self) {
      try coordinator.validate(
        ownership,
        operation: .bootstrap
      )
    }
  }

  @Test
  func validationRequiresMatchingOperationKind() throws {
    let clerk = Clerk()
    let coordinator = clerk.identityPersistenceOperationCoordinator
    let ownership = try coordinator.beginClear(epoch: clerk.configurationEpoch)

    try coordinator.validate(ownership, operation: .clear)
    #expect(throws: CancellationError.self) {
      try coordinator.validate(ownership, operation: .bootstrap)
    }
    #expect(throws: CancellationError.self) {
      try coordinator.validate(ownership, operation: .reconfigure)
    }

    guard case .running(let operation) =
      coordinator.transitionState
    else {
      Issue.record("Expected an active clear operation")
      return
    }
    #expect(operation.kind == .clear)
    #expect(operation.ownership == ownership)
  }

  @Test
  func validationSupportsIntentionalReconfigurationEpochHandoff() throws {
    let clerk = Clerk()
    let coordinator = clerk.identityPersistenceOperationCoordinator
    let ownership = try coordinator.beginReconfiguration(
      epoch: clerk.configurationEpoch
    )
    let nextEpoch = clerk.nextConfigurationEpoch

    clerk.setConfigurationEpoch(to: nextEpoch)

    #expect(throws: CancellationError.self) {
      try coordinator.validate(ownership, operation: .reconfigure)
    }
    try coordinator.validate(
      ownership,
      operation: .reconfigure,
      expectedEpoch: nextEpoch
    )
  }

  @Test
  func validationChecksTaskCancellation() async {
    let clerk = Clerk()
    let coordinator = clerk.identityPersistenceOperationCoordinator
    let ownership = coordinator.beginBootstrap(epoch: clerk.configurationEpoch)
    let task = Task { @MainActor in
      try coordinator.validate(ownership, operation: .bootstrap)
    }

    task.cancel()

    await #expect(throws: CancellationError.self) {
      try await task.value
    }
  }

  @Test
  func failedClearPreflightPreservesActiveBootstrap() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
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
    clerk.dependencies = dependencies
    clerk.appContainerIdentityClearIntentStore =
      FailingAppContainerIdentityClearIntentStore()

    let coordinator = clerk.identityPersistenceOperationCoordinator
    coordinator.reset(
      identityCapability: .durable,
      sharedSessionCapability: .unavailable(.temporarilyUnavailable)
    )
    let ownership = coordinator.beginBootstrap(
      epoch: clerk.configurationEpoch
    )
    let gate = PersistenceBootstrapGate()
    let bootstrap = Task { @MainActor in
      await gate.waitForRelease()
      try coordinator.validate(ownership, operation: .bootstrap)
      coordinator.setSharedSessionCapability(.active)
      coordinator.finish(ownership)
    }
    defer {
      gate.release()
      bootstrap.cancel()
    }
    await gate.waitUntilEntered()

    await #expect(throws: (any Error).self) {
      try await clerk.clearAllKeychainItemsAndWait()
    }

    #expect(coordinator.isActive(ownership, operation: .bootstrap))
    #expect(clerk.persistenceStatus.readiness == .transitioning)
    #expect(
      clerk.persistenceStatus.sharedSession
        == .unavailable(.temporarilyUnavailable)
    )

    gate.release()
    try await bootstrap.value

    #expect(clerk.persistenceStatus.readiness == .ready)
    #expect(clerk.persistenceStatus.sharedSession == .active)
  }

  @Test
  func clearContinuesWhenIntentRecordThrowsAfterPersisting() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
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
    clerk.dependencies = dependencies
    let intentStore =
      FailAfterPersistAppContainerIdentityClearIntentStore()
    clerk.appContainerIdentityClearIntentStore = intentStore

    let coordinator = clerk.identityPersistenceOperationCoordinator
    coordinator.reset(
      identityCapability: .durable,
      sharedSessionCapability: .unavailable(.temporarilyUnavailable)
    )
    let ownership = coordinator.beginBootstrap(
      epoch: clerk.configurationEpoch
    )

    try await clerk.clearAllKeychainItemsAndWait()

    #expect(!coordinator.isActive(ownership, operation: .bootstrap))
    #expect(clerk.persistenceStatus.readiness == .ready)
    #expect(try intentStore.load() == nil)
  }

  @Test
  func failedReconfigurationPreflightPreservesActiveBootstrap()
    async throws
  {
    let clerk = Clerk()
    let coordinator = clerk.identityPersistenceOperationCoordinator
    coordinator.reset(
      identityCapability: .durable,
      sharedSessionCapability: .unavailable(.temporarilyUnavailable)
    )
    let ownership = coordinator.beginBootstrap(
      epoch: clerk.configurationEpoch
    )
    let gate = PersistenceBootstrapGate()
    let bootstrap = Task { @MainActor in
      await gate.waitForRelease()
      try coordinator.validate(ownership, operation: .bootstrap)
      coordinator.setSharedSessionCapability(.active)
      coordinator.finish(ownership)
    }
    defer {
      gate.release()
      bootstrap.cancel()
    }
    await gate.waitUntilEntered()

    await #expect(throws: ClerkInitializationError.self) {
      try await clerk.performReconfiguration(
        publishableKey: "invalid_key",
        options: .init()
      )
    }

    #expect(coordinator.isActive(ownership, operation: .bootstrap))
    #expect(clerk.persistenceStatus.readiness == .transitioning)
    #expect(
      clerk.persistenceStatus.sharedSession
        == .unavailable(.temporarilyUnavailable)
    )

    gate.release()
    try await bootstrap.value

    #expect(clerk.persistenceStatus.readiness == .ready)
    #expect(clerk.persistenceStatus.sharedSession == .active)
  }

  @Test
  func disablingSharedSyncSettlesAliasedPendingPublicationBeforeDiscard()
    async throws
  {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(
      keychain: keychain
    )
    let ownerIdentifier = "com.example.source"
    let instanceFingerprint = "same-scope-instance"
    let keychainConfig = Clerk.Options.KeychainConfig(
      service: "com.example.same-scope"
    )

    var acceptedClient = Client.mockSignedOut
    acceptedClient.id = "accepted-a"
    let acceptedIdentity = try ClerkIdentitySnapshot(
      state: .present,
      deviceToken: "token-a",
      client: acceptedClient,
      serverDate: Date(timeIntervalSince1970: 100)
    ).validated()
    let acceptedEventID = try #require(
      UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")
    )
    let acceptedEvent = try SharedSessionIdentityEvent(
      id: acceptedEventID,
      originOwnerIdentifier: ownerIdentifier,
      generation: 1,
      state: acceptedIdentity.state,
      deviceToken: acceptedIdentity.deviceToken,
      client: acceptedIdentity.client,
      serverDate: acceptedIdentity.serverDate
    ).validated()

    var pendingClient = Client.mockSignedOut
    pendingClient.id = "pending-b"
    let pendingEventID = try #require(
      UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")
    )
    let pendingEvent = try SharedSessionIdentityEvent(
      id: pendingEventID,
      originOwnerIdentifier: ownerIdentifier,
      generation: 2,
      state: .present,
      deviceToken: "token-b",
      client: pendingClient,
      serverDate: Date(timeIntervalSince1970: 200)
    ).validated()

    try identityStore.save(acceptedIdentity)
    try identityStore.stagePendingPublication(pendingEvent)
    let slotStore = ReconfigurationPendingPublicationSlotStore(
      ownerIdentifier: ownerIdentifier,
      slots: [
        SharedSessionOwnerSlot(
          schemaVersion: SharedSessionOwnerSlot.schemaVersion,
          instanceFingerprint: instanceFingerprint,
          slotOwnerIdentifier: ownerIdentifier,
          event: acceptedEvent
        ),
      ]
    )

    let source = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      appLocalKeychain: keychain,
      identityKeychain: keychain,
      atomicIdentityStore: identityStore,
      sharedSessionOwnerIdentifier: ownerIdentifier,
      clientService: MockClientService(get: { nil })
    )
    try source.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: keychainConfig,
        sharedSessionSync: .enabled
      )
    )
    clerk.dependencies = source
    clerk.identityController.hydrateAtomicIdentityIfNeeded(
      acceptedIdentity
    )
    clerk.sharedSessionSyncCoordinator = SharedSessionSyncCoordinator(
      ownerIdentifier: ownerIdentifier,
      instanceFingerprint: instanceFingerprint,
      slotStore: slotStore,
      localIdentityStore: identityStore,
      localIdentityIO: source.atomicIdentityIO,
      notifier: ReconfigurationPendingPublicationNotifier(),
      configurationEpoch: clerk.configurationEpoch,
      clerk: clerk
    )
    defer { clerk.cleanupManagers() }

    let dependencyFactory: Clerk.ReconfigurationDependencyFactory = {
      publishableKey,
      options,
      runtimeScope in
      let target = MockDependencyContainer(
        apiClient: createMockAPIClient(runtimeScope: runtimeScope),
        keychain: keychain,
        appLocalKeychain: keychain,
        identityKeychain: keychain,
        atomicIdentityStore: identityStore,
        sharedSessionOwnerIdentifier: ownerIdentifier,
        clientService: MockClientService(get: { nil })
      )
      try target.configurationManager.configure(
        publishableKey: publishableKey,
        options: options
      )
      return target
    }

    let reconfigured = try await clerk.performReconfiguration(
      publishableKey: testPublishableKey,
      options: .init(keychainConfig: keychainConfig),
      dependencyFactory: dependencyFactory
    )

    let record = try #require(try identityStore.loadRecord())
    #expect(record.pendingPublication == nil)
    #expect(record.acceptedIdentity?.client?.id == pendingClient.id)
    #expect(record.acceptedIdentity?.deviceToken == "token-b")
    #expect(try slotStore.loadOwnSlot()?.event == pendingEvent)
    #expect(reconfigured.client?.id == pendingClient.id)
    #expect(reconfigured.identityController.currentDeviceToken == "token-b")
  }

  @Test
  func cancellationAfterSourceRetirementCommitStillInstallsTarget()
    async throws
  {
    let clerk = Clerk()
    let sourceKeychain = InMemoryKeychain()
    let sourceIdentityStore = SharedSessionLocalIdentityStore(
      keychain: sourceKeychain
    )
    var sourceClient = Client.mockSignedOut
    sourceClient.id = "source-client"
    let sourceIdentity = try ClerkIdentitySnapshot(
      state: .present,
      deviceToken: "source-token",
      client: sourceClient,
      serverDate: Date(timeIntervalSince1970: 100)
    ).validated()
    try sourceIdentityStore.save(sourceIdentity)

    let keychainConfig = Clerk.Options.KeychainConfig(
      service: "com.example.reconfiguration-commit",
      accessGroup: "TEAM.shared"
    )
    let source = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: sourceKeychain,
      appLocalKeychain: sourceKeychain,
      identityKeychain: sourceKeychain,
      atomicIdentityStore: sourceIdentityStore,
      sharedSessionOwnerIdentifier: "com.example.source",
      clientService: MockClientService(get: { nil })
    )
    try source.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: keychainConfig,
        sharedSessionSync: .enabled
      )
    )
    clerk.dependencies = source
    clerk.identityController.hydrateAtomicIdentityIfNeeded(sourceIdentity)

    let targetKeychain = InMemoryKeychain()
    let targetIdentityStore = SharedSessionLocalIdentityStore(
      keychain: targetKeychain
    )
    var target: MockDependencyContainer?
    let dependencyFactory: Clerk.ReconfigurationDependencyFactory = {
      publishableKey,
      options,
      runtimeScope in
      let dependencies = MockDependencyContainer(
        apiClient: createMockAPIClient(runtimeScope: runtimeScope),
        keychain: targetKeychain,
        appLocalKeychain: targetKeychain,
        identityKeychain: targetKeychain,
        atomicIdentityStore: targetIdentityStore,
        sharedSessionOwnerIdentifier: "com.example.source",
        clientService: MockClientService(get: { nil })
      )
      try dependencies.configurationManager.configure(
        publishableKey: publishableKey,
        options: options
      )
      target = dependencies
      return dependencies
    }

    let retirementGate = PersistenceBootstrapGate()
    let reconfiguration = Task { @MainActor in
      try await clerk.performReconfiguration(
        publishableKey: testPublishableKey,
        options: .init(keychainConfig: keychainConfig),
        dependencyFactory: dependencyFactory,
        sourceRetirement: { _ in
          await retirementGate.waitForRelease()
        }
      )
    }
    defer {
      retirementGate.release()
      reconfiguration.cancel()
      clerk.cleanupManagers()
    }

    await retirementGate.waitUntilEntered()
    reconfiguration.cancel()
    retirementGate.release()

    let reconfigured = try await reconfiguration.value
    let installedTarget = try #require(target)
    #expect(reconfigured.dependencies === installedTarget)
    #expect(reconfigured.client?.id == sourceClient.id)
    #expect(reconfigured.persistenceStatus.readiness == .ready)
  }

  @Test
  func failedIdentityReplacementRemainsBlockedAcrossRelaunch()
    async throws
  {
    let temporaryRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }
    let intentURL = temporaryRoot.appendingPathComponent(
      "pending-clear.json",
      isDirectory: false
    )

    let clerk = Clerk()
    let intentStore = FileAppContainerIdentityClearIntentStore(
      fileURL: intentURL
    )
    clerk.appContainerIdentityClearIntentStore = intentStore
    let sourceKeychain = FailAfterFirstDeleteKeychain()
    let sourceIdentityStore = SharedSessionLocalIdentityStore(
      keychain: sourceKeychain
    )
    let sourceIdentity = makeIdentity(
      serverDate: Date(timeIntervalSince1970: 100)
    )
    try sourceIdentityStore.save(sourceIdentity)
    let sourceOptions = Clerk.Options(
      keychainConfig: .init(service: "com.example.reconfiguration-source")
    )
    let source = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: sourceKeychain,
      appLocalKeychain: sourceKeychain,
      identityKeychain: sourceKeychain,
      atomicIdentityStore: sourceIdentityStore,
      clientService: MockClientService(get: { nil })
    )
    try source.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: sourceOptions
    )
    try clerk.performConfiguration(dependencies: source)
    defer { clerk.cleanupManagers() }
    #expect(clerk.client?.id == sourceIdentity.client?.id)

    let targetKeychain = InMemoryKeychain()
    let targetOptions = Clerk.Options(
      keychainConfig: .init(service: "com.example.reconfiguration-target")
    )
    let dependencyFactory: Clerk.ReconfigurationDependencyFactory = {
      publishableKey,
      options,
      runtimeScope in
      let target = MockDependencyContainer(
        apiClient: createMockAPIClient(runtimeScope: runtimeScope),
        keychain: targetKeychain,
        appLocalKeychain: targetKeychain,
        identityKeychain: targetKeychain,
        atomicIdentityStore: SharedSessionLocalIdentityStore(
          keychain: targetKeychain
        ),
        clientService: MockClientService(get: { nil })
      )
      try target.configurationManager.configure(
        publishableKey: publishableKey,
        options: options
      )
      return target
    }

    await #expect(throws: (any Error).self) {
      try await clerk.performReconfiguration(
        publishableKey: testPublishableKey,
        options: targetOptions,
        dependencyFactory: dependencyFactory
      )
    }

    #expect(clerk.dependencies === source)
    #expect(clerk.client == nil)
    #expect(clerk.persistenceStatus.readiness == .blocked(.pendingClear))
    #expect(try intentStore.load() != nil)
    #expect(try sourceIdentityStore.load() == sourceIdentity)

    clerk.cleanupManagers()
    sourceKeychain.allowDeletes()

    let relaunchedClerk = Clerk()
    let relaunchedIntentStore = FileAppContainerIdentityClearIntentStore(
      fileURL: intentURL
    )
    relaunchedClerk.appContainerIdentityClearIntentStore =
      relaunchedIntentStore
    relaunchedClerk.appContainerIdentityClearRecovery =
      AppContainerIdentityClearRecovery(
        storageProvider: { _ in sourceKeychain }
      )
    let relaunchedSource = MockDependencyContainer(
      apiClient: createMockAPIClient(
        runtimeScope: relaunchedClerk.runtimeScope
      ),
      keychain: sourceKeychain,
      appLocalKeychain: sourceKeychain,
      identityKeychain: sourceKeychain,
      atomicIdentityStore: sourceIdentityStore,
      clientService: MockClientService(get: { nil })
    )
    try relaunchedSource.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: sourceOptions
    )
    try relaunchedClerk.performConfiguration(
      dependencies: relaunchedSource
    )
    defer { relaunchedClerk.cleanupManagers() }

    #expect(relaunchedClerk.persistenceStatus.readiness == .ready)
    #expect(relaunchedClerk.client == nil)
    #expect(try sourceIdentityStore.load() == nil)
    #expect(try relaunchedIntentStore.load() == nil)
  }

  @Test
  func overlappingReplacementFailureRecoversBothTopologiesOnTargetRelaunch()
    async throws
  {
    let temporaryRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }
    let intentURL = temporaryRoot.appendingPathComponent(
      "pending-clear.json",
      isDirectory: false
    )

    let ownerIdentifier = "com.example.reconfiguration-app"
    let sourcePublishableKey = publishableKey(
      for: "source-reconfiguration.clerk.example.com"
    )
    let targetPublishableKey = publishableKey(
      for: "target-reconfiguration.clerk.example.com"
    )
    let options = Clerk.Options(
      keychainConfig: .init(
        service: "com.example.reconfiguration-shared",
        accessGroup: "TEAMID.com.example.reconfiguration-shared",
        appLocalAccessGroup: "TEAMID.\(ownerIdentifier)"
      )
    )

    let configuredSharedStorage = InMemoryKeychain()
    let configuredAppLocalStorage = FailAfterFirstDeleteKeychain()
    let previousAppLocalStorage = InMemoryKeychain()
    let sourceStableStorage = InMemoryKeychain()
    let targetStableStorage = InMemoryKeychain()
    let clearJournalStorage = InMemoryKeychain()
    let sourceIdentityStore = SharedSessionLocalIdentityStore(
      keychain: sourceStableStorage
    )
    let targetIdentityStore = SharedSessionLocalIdentityStore(
      keychain: targetStableStorage
    )
    let sourceIdentity = makeIdentity(
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let targetIdentity = makeIdentity(
      serverDate: Date(timeIntervalSince1970: 200)
    )
    try sourceIdentityStore.save(sourceIdentity)
    try targetIdentityStore.save(targetIdentity)
    try previousAppLocalStorage.set(
      Data("previous-app-local".utf8),
      forKey: ClerkKeychainKey.cachedClient.rawValue
    )
    try configuredSharedStorage.set(
      Data("shared-credential".utf8),
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )

    let clerk = Clerk()
    let intentStore = FileAppContainerIdentityClearIntentStore(
      fileURL: intentURL
    )
    clerk.appContainerIdentityClearIntentStore = intentStore
    let source = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: configuredSharedStorage,
      appLocalKeychain: configuredAppLocalStorage,
      identityKeychain: sourceStableStorage,
      legacyAppLocalKeychain: previousAppLocalStorage,
      atomicIdentityStore: sourceIdentityStore,
      sharedSessionOwnerIdentifier: ownerIdentifier,
      clientService: MockClientService(get: { nil })
    )
    try source.configurationManager.configure(
      publishableKey: sourcePublishableKey,
      options: options
    )
    try clerk.performConfiguration(dependencies: source)
    defer { clerk.cleanupManagers() }
    let sourceIntent = try clerk.makeAppContainerIdentityClearIntent()

    var preparedTarget: MockDependencyContainer?
    let dependencyFactory: Clerk.ReconfigurationDependencyFactory = {
      publishableKey,
      options,
      runtimeScope in
      let target = MockDependencyContainer(
        apiClient: createMockAPIClient(runtimeScope: runtimeScope),
        keychain: configuredSharedStorage,
        appLocalKeychain: configuredAppLocalStorage,
        identityKeychain: targetStableStorage,
        legacyAppLocalKeychain: previousAppLocalStorage,
        atomicIdentityStore: targetIdentityStore,
        sharedSessionOwnerIdentifier: ownerIdentifier,
        clientService: MockClientService(get: { nil })
      )
      try target.configurationManager.configure(
        publishableKey: publishableKey,
        options: options
      )
      preparedTarget = target
      return target
    }

    await #expect(throws: (any Error).self) {
      try await clerk.performReconfiguration(
        publishableKey: targetPublishableKey,
        options: options,
        dependencyFactory: dependencyFactory
      )
    }

    let target = try #require(preparedTarget)
    let targetIntent = try Clerk.makeAppContainerIdentityClearIntent(
      dependencies: target,
      options: options,
      frontendApiUrl: target.configurationManager.frontendApiUrl,
      publishableKey: targetPublishableKey
    )
    let recordedEnvelope = try #require(try intentStore.load())
    let additionalIntent = try #require(
      recordedEnvelope.additionalClearIntents?.first
    )
    #expect(
      recordedEnvelope.hasSameRecoveryTopology(as: sourceIntent)
    )
    #expect(additionalIntent.hasSameRecoveryTopology(as: targetIntent))
    #expect(recordedEnvelope.recordedClearIntents.count == 2)
    #expect(sourceIntent.activeStorageMayOverlap(with: targetIntent))
    #expect(clerk.persistenceStatus.readiness == .blocked(.pendingClear))
    #expect(try sourceIdentityStore.load() == sourceIdentity)
    #expect(try targetIdentityStore.load() == targetIdentity)

    clerk.cleanupManagers()
    configuredAppLocalStorage.allowDeletes()

    let relaunchedOptions = Clerk.Options(
      keychainConfig: .init(
        service: "com.example.relaunch-shared",
        accessGroup: "TEAMID.com.example.relaunch-shared",
        appLocalAccessGroup: "TEAMID.\(ownerIdentifier)"
      )
    )
    let relaunchedSharedStorage = InMemoryKeychain()
    let relaunchedAppLocalStorage = InMemoryKeychain()
    let relaunchedStableStorage = InMemoryKeychain()
    let relaunchedIdentityStore = SharedSessionLocalIdentityStore(
      keychain: relaunchedStableStorage
    )
    let relaunchedIdentity = makeIdentity(
      serverDate: Date(timeIntervalSince1970: 300)
    )
    try relaunchedIdentityStore.save(relaunchedIdentity)
    try relaunchedSharedStorage.set(
      Data("relaunched-shared-credential".utf8),
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )
    try relaunchedAppLocalStorage.set(
      Data("relaunched-private-credential".utf8),
      forKey: ClerkKeychainKey.cachedClient.rawValue
    )

    let sourceOwnerSlot = try #require(sourceIntent.ownerSlot)
    let targetOwnerSlot = try #require(targetIntent.ownerSlot)
    let sourceSlotStore = RecordingAppContainerSlotStore()
    let targetSlotStore = RecordingAppContainerSlotStore()
    let relaunchedClerk = Clerk()
    let relaunchedTarget = MockDependencyContainer(
      apiClient: createMockAPIClient(
        runtimeScope: relaunchedClerk.runtimeScope
      ),
      keychain: relaunchedSharedStorage,
      appLocalKeychain: relaunchedAppLocalStorage,
      identityKeychain: relaunchedStableStorage,
      legacyAppLocalKeychain: previousAppLocalStorage,
      atomicIdentityStore: relaunchedIdentityStore,
      sharedSessionOwnerIdentifier: ownerIdentifier,
      clientService: MockClientService(get: { nil })
    )
    try relaunchedTarget.configurationManager.configure(
      publishableKey: targetPublishableKey,
      options: relaunchedOptions
    )
    let relaunchedIntent = try Clerk.makeAppContainerIdentityClearIntent(
      dependencies: relaunchedTarget,
      options: relaunchedOptions,
      frontendApiUrl:
      relaunchedTarget.configurationManager.frontendApiUrl,
      publishableKey: targetPublishableKey
    )
    #expect(
      relaunchedIntent.instanceFingerprint
        == targetIntent.instanceFingerprint
    )
    #expect(!relaunchedIntent.hasSameRecoveryTopology(as: targetIntent))
    let relaunchedOwnerSlot = try #require(relaunchedIntent.ownerSlot)
    let relaunchedSlotStore = RecordingAppContainerSlotStore()
    let relaunchedIntentStore = FileAppContainerIdentityClearIntentStore(
      fileURL: intentURL
    )
    relaunchedClerk.appContainerIdentityClearIntentStore =
      relaunchedIntentStore
    relaunchedClerk.appContainerIdentityClearRecovery =
      AppContainerIdentityClearRecovery(
        storageProvider: { clearTarget in
          if clearTarget == sourceIntent.stableIdentity {
            return sourceStableStorage
          }
          if clearTarget == targetIntent.stableIdentity {
            return targetStableStorage
          }
          if clearTarget == relaunchedIntent.stableIdentity {
            return relaunchedStableStorage
          }
          if clearTarget == sourceIntent.configuredAppLocal
            || clearTarget == targetIntent.configuredAppLocal
          {
            return configuredAppLocalStorage
          }
          if clearTarget == relaunchedIntent.configuredAppLocal {
            return relaunchedAppLocalStorage
          }
          if clearTarget == sourceIntent.configuredShared
            || clearTarget == targetIntent.configuredShared
          {
            return configuredSharedStorage
          }
          if clearTarget == relaunchedIntent.configuredShared {
            return relaunchedSharedStorage
          }
          if clearTarget == sourceIntent.previousAppLocal
            || clearTarget == targetIntent.previousAppLocal
            || clearTarget == relaunchedIntent.previousAppLocal
          {
            return previousAppLocalStorage
          }
          if clearTarget == sourceIntent.clearJournal
            || clearTarget == targetIntent.clearJournal
            || clearTarget == relaunchedIntent.clearJournal
          {
            return clearJournalStorage
          }
          throw IdentityPersistenceBootstrapTestError
            .unexpectedTargetLookup
        },
        slotStoreProvider: { ownerSlot in
          if ownerSlot == sourceOwnerSlot {
            return sourceSlotStore
          }
          if ownerSlot == targetOwnerSlot {
            return targetSlotStore
          }
          if ownerSlot == relaunchedOwnerSlot {
            return relaunchedSlotStore
          }
          throw IdentityPersistenceBootstrapTestError
            .unexpectedTargetLookup
        }
      )
    try relaunchedClerk.performConfiguration(
      dependencies: relaunchedTarget
    )
    defer { relaunchedClerk.cleanupManagers() }

    #expect(relaunchedClerk.persistenceStatus.readiness == .ready)
    #expect(relaunchedClerk.client == nil)
    #expect(try sourceIdentityStore.load() == nil)
    #expect(try targetIdentityStore.load() == nil)
    #expect(try relaunchedIdentityStore.load() == nil)
    #expect(
      try previousAppLocalStorage.data(
        forKey: ClerkKeychainKey.cachedClient.rawValue
      ) == nil
    )
    #expect(
      try configuredSharedStorage.data(
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      ) == nil
    )
    #expect(
      try relaunchedSharedStorage.data(
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      ) == nil
    )
    #expect(
      try relaunchedAppLocalStorage.data(
        forKey: ClerkKeychainKey.cachedClient.rawValue
      ) == nil
    )
    #expect(sourceSlotStore.deleteCount == 1)
    #expect(targetSlotStore.deleteCount == 1)
    #expect(relaunchedSlotStore.deleteCount == 1)
    #expect(try relaunchedIntentStore.load() == nil)
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
  func clearIntentEnvelopeRoundTripsAndRecoversOnlyRecordedTopologies()
    throws
  {
    let sharedService = "com.example.envelope-shared"
    let sharedAccessGroup = "TEAMID.com.example.envelope-shared"
    let recoveryClerk = Clerk()
    let runtimeScope = recoveryClerk.runtimeScope

    func makeIntent(
      ownerIdentifier: String,
      host: String
    ) throws -> AppContainerIdentityClearIntent {
      let dependencies = MockDependencyContainer(
        apiClient: createMockAPIClient(runtimeScope: runtimeScope),
        sharedSessionOwnerIdentifier: ownerIdentifier
      )
      let options = Clerk.Options(
        keychainConfig: .init(
          service: sharedService,
          accessGroup: sharedAccessGroup,
          appLocalAccessGroup: "TEAMID.\(ownerIdentifier)"
        ),
        sharedSessionSync: .enabled
      )
      let publishableKey = publishableKey(for: host)
      try dependencies.configurationManager.configure(
        publishableKey: publishableKey,
        options: options
      )
      return try Clerk.makeAppContainerIdentityClearIntent(
        dependencies: dependencies,
        options: options,
        frontendApiUrl: dependencies.configurationManager.frontendApiUrl,
        publishableKey: publishableKey
      )
    }

    let sourceIntent = try makeIntent(
      ownerIdentifier: "com.example.envelope-source",
      host: "envelope-source.clerk.example.com"
    )
    let targetIntent = try makeIntent(
      ownerIdentifier: "com.example.envelope-target",
      host: "envelope-target.clerk.example.com"
    )
    let unrecordedOwnerIdentifier =
      "com.example.envelope-unrecorded"
    let unrecordedPublishableKey = publishableKey(
      for: "envelope-unrecorded.clerk.example.com"
    )
    let unrecordedIntent = try makeIntent(
      ownerIdentifier: unrecordedOwnerIdentifier,
      host: "envelope-unrecorded.clerk.example.com"
    )
    #expect(sourceIntent.activeStorageMayOverlap(with: targetIntent))
    #expect(sourceIntent.activeStorageMayOverlap(with: unrecordedIntent))

    let envelope = try sourceIntent.includingClearIntent(targetIntent)
    let encoded = try JSONEncoder.clerkEncoder.encode(envelope)
    let decoded = try JSONDecoder.clerkDecoder.decode(
      AppContainerIdentityClearIntent.self,
      from: encoded
    ).validated()
    #expect(decoded == envelope)
    #expect(decoded.recordedClearIntents.count == 2)
    #expect(
      decoded.recordedClearIntents[0]
        .hasSameRecoveryTopology(as: sourceIntent)
    )
    #expect(
      decoded.recordedClearIntents[1]
        .hasSameRecoveryTopology(as: targetIntent)
    )

    let allIntents = [
      sourceIntent,
      targetIntent,
      unrecordedIntent,
    ]
    var storageByTarget: [
      AppContainerIdentityClearIntent.KeychainTarget: InMemoryKeychain
    ] = [:]
    for intent in allIntents {
      let targets =
        intent.uniqueKeychainTargets
          + [intent.clearJournal].compactMap(\.self)
      for clearTarget in targets where storageByTarget[clearTarget] == nil {
        storageByTarget[clearTarget] = InMemoryKeychain()
      }
    }

    let sourceStableStorage = try #require(
      storageByTarget[sourceIntent.stableIdentity]
    )
    let targetStableStorage = try #require(
      storageByTarget[targetIntent.stableIdentity]
    )
    let unrecordedStableStorage = try #require(
      storageByTarget[unrecordedIntent.stableIdentity]
    )
    let sourceIdentity = makeIdentity(
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let targetIdentity = makeIdentity(
      serverDate: Date(timeIntervalSince1970: 200)
    )
    let unrecordedIdentity = makeIdentity(
      serverDate: Date(timeIntervalSince1970: 300)
    )
    try SharedSessionLocalIdentityStore(
      keychain: sourceStableStorage
    ).save(sourceIdentity)
    try SharedSessionLocalIdentityStore(
      keychain: targetStableStorage
    ).save(targetIdentity)
    try SharedSessionLocalIdentityStore(
      keychain: unrecordedStableStorage
    ).save(unrecordedIdentity)

    let sourcePrevious = try #require(sourceIntent.previousAppLocal)
    let targetPrevious = try #require(targetIntent.previousAppLocal)
    let unrecordedPrevious = try #require(
      unrecordedIntent.previousAppLocal
    )
    try storageByTarget[sourcePrevious]?.set(
      Data("source-previous".utf8),
      forKey: ClerkKeychainKey.cachedClient.rawValue
    )
    try storageByTarget[targetPrevious]?.set(
      Data("target-previous".utf8),
      forKey: ClerkKeychainKey.cachedClient.rawValue
    )
    let unrecordedPreviousData = Data("unrecorded-previous".utf8)
    try storageByTarget[unrecordedPrevious]?.set(
      unrecordedPreviousData,
      forKey: ClerkKeychainKey.cachedClient.rawValue
    )

    let privateTopologyKey = ClerkKeychainKey.cachedEnvironment.rawValue
    try storageByTarget[sourceIntent.configuredAppLocal]?.set(
      Data("source-private".utf8),
      forKey: privateTopologyKey
    )
    try storageByTarget[targetIntent.configuredAppLocal]?.set(
      Data("target-private".utf8),
      forKey: privateTopologyKey
    )
    let unrecordedPrivateData = Data("unrecorded-private".utf8)
    try storageByTarget[unrecordedIntent.configuredAppLocal]?.set(
      unrecordedPrivateData,
      forKey: privateTopologyKey
    )

    let sourceJournal = try #require(sourceIntent.clearJournal)
    let targetJournal = try #require(targetIntent.clearJournal)
    let unrecordedJournal = try #require(
      unrecordedIntent.clearJournal
    )
    try storageByTarget[sourceJournal]?.set(
      Data("source-journal".utf8),
      forKey: SharedSessionOwnerSlotClearRecovery.storageKey
    )
    try storageByTarget[targetJournal]?.set(
      Data("target-journal".utf8),
      forKey: SharedSessionOwnerSlotClearRecovery.storageKey
    )
    let unrecordedJournalData = Data("unrecorded-journal".utf8)
    try storageByTarget[unrecordedJournal]?.set(
      unrecordedJournalData,
      forKey: SharedSessionOwnerSlotClearRecovery.storageKey
    )

    let sourceOwnerSlot = try #require(sourceIntent.ownerSlot)
    let targetOwnerSlot = try #require(targetIntent.ownerSlot)
    let unrecordedOwnerSlot = try #require(unrecordedIntent.ownerSlot)
    let sourceSlotStore = RecordingAppContainerSlotStore()
    let targetSlotStore = RecordingAppContainerSlotStore()
    let unrecordedSlotStore = RecordingAppContainerSlotStore()

    recoveryClerk.appContainerIdentityClearRecovery =
      AppContainerIdentityClearRecovery(
        storageProvider: { clearTarget in
          guard let storage = storageByTarget[clearTarget] else {
            throw IdentityPersistenceBootstrapTestError
              .unexpectedTargetLookup
          }
          return storage
        },
        slotStoreProvider: { ownerSlot in
          if ownerSlot == sourceOwnerSlot {
            return sourceSlotStore
          }
          if ownerSlot == targetOwnerSlot {
            return targetSlotStore
          }
          if ownerSlot == unrecordedOwnerSlot {
            return unrecordedSlotStore
          }
          throw IdentityPersistenceBootstrapTestError
            .unexpectedTargetLookup
        }
      )
    let unrecordedOptions = Clerk.Options(
      keychainConfig: .init(
        service: sharedService,
        accessGroup: sharedAccessGroup,
        appLocalAccessGroup: "TEAMID.\(unrecordedOwnerIdentifier)"
      ),
      sharedSessionSync: .enabled
    )
    let unrecordedSharedStorage = try #require(
      storageByTarget[unrecordedIntent.configuredShared]
    )
    let unrecordedAppLocalStorage = try #require(
      storageByTarget[unrecordedIntent.configuredAppLocal]
    )
    let unrecordedPreviousStorage = try #require(
      storageByTarget[unrecordedPrevious]
    )
    let unrecordedDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: runtimeScope),
      keychain: unrecordedSharedStorage,
      appLocalKeychain: unrecordedAppLocalStorage,
      identityKeychain: unrecordedStableStorage,
      legacyAppLocalKeychain: unrecordedPreviousStorage,
      atomicIdentityStore: SharedSessionLocalIdentityStore(
        keychain: unrecordedStableStorage
      ),
      sharedSessionOwnerIdentifier: unrecordedOwnerIdentifier
    )
    try unrecordedDependencies.configurationManager.configure(
      publishableKey: unrecordedPublishableKey,
      options: unrecordedOptions
    )
    try recoveryClerk.recoverAppContainerIdentityClear(
      decoded,
      protecting: unrecordedDependencies
    )

    #expect(
      try SharedSessionLocalIdentityStore(
        keychain: sourceStableStorage
      ).load() == nil
    )
    #expect(
      try SharedSessionLocalIdentityStore(
        keychain: targetStableStorage
      ).load() == nil
    )
    #expect(
      try SharedSessionLocalIdentityStore(
        keychain: unrecordedStableStorage
      ).load() == unrecordedIdentity
    )
    #expect(
      try storageByTarget[sourcePrevious]?.data(
        forKey: ClerkKeychainKey.cachedClient.rawValue
      ) == nil
    )
    #expect(
      try storageByTarget[targetPrevious]?.data(
        forKey: ClerkKeychainKey.cachedClient.rawValue
      ) == nil
    )
    #expect(
      try storageByTarget[unrecordedPrevious]?.data(
        forKey: ClerkKeychainKey.cachedClient.rawValue
      ) == unrecordedPreviousData
    )
    #expect(
      try storageByTarget[sourceIntent.configuredAppLocal]?.data(
        forKey: privateTopologyKey
      ) == nil
    )
    #expect(
      try storageByTarget[targetIntent.configuredAppLocal]?.data(
        forKey: privateTopologyKey
      ) == nil
    )
    #expect(
      try storageByTarget[unrecordedIntent.configuredAppLocal]?.data(
        forKey: privateTopologyKey
      ) == unrecordedPrivateData
    )
    #expect(
      try storageByTarget[sourceJournal]?.data(
        forKey: SharedSessionOwnerSlotClearRecovery.storageKey
      ) == nil
    )
    #expect(
      try storageByTarget[targetJournal]?.data(
        forKey: SharedSessionOwnerSlotClearRecovery.storageKey
      ) == nil
    )
    #expect(
      try storageByTarget[unrecordedJournal]?.data(
        forKey: SharedSessionOwnerSlotClearRecovery.storageKey
      ) == unrecordedJournalData
    )
    #expect(sourceSlotStore.deleteCount == 1)
    #expect(targetSlotStore.deleteCount == 1)
    #expect(unrecordedSlotStore.deleteCount == 0)
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
  func appContainerRecoveryPreservesWatchTombstoneAcrossAliasedTargetKinds()
    throws
  {
    let clerk = Clerk()
    let service = "com.example.watch-alias"
    let appLocalAccessGroup = "TEAMID.com.example.watch-alias-app"

    func makeIntent(
      ownerIdentifier: String,
      host: String,
      sharedAccessGroup: String,
      privateAccessGroup: String
    ) throws -> AppContainerIdentityClearIntent {
      let dependencies = MockDependencyContainer(
        apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
        sharedSessionOwnerIdentifier: ownerIdentifier,
        usesVolatileIdentityPersistence: true
      )
      let options = Clerk.Options(
        keychainConfig: .init(
          service: service,
          accessGroup: sharedAccessGroup,
          appLocalAccessGroup: privateAccessGroup
        )
      )
      let publishableKey = publishableKey(for: host)
      try dependencies.configurationManager.configure(
        publishableKey: publishableKey,
        options: options
      )
      return try Clerk.makeAppContainerIdentityClearIntent(
        dependencies: dependencies,
        options: options,
        frontendApiUrl: dependencies.configurationManager.frontendApiUrl,
        publishableKey: publishableKey
      )
    }

    let appLocalIntent = try makeIntent(
      ownerIdentifier: "com.example.watch-alias-app",
      host: "watch-alias-app.clerk.example.com",
      sharedAccessGroup: "TEAMID.com.example.watch-alias-shared",
      privateAccessGroup: appLocalAccessGroup
    )
    let configuredIntent = try makeIntent(
      ownerIdentifier: "com.example.watch-alias-configured",
      host: "watch-alias-configured.clerk.example.com",
      sharedAccessGroup: appLocalAccessGroup,
      privateAccessGroup:
      "TEAMID.com.example.watch-alias-configured"
    )
    let appLocalTarget = appLocalIntent.configuredAppLocal
    let configuredTarget = configuredIntent.configuredShared
    #expect(
      appLocalTarget.kind
        == AppContainerIdentityClearIntent.KeychainTarget.Kind
        .applicationLocal
    )
    #expect(
      configuredTarget.kind
        == AppContainerIdentityClearIntent.KeychainTarget.Kind
        .configured
    )
    #expect(appLocalTarget != configuredTarget)
    #expect(appLocalTarget.service == configuredTarget.service)
    #expect(appLocalTarget.accessGroup == configuredTarget.accessGroup)
    #expect(
      appLocalIntent.activeStorageMayOverlap(with: configuredIntent)
    )

    let envelope = try appLocalIntent.includingClearIntent(
      configuredIntent
    )
    let aliasedStorage = InMemoryKeychain()
    var storageByTarget: [
      AppContainerIdentityClearIntent.KeychainTarget: InMemoryKeychain
    ] = [:]
    for intent in envelope.recordedClearIntents {
      for target in intent.uniqueKeychainTargets
        where target != appLocalTarget && target != configuredTarget
      {
        if storageByTarget[target] == nil {
          storageByTarget[target] = InMemoryKeychain()
        }
      }
    }
    try WatchSyncMetadataStore(keychain: aliasedStorage).save(
      WatchSyncMetadataRecord(
        deviceTokenState: .set,
        deviceTokenVersion: 41,
        authState: .set,
        authVersion: 42
      )
    )

    try AppContainerIdentityClearRecovery(
      storageProvider: { target in
        if target == appLocalTarget || target == configuredTarget {
          return aliasedStorage
        }
        guard let storage = storageByTarget[target] else {
          throw IdentityPersistenceBootstrapTestError
            .unexpectedTargetLookup
        }
        return storage
      }
    ).recover(envelope)

    #expect(
      try aliasedStorage.data(
        forKey: ClerkKeychainKey.watchSyncMetadata.rawValue
      ) != nil
    )
    let metadata = try WatchSyncMetadataStore(
      keychain: aliasedStorage
    ).load()
    #expect(metadata.deviceTokenState == .cleared)
    #expect(metadata.authState == .cleared)
    #expect(metadata.deviceTokenVersion == metadata.authVersion)
    #expect(metadata.authVersion ?? 0 > 42)
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
        == .blocked(.pendingClear)
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
        == .blocked(.pendingClear)
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
    let identity = makeSignedInIdentity(
      serverDate: Date(timeIntervalSince1970: 100)
    )
    try identityStore.save(identity)
    clerk.hydrateIdentityIfNeeded(identity)
    let sessionID = try #require(clerk.session?.id)
    let userID = try #require(clerk.user?.id)
    let persistedIdentityBeforeClear = try identityStore.load()

    await #expect(throws: (any Error).self) {
      try await clerk.clearAllKeychainItemsAndWait()
    }

    #expect(clerk.client == identity.client)
    #expect(
      clerk.identityController.currentDeviceToken == identity.deviceToken
    )
    #expect(clerk.session?.id == sessionID)
    #expect(clerk.user?.id == userID)
    #expect(try identityStore.load() == persistedIdentityBeforeClear)
    #expect(clerk.persistenceStatus.readiness == .ready)
  }

  @Test
  func unreadableAppContainerClearRemainsFencedUntilForegroundRecovery()
    async throws
  {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let identity = makeSignedInIdentity(
      serverDate: Date(timeIntervalSince1970: 100)
    )
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
        keychainConfig: .init(service: "com.example.unreadable-clear")
      )
    )
    try clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }
    #expect(clerk.client?.id == identity.client?.id)
    #expect(clerk.session != nil)
    #expect(clerk.user != nil)

    let intent = try clerk.makeAppContainerIdentityClearIntent()
    let intentStore =
      RecoveringReadFailureAppContainerIdentityClearIntentStore(
        intent: intent,
        failingLoadCount: 2
      )
    clerk.appContainerIdentityClearIntentStore = intentStore
    clerk.appContainerIdentityClearRecovery =
      AppContainerIdentityClearRecovery(
        storageProvider: { _ in keychain }
      )

    await #expect(throws: (any Error).self) {
      try await clerk.clearAllKeychainItemsAndWait()
    }

    #expect(clerk.client == nil)
    #expect(clerk.session == nil)
    #expect(clerk.user == nil)
    #expect(
      clerk.persistenceStatus.readiness == .blocked(.pendingClear)
    )
    #expect(intentStore.loadCount == 1)
    #expect(intentStore.hasPendingIntent)

    let targetKeychain = InMemoryKeychain()
    let dependencyFactory: Clerk.ReconfigurationDependencyFactory = {
      publishableKey,
      options,
      runtimeScope in
      let target = MockDependencyContainer(
        apiClient: createMockAPIClient(runtimeScope: runtimeScope),
        keychain: targetKeychain,
        appLocalKeychain: targetKeychain,
        identityKeychain: targetKeychain,
        atomicIdentityStore: SharedSessionLocalIdentityStore(
          keychain: targetKeychain
        )
      )
      try target.configurationManager.configure(
        publishableKey: publishableKey,
        options: options
      )
      return target
    }
    await #expect(throws: (any Error).self) {
      try await clerk.performReconfiguration(
        publishableKey: testPublishableKey,
        options: .init(
          keychainConfig: .init(service: "com.example.blocked-target")
        ),
        dependencyFactory: dependencyFactory
      )
    }

    #expect(clerk.dependencies === dependencies)
    #expect(
      clerk.persistenceStatus.readiness == .blocked(.pendingClear)
    )
    #expect(intentStore.loadCount == 1)

    await clerk.onWillEnterForeground()

    #expect(
      clerk.persistenceStatus.readiness == .blocked(.pendingClear)
    )
    #expect(intentStore.loadCount == 2)
    #expect(intentStore.hasPendingIntent)
    #expect(clerk.client == nil)
    #expect(clerk.session == nil)
    #expect(clerk.user == nil)

    await clerk.onWillEnterForeground()

    #expect(clerk.persistenceStatus.readiness == .ready)
    #expect(intentStore.loadCount == 3)
    #expect(!intentStore.hasPendingIntent)
    #expect(clerk.client == nil)
    #expect(clerk.session == nil)
    #expect(clerk.user == nil)
    #expect(try identityStore.load() == nil)
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
  func pendingClearRecoveryRebootsBlockedSharedSessionRuntime()
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
      atomicIdentityStore: identityStore,
      sharedSessionOwnerIdentifier: "com.example.shared-clear"
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(
          service: "com.example.shared-bootstrap-clear"
        ),
        watchConnectivityEnabled: true,
        sharedSessionSync: .enabled
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

    #expect(clerk.sharedSessionSyncCoordinator == nil)
    #expect(
      clerk.persistenceStatus.sharedSession
        == .unavailable(.temporarilyUnavailable)
    )
    #expect(
      clerk.persistenceStatus.readiness == .blocked(.pendingClear)
    )
    #expect(try intentStore.load() == intent)

    await clerk.onWillEnterForeground()

    #expect(try intentStore.load() == nil)
    #expect(clerk.persistenceStatus.identityStorage == .durable)
    #expect(
      clerk.persistenceStatus.sharedSession == .unavailable(.unexpected)
    )
    #expect(clerk.persistenceStatus.readiness == .ready)
    #expect(clerk.sharedSessionSyncCoordinator == nil)
    #expect(clerk.isWatchConnectivityInstalled)
    #expect(clerk.client == nil)
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

  private func publishableKey(for host: String) -> String {
    let encoded = Data("\(host)$".utf8)
      .base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
    return "pk_test_\(encoded)"
  }

  private func makeSignedInIdentity(
    serverDate: Date?
  ) -> ClerkIdentitySnapshot {
    var client = Client.mock
    client.id = "signed-in-client"
    return ClerkIdentitySnapshot(
      state: .present,
      deviceToken: "signed-in-token",
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

@MainActor
private final class PersistenceBootstrapGate {
  private var didEnter = false
  private var entryWaiters: [CheckedContinuation<Void, Never>] = []
  private var releaseContinuation: CheckedContinuation<Void, Never>?

  func waitForRelease() async {
    didEnter = true
    let waiters = entryWaiters
    entryWaiters.removeAll()
    waiters.forEach { $0.resume() }
    await withCheckedContinuation { continuation in
      releaseContinuation = continuation
    }
  }

  func waitUntilEntered() async {
    guard !didEnter else { return }
    await withCheckedContinuation { continuation in
      entryWaiters.append(continuation)
    }
  }

  func release() {
    releaseContinuation?.resume()
    releaseContinuation = nil
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

private final class ReconfigurationPendingPublicationSlotStore:
  @unchecked Sendable,
  SharedSessionSlotStoring
{
  private let lock = NSLock()
  private let ownerIdentifier: String
  private var slotsByOwner: [String: SharedSessionOwnerSlot]

  init(
    ownerIdentifier: String,
    slots: [SharedSessionOwnerSlot]
  ) {
    self.ownerIdentifier = ownerIdentifier
    slotsByOwner = Dictionary(
      uniqueKeysWithValues: slots.map {
        ($0.slotOwnerIdentifier, $0)
      }
    )
  }

  func loadOwnSlot() throws -> SharedSessionOwnerSlot? {
    lock.withLock {
      slotsByOwner[ownerIdentifier]
    }
  }

  func loadAllSlots() throws -> [SharedSessionOwnerSlot] {
    lock.withLock {
      Array(slotsByOwner.values)
    }
  }

  func saveOwnSlot(_ slot: SharedSessionOwnerSlot) throws {
    lock.withLock {
      slotsByOwner[ownerIdentifier] = slot
    }
  }

  func deleteOwnSlot() throws {
    lock.withLock {
      slotsByOwner[ownerIdentifier] = nil
    }
  }
}

@MainActor
private final class ReconfigurationPendingPublicationNotifier:
  SharedSessionSyncNotifying
{
  func setHandler(_: @escaping @MainActor () -> Void) {}
  func post() {}
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

private final class FailAfterFirstDeleteKeychain:
  @unchecked Sendable,
  KeychainStorage
{
  private enum DeleteError: Error {
    case unavailable
  }

  private let lock = NSLock()
  private var storage: [String: Data] = [:]
  private var successfulDeleteCount = 0
  private var deletesAreAvailable = false

  func allowDeletes() {
    lock.withLock {
      deletesAreAvailable = true
    }
  }

  func set(_ data: Data, forKey key: String) throws {
    lock.withLock {
      storage[key] = data
    }
  }

  func data(forKey key: String) throws -> Data? {
    lock.withLock {
      storage[key]
    }
  }

  func deleteItem(forKey key: String) throws {
    try lock.withLock {
      guard deletesAreAvailable || successfulDeleteCount == 0 else {
        throw DeleteError.unavailable
      }
      successfulDeleteCount += 1
      storage[key] = nil
    }
  }

  func hasItem(forKey key: String) throws -> Bool {
    lock.withLock {
      storage[key] != nil
    }
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
private final class FailAfterPersistAppContainerIdentityClearIntentStore:
  AppContainerIdentityClearIntentStoring
{
  private let backing = InMemoryAppContainerIdentityClearIntentStore()

  func load() throws -> AppContainerIdentityClearIntent? {
    try backing.load()
  }

  func record(_ intent: AppContainerIdentityClearIntent) throws {
    try backing.record(intent)
    throw IdentityPersistenceBootstrapTestError.unexpectedMutation
  }

  func remove(matching transactionID: UUID) throws {
    try backing.remove(matching: transactionID)
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

@MainActor
private final class RecoveringReadFailureAppContainerIdentityClearIntentStore:
  AppContainerIdentityClearIntentStoring
{
  private(set) var intent: AppContainerIdentityClearIntent?
  private(set) var loadCount = 0
  private var remainingFailingLoads: Int

  init(
    intent: AppContainerIdentityClearIntent,
    failingLoadCount: Int
  ) {
    self.intent = intent
    remainingFailingLoads = failingLoadCount
  }

  var hasPendingIntent: Bool {
    intent != nil
  }

  func load() throws -> AppContainerIdentityClearIntent? {
    loadCount += 1
    if remainingFailingLoads > 0 {
      remainingFailingLoads -= 1
      throw KeychainError.unexpectedStatus(errSecNotAvailable)
    }
    return intent
  }

  func record(_ intent: AppContainerIdentityClearIntent) throws {
    let intent = try intent.validated()
    if let pending = self.intent {
      guard pending == intent else {
        throw AppContainerIdentityClearIntentError.pendingIntentConflict
      }
      return
    }
    self.intent = intent
  }

  func remove(matching transactionID: UUID) throws {
    guard let intent else { return }
    guard intent.transactionID == transactionID else {
      throw AppContainerIdentityClearIntentError.pendingIntentConflict
    }
    self.intent = nil
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
