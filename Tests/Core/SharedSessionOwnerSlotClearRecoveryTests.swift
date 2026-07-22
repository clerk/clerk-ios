@testable import ClerkKit
import Foundation
import Testing

@Suite(.serialized)
struct SharedSessionOwnerSlotClearRecoveryTests {
  @Test
  @MainActor
  func synchronousClearPersistsExactRecoveryIntentBeforeReturning() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let journal = InMemoryKeychain()
    let localStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let slotStore = try RecoveryOwnerSlotStore(slot: makeSlot())
    let intent = makeIntent()
    let recovery = makeContext(
      journal: journal,
      currentIntent: intent,
      identityStore: localStore,
      slotStore: slotStore
    )
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      identityKeychain: keychain,
      atomicIdentityStore: localStore,
      sharedSessionOwnerSlotClearRecovery: recovery,
      clientService: MockClientService(get: { nil })
    )
    clerk.sharedSessionSyncCoordinator = SharedSessionSyncCoordinator(
      ownerIdentifier: "app.owner",
      instanceFingerprint: "instance",
      slotStore: slotStore,
      localIdentityStore: localStore,
      notifier: RecoverySharedSessionNotifier(),
      configurationEpoch: clerk.configurationEpoch,
      clerk: clerk
    )

    let clearTask = Clerk.startKeychainClearIfNeeded(for: clerk)

    #expect(
      try SharedSessionOwnerSlotClearRecovery.loadPendingIntent(in: journal)
        == intent
    )

    try await clearTask.value
    #expect(try slotStore.loadOwnSlot() == nil)
    #expect(try SharedSessionOwnerSlotClearRecovery.loadPendingIntent(in: journal) == nil)
  }

  @Test
  @MainActor
  func journalFailureLeavesIdentityAndOwnerSlotUntouched() async throws {
    let clerk = Clerk()
    let identityKeychain = InMemoryKeychain()
    let journal = SetFailingKeychain()
    let localStore = SharedSessionLocalIdentityStore(keychain: identityKeychain)
    let slot = try makeSlot()
    let slotStore = RecoveryOwnerSlotStore(slot: slot)
    let recovery = makeContext(
      journal: journal,
      currentIntent: makeIntent(),
      identityStore: localStore,
      slotStore: slotStore
    )
    let dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: identityKeychain,
      identityKeychain: identityKeychain,
      atomicIdentityStore: localStore,
      sharedSessionOwnerSlotClearRecovery: recovery,
      clientService: MockClientService(get: { nil })
    )
    clerk.dependencies = dependencies
    let identity = makeIdentity(token: "accepted-token")
    try localStore.save(identity)
    let recordBeforeClear = try localStore.loadRecord()
    clerk.hydrateIdentityIfNeeded(identity)
    let coordinator = SharedSessionSyncCoordinator(
      ownerIdentifier: "app.owner",
      instanceFingerprint: "instance",
      slotStore: slotStore,
      localIdentityStore: localStore,
      localIdentityIO: dependencies.atomicIdentityIO,
      notifier: RecoverySharedSessionNotifier(),
      configurationEpoch: clerk.configurationEpoch,
      clerk: clerk
    )
    clerk.sharedSessionSyncCoordinator = coordinator

    do {
      try await clerk.clearAllKeychainItemsAndWait()
      Issue.record("Expected recovery journal persistence to fail.")
    } catch {
      #expect(
        error.localizedDescription.contains(
          "persist owner-slot withdrawal intent"
        )
      )
    }

    #expect(clerk.client?.id == identity.client?.id)
    #expect(clerk.identityController.currentDeviceToken == "accepted-token")
    #expect(try localStore.loadRecord() == recordBeforeClear)
    #expect(try slotStore.loadOwnSlot() == slot)
    #expect(clerk.keychainClearTask == nil)
    #expect(try await coordinator.captureRequestIdentity().deviceToken == "accepted-token")
  }

  @Test
  @MainActor
  func recoveryClearsAcceptedAndPendingIdentityBeforeCoordinatorStartup() async throws {
    let journal = InMemoryKeychain()
    let localStore = SharedSessionLocalIdentityStore(keychain: InMemoryKeychain())
    let slotStore = try RecoveryOwnerSlotStore(slot: makeSlot())
    let intent = makeIntent()
    let context = makeContext(
      journal: journal,
      currentIntent: intent,
      identityStore: localStore,
      slotStore: slotStore
    )
    try localStore.save(makeIdentity(token: "accepted-token"))
    try localStore.stagePendingPublication(makeEvent(
      token: "pending-token",
      generation: 2
    ))
    try SharedSessionOwnerSlotClearRecovery.markPending(in: context)

    #expect(try SharedSessionOwnerSlotClearRecovery.recoverIfNeeded(in: context))

    #expect(try localStore.loadRecord() == nil)
    #expect(try slotStore.loadOwnSlot() == nil)
    #expect(try SharedSessionOwnerSlotClearRecovery.loadPendingIntent(in: journal) == nil)

    let clerk = Clerk()
    let dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      atomicIdentityStore: localStore,
      clientService: MockClientService(get: { nil })
    )
    clerk.dependencies = dependencies
    let coordinator = SharedSessionSyncCoordinator(
      ownerIdentifier: "app.owner",
      instanceFingerprint: "instance",
      slotStore: slotStore,
      localIdentityStore: localStore,
      localIdentityIO: dependencies.atomicIdentityIO,
      notifier: RecoverySharedSessionNotifier(),
      configurationEpoch: clerk.configurationEpoch,
      clerk: clerk
    )
    clerk.sharedSessionSyncCoordinator = coordinator

    _ = await coordinator.start().value

    #expect(try slotStore.loadOwnSlot() == nil)
    #expect(try localStore.loadRecord() == nil)
  }

  @Test
  func recoveryUsesRecordedTopologyInsteadOfCurrentConfiguration() throws {
    let journal = InMemoryKeychain()
    let originalIdentityStore = SharedSessionLocalIdentityStore(keychain: InMemoryKeychain())
    let currentIdentityStore = SharedSessionLocalIdentityStore(keychain: InMemoryKeychain())
    let originalSlotStore = try RecoveryOwnerSlotStore(slot: makeSlot())
    let currentSlotStore = try RecoveryOwnerSlotStore(slot: makeSlot(token: "current-token"))
    let originalIntent = makeIntent(suffix: "original")
    let currentIntent = makeIntent(suffix: "current")
    try originalIdentityStore.save(makeIdentity(token: "original-token"))
    try currentIdentityStore.save(makeIdentity(token: "current-token"))
    let provider = RecoveryTargetProvider(
      originalIntent: originalIntent,
      originalIdentityStore: originalIdentityStore,
      originalSlotStore: originalSlotStore,
      otherIdentityStore: currentIdentityStore,
      otherSlotStore: currentSlotStore
    )
    try SharedSessionOwnerSlotClearRecovery.markPending(in: .init(
      journal: journal,
      currentIntent: originalIntent,
      targetProvider: provider
    ))
    let currentContext = SharedSessionOwnerSlotClearRecovery.Context(
      journal: journal,
      currentIntent: currentIntent,
      targetProvider: provider
    )

    #expect(try SharedSessionOwnerSlotClearRecovery.recoverIfNeeded(in: currentContext))

    #expect(try originalIdentityStore.loadRecord() == nil)
    #expect(try originalSlotStore.loadOwnSlot() == nil)
    #expect(try currentIdentityStore.load() != nil)
    #expect(try currentSlotStore.loadOwnSlot() != nil)
  }

  @Test
  @MainActor
  func disabledSyncRecoversBeforeCacheHydration() throws {
    let clerk = Clerk()
    let journal = InMemoryKeychain()
    let localStore = SharedSessionLocalIdentityStore(keychain: InMemoryKeychain())
    let slotStore = try RecoveryOwnerSlotStore(slot: makeSlot())
    let intent = makeIntent()
    let provider = RecoveryTargetProvider(
      originalIntent: intent,
      originalIdentityStore: localStore,
      originalSlotStore: slotStore
    )
    try localStore.save(makeIdentity(token: "accepted-token"))
    try SharedSessionOwnerSlotClearRecovery.markPending(in: .init(
      journal: journal,
      currentIntent: intent,
      targetProvider: provider
    ))
    let disabledContext = SharedSessionOwnerSlotClearRecovery.Context(
      journal: journal,
      currentIntent: nil,
      targetProvider: provider
    )
    let dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      atomicIdentityStore: localStore,
      sharedSessionOwnerSlotClearRecovery: disabledContext,
      clientService: MockClientService(get: { nil })
    )

    try clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }

    #expect(clerk.identityController.currentDeviceToken == nil)
    #expect(clerk.client == nil)
    #expect(try localStore.loadRecord() == nil)
    #expect(try slotStore.loadOwnSlot() == nil)
    #expect(try SharedSessionOwnerSlotClearRecovery.loadPendingIntent(in: journal) == nil)
  }

  @Test
  func failedLocalIdentityDeletionKeepsSlotAndIntent() throws {
    let journal = InMemoryKeychain()
    let localStore = DeleteFailingRecoveryIdentityStore()
    let slotStore = try RecoveryOwnerSlotStore(slot: makeSlot())
    let intent = makeIntent()
    let context = makeContext(
      journal: journal,
      currentIntent: intent,
      identityStore: localStore,
      slotStore: slotStore
    )
    try SharedSessionOwnerSlotClearRecovery.markPending(in: context)

    #expect(throws: DeleteFailingRecoveryIdentityStore.Failure.delete) {
      try SharedSessionOwnerSlotClearRecovery.recoverIfNeeded(in: context)
    }

    #expect(try slotStore.loadOwnSlot() != nil)
    #expect(try SharedSessionOwnerSlotClearRecovery.loadPendingIntent(in: journal) == intent)
  }

  @Test
  @MainActor
  func failedRecoveryPreventsCacheHydrationAndRuntimeInstallation() throws {
    let clerk = Clerk()
    let initialKeychain = InMemoryKeychain()
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: initialKeychain,
      identityKeychain: initialKeychain,
      clientService: MockClientService(get: { nil })
    )
    let journal = InMemoryKeychain()
    let cachedIdentityStore = SharedSessionLocalIdentityStore(keychain: InMemoryKeychain())
    let failingRecoveryStore = DeleteFailingRecoveryIdentityStore()
    let slotStore = try RecoveryOwnerSlotStore(slot: makeSlot())
    let intent = makeIntent()
    let context = makeContext(
      journal: journal,
      currentIntent: intent,
      identityStore: failingRecoveryStore,
      slotStore: slotStore
    )
    try cachedIdentityStore.save(makeIdentity(token: "must-not-hydrate"))
    try SharedSessionOwnerSlotClearRecovery.markPending(in: context)
    let dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      atomicIdentityStore: cachedIdentityStore,
      sharedSessionOwnerSlotClearRecovery: context,
      clientService: MockClientService(get: { nil })
    )

    #expect(throws: DeleteFailingRecoveryIdentityStore.Failure.delete) {
      try clerk.performConfiguration(dependencies: dependencies)
    }

    #expect(clerk.client == nil)
    #expect(clerk.identityController.currentDeviceToken == nil)
    #expect(clerk.dependencies !== dependencies)
    #expect(try cachedIdentityStore.load() != nil)
    #expect(try SharedSessionOwnerSlotClearRecovery.loadPendingIntent(in: journal) == intent)
  }

  @Test
  func failedSlotWithdrawalLeavesClearedIdentityAndIntentForRetry() throws {
    let journal = InMemoryKeychain()
    let localStore = SharedSessionLocalIdentityStore(keychain: InMemoryKeychain())
    let slotStore = try RecoveryOwnerSlotStore(slot: makeSlot(), deleteFails: true)
    let intent = makeIntent()
    let context = makeContext(
      journal: journal,
      currentIntent: intent,
      identityStore: localStore,
      slotStore: slotStore
    )
    try localStore.save(makeIdentity(token: "accepted-token"))
    try SharedSessionOwnerSlotClearRecovery.markPending(in: context)

    #expect(throws: RecoveryOwnerSlotStore.Failure.delete) {
      try SharedSessionOwnerSlotClearRecovery.recoverIfNeeded(in: context)
    }

    #expect(try localStore.loadRecord() == nil)
    #expect(try slotStore.loadOwnSlot() != nil)
    #expect(try SharedSessionOwnerSlotClearRecovery.loadPendingIntent(in: journal) == intent)
  }

  @Test
  func futureSchemaSlotKeepsRecoveryIntentPending() throws {
    let journal = InMemoryKeychain()
    let localStore = SharedSessionLocalIdentityStore(keychain: InMemoryKeychain())
    let slotStore = try RecoveryOwnerSlotStore(
      slot: makeSlot(),
      futureSchemaVersion: 3
    )
    let intent = makeIntent()
    let context = makeContext(
      journal: journal,
      currentIntent: intent,
      identityStore: localStore,
      slotStore: slotStore
    )
    try localStore.save(makeIdentity(token: "accepted-token"))
    try SharedSessionOwnerSlotClearRecovery.markPending(in: context)

    #expect(throws: SharedSessionOwnerSlotStoreError.futureSchemaVersion(3)) {
      try SharedSessionOwnerSlotClearRecovery.recoverIfNeeded(in: context)
    }

    #expect(try localStore.loadRecord() == nil)
    #expect(try slotStore.loadOwnSlot() != nil)
    #expect(try SharedSessionOwnerSlotClearRecovery.loadPendingIntent(in: journal) == intent)
  }

  private func makeContext(
    journal: any KeychainStorage,
    currentIntent: SharedSessionOwnerSlotClearRecovery.Intent?,
    identityStore: any SharedSessionLocalIdentityStoring,
    slotStore: any SharedSessionSlotStoring
  ) -> SharedSessionOwnerSlotClearRecovery.Context {
    let intent = currentIntent ?? makeIntent()
    return SharedSessionOwnerSlotClearRecovery.Context(
      journal: journal,
      currentIntent: currentIntent,
      targetProvider: RecoveryTargetProvider(
        originalIntent: intent,
        originalIdentityStore: identityStore,
        originalSlotStore: slotStore
      )
    )
  }

  private func makeIntent(
    suffix: String = "original"
  ) -> SharedSessionOwnerSlotClearRecovery.Intent {
    SharedSessionOwnerSlotClearRecovery.Intent(
      localIdentityService: "app.identity.\(suffix)",
      slotService: "app.slots.\(suffix)",
      slotAccessGroup: "group.\(suffix)",
      slotAccount: "owner.\(suffix)",
      instanceFingerprint: "instance-\(suffix)",
      ownerIdentifier: "app.owner"
    )
  }

  private func makeIdentity(token: String) -> ClerkIdentitySnapshot {
    ClerkIdentitySnapshot(
      state: .present,
      deviceToken: token,
      client: .mock,
      serverDate: Date(timeIntervalSince1970: 100)
    )
  }

  private func makeEvent(
    token: String,
    generation: UInt64
  ) throws -> SharedSessionIdentityEvent {
    try SharedSessionIdentityEvent(
      id: UUID(),
      originOwnerIdentifier: "app.owner",
      generation: generation,
      state: .present,
      deviceToken: token,
      client: .mock,
      serverDate: Date(timeIntervalSince1970: 100)
    ).validated()
  }

  private func makeSlot(token: String = "token") throws -> SharedSessionOwnerSlot {
    try SharedSessionOwnerSlot(
      schemaVersion: SharedSessionOwnerSlot.schemaVersion,
      instanceFingerprint: "instance",
      slotOwnerIdentifier: "app.owner",
      event: makeEvent(token: token, generation: 1)
    )
  }
}

@MainActor
private final class RecoverySharedSessionNotifier: SharedSessionSyncNotifying {
  func setHandler(_: @escaping @MainActor () -> Void) {}
  func post() {}
}

private final class RecoveryTargetProvider:
  SharedSessionClearRecoveryTargets,
  @unchecked Sendable
{
  enum Failure: Error {
    case unexpectedIntent
  }

  private let originalIntent: SharedSessionOwnerSlotClearRecovery.Intent
  private let originalIdentityStore: any SharedSessionLocalIdentityStoring
  private let originalSlotStore: any SharedSessionSlotStoring
  private let otherIdentityStore: (any SharedSessionLocalIdentityStoring)?
  private let otherSlotStore: (any SharedSessionSlotStoring)?

  init(
    originalIntent: SharedSessionOwnerSlotClearRecovery.Intent,
    originalIdentityStore: any SharedSessionLocalIdentityStoring,
    originalSlotStore: any SharedSessionSlotStoring,
    otherIdentityStore: (any SharedSessionLocalIdentityStoring)? = nil,
    otherSlotStore: (any SharedSessionSlotStoring)? = nil
  ) {
    self.originalIntent = originalIntent
    self.originalIdentityStore = originalIdentityStore
    self.originalSlotStore = originalSlotStore
    self.otherIdentityStore = otherIdentityStore
    self.otherSlotStore = otherSlotStore
  }

  func localIdentityStore(
    for intent: SharedSessionOwnerSlotClearRecovery.Intent
  ) throws -> any SharedSessionLocalIdentityStoring {
    if intent == originalIntent { return originalIdentityStore }
    guard let otherIdentityStore else { throw Failure.unexpectedIntent }
    return otherIdentityStore
  }

  func slotStore(
    for intent: SharedSessionOwnerSlotClearRecovery.Intent
  ) throws -> any SharedSessionSlotStoring {
    if intent == originalIntent { return originalSlotStore }
    guard let otherSlotStore else { throw Failure.unexpectedIntent }
    return otherSlotStore
  }
}

private final class RecoveryOwnerSlotStore: SharedSessionSlotStoring, @unchecked Sendable {
  enum Failure: Error {
    case delete
  }

  private let lock = NSLock()
  private var slot: SharedSessionOwnerSlot?
  private let deleteFails: Bool
  private let futureSchemaVersion: Int?

  init(
    slot: SharedSessionOwnerSlot?,
    deleteFails: Bool = false,
    futureSchemaVersion: Int? = nil
  ) {
    self.slot = slot
    self.deleteFails = deleteFails
    self.futureSchemaVersion = futureSchemaVersion
  }

  func loadOwnSlot() throws -> SharedSessionOwnerSlot? {
    lock.withLock { slot }
  }

  func loadAllSlots() throws -> [SharedSessionOwnerSlot] {
    lock.withLock { slot.map { [$0] } ?? [] }
  }

  func saveOwnSlot(_ slot: SharedSessionOwnerSlot) throws {
    lock.withLock { self.slot = slot }
  }

  func deleteOwnSlot() throws {
    try lock.withLock {
      if let futureSchemaVersion {
        throw SharedSessionOwnerSlotStoreError.futureSchemaVersion(
          futureSchemaVersion
        )
      }
      if deleteFails { throw Failure.delete }
      slot = nil
    }
  }
}

private final class DeleteFailingRecoveryIdentityStore:
  SharedSessionLocalIdentityStoring,
  @unchecked Sendable
{
  enum Failure: Error {
    case delete
  }

  func loadRecord() throws -> SharedSessionLocalIdentityRecord? {
    nil
  }

  func updateRecord(
    _ update: (SharedSessionLocalIdentityRecord?) throws -> SharedSessionLocalIdentityRecord?
  ) throws {
    guard try update(nil) != nil else { throw Failure.delete }
  }

  func invalidateOperations(through _: UInt64) throws {}

  func save(
    _: SharedSessionLocalIdentity,
    operationRevision _: UInt64
  ) throws -> Bool {
    true
  }

  func delete(operationRevision _: UInt64) throws -> Bool {
    throw Failure.delete
  }

  func deleteInvalidatingOperations(through _: UInt64) throws {
    throw Failure.delete
  }
}
