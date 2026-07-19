//
//  ClerkIdentityControllerTests.swift
//  Clerk
//

@testable import ClerkKit
import Foundation
import Testing

@MainActor
struct ClerkIdentityControllerTests {
  private enum StageFailure: Error {
    case expected
  }

  @Test
  func externalTransitionUsesAtomicPersistenceBeforeApplyingMemory() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let store = SharedSessionLocalIdentityStore(keychain: keychain)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      atomicIdentityStore: store
    )
    let identity = ClerkIdentitySnapshot(
      state: .present,
      deviceToken: "atomic-token",
      client: .mock,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    var persistedIdentityObservedAfterApply: ClerkIdentitySnapshot?

    let task = try #require(try clerk.identityController.submitExternalTransition {
      ClerkIdentityController.ExternalTransition(
        identity: identity,
        didApply: {
          persistedIdentityObservedAfterApply = try? store.load()
        }
      )
    })
    try await task.value

    let persistedIdentity = try #require(try store.load())
    #expect(persistedIdentityObservedAfterApply == persistedIdentity)
    #expect(persistedIdentity.deviceToken == identity.deviceToken)
    #expect(persistedIdentity.client?.id == identity.client?.id)
    #expect(persistedIdentity.serverDate == identity.serverDate)
    #expect(clerk.identityController.currentDeviceToken == identity.deviceToken)
    #expect(clerk.client == identity.client)
    #expect(clerk.lastClientServerFetchDate == identity.serverDate)
  }

  @Test
  func externalTransitionUsesLegacyPersistenceThroughSameBoundary() throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain
    )
    let identity = ClerkIdentitySnapshot(
      state: .present,
      deviceToken: "legacy-token",
      client: .mock,
      serverDate: Date(timeIntervalSince1970: 200)
    )
    var didApply = false

    let task = try clerk.identityController.submitExternalTransition {
      ClerkIdentityController.ExternalTransition(
        identity: identity,
        didApply: { didApply = true }
      )
    }

    #expect(task == nil)
    #expect(didApply)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "legacy-token")
    #expect(clerk.client == identity.client)
    #expect(clerk.lastClientServerFetchDate == identity.serverDate)
  }

  @Test
  func failedExternalTransitionStageCannotExposeIdentity() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let store = SharedSessionLocalIdentityStore(keychain: keychain)
    let previous = ClerkIdentitySnapshot(
      state: .cleared,
      deviceToken: "previous-token",
      client: nil,
      serverDate: nil
    )
    try store.save(previous)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      atomicIdentityStore: store
    )
    clerk.hydrateIdentityIfNeeded(previous)
    let replacement = ClerkIdentitySnapshot(
      state: .present,
      deviceToken: "replacement-token",
      client: .mock,
      serverDate: Date(timeIntervalSince1970: 300)
    )

    let task = try #require(try clerk.identityController.submitExternalTransition {
      ClerkIdentityController.ExternalTransition(
        identity: replacement,
        stage: { throw StageFailure.expected }
      )
    })

    await #expect(throws: StageFailure.expected) {
      try await task.value
    }
    #expect(try store.load() == previous)
    #expect(clerk.identityController.currentDeviceToken == previous.deviceToken)
    #expect(clerk.client == nil)
  }

  @Test
  func legacyMemoryResponsePathCannotBypassAtomicPersistence() throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let store = SharedSessionLocalIdentityStore(keychain: keychain)
    let accepted = ClerkIdentitySnapshot(
      state: .present,
      deviceToken: "accepted-token",
      client: .mock,
      serverDate: Date(timeIntervalSince1970: 400)
    )
    try store.save(accepted)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      atomicIdentityStore: store
    )
    clerk.hydrateIdentityIfNeeded(accepted)
    var replacement = Client.mock
    replacement.id = "replacement-client"

    clerk.identityController.applyLegacyResponseClient(
      replacement,
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 500)
    )

    #expect(clerk.client?.id == accepted.client?.id)
    #expect(clerk.lastClientServerFetchDate == accepted.serverDate)
    #expect(try store.load()?.client?.id == accepted.client?.id)
  }

  @Test
  func atomicTokenOnlyResponseResolvesIdentityWhenItsSerializedTurnBegins() async throws {
    let clerk = Clerk()
    let store = ControllerSuspendingIdentityStore()
    var initialClient = Client.mock
    initialClient.id = "initial"
    let initialIdentity = ClerkIdentitySnapshot(
      state: .present,
      deviceToken: "token",
      client: initialClient,
      serverDate: Date(timeIntervalSince1970: 50)
    )
    try store.save(initialIdentity)
    let keychain = InMemoryKeychain()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      atomicIdentityStore: store
    )
    clerk.hydrateIdentityIfNeeded(initialIdentity)
    store.suspendNextSave()
    var newClient = Client.mock
    newClient.id = "new-client"

    let clientResponse = Task { @MainActor in
      try await clerk.identityController.applyNetworkResponse(
        ClientSyncResponseContext(
          update: .client(newClient),
          deviceTokenUpdate: .set("token"),
          requestDeviceToken: "token",
          baseGeneration: 0,
          serverDate: Date(timeIntervalSince1970: 100),
          isCanonicalClientRequest: true,
          clientResponseGeneration: clerk.clientResponseGeneration,
          responseSequence: 1
        )
      )
    }
    try await waitUntil { store.isSaveSuspended }

    let tokenOnlyResponse = Task { @MainActor in
      try await clerk.identityController.applyNetworkResponse(
        ClientSyncResponseContext(
          update: .absent,
          deviceTokenUpdate: .set("rotated-token"),
          requestDeviceToken: "token",
          baseGeneration: 0,
          serverDate: Date(timeIntervalSince1970: 200),
          isCanonicalClientRequest: false,
          clientResponseGeneration: clerk.clientResponseGeneration,
          responseSequence: 2
        )
      )
    }

    store.resumeSuspendedSave()
    try await clientResponse.value
    try await tokenOnlyResponse.value

    let persisted = try #require(try store.load())
    #expect(persisted.deviceToken == "rotated-token")
    #expect(persisted.client?.id == "new-client")
    #expect(clerk.client?.id == "new-client")
  }

  @Test
  func atomicResponseRetryAfterPersistenceFailureKeepsResponseSequenceUsable() async throws {
    let clerk = Clerk()
    var oldClient = Client.mock
    oldClient.id = "old-client"
    let previous = ClerkIdentitySnapshot(
      state: .present,
      deviceToken: "token",
      client: oldClient,
      serverDate: Date(timeIntervalSince1970: 50)
    )
    let store = ControllerFailingOnceIdentityStore(identity: previous)
    let keychain = InMemoryKeychain()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      atomicIdentityStore: store
    )
    clerk.hydrateIdentityIfNeeded(previous)
    store.failNextSave()
    let context = ClientSyncResponseContext(
      update: .client(makeClient(id: "new-client")),
      deviceTokenUpdate: .set("token"),
      requestDeviceToken: "token",
      baseGeneration: 0,
      serverDate: Date(timeIntervalSince1970: 100),
      isCanonicalClientRequest: true,
      clientResponseGeneration: clerk.clientResponseGeneration,
      responseSequence: 1
    )

    await #expect(throws: ControllerFailingOnceIdentityStore.Failure.self) {
      try await clerk.identityController.applyNetworkResponse(context)
    }
    #expect(clerk.client?.id == "old-client")

    try await clerk.identityController.applyNetworkResponse(context)

    #expect(clerk.client?.id == "new-client")
    #expect(try store.load()?.client?.id == "new-client")
  }

  @Test
  func canonicalLegacyClientWithoutAClerkTokenIsRejected() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain
    )

    await #expect(throws: ClientSyncResponseError.missingDeviceTokenForCanonicalClient) {
      try await clerk.identityController.applyNetworkResponse(
        ClientSyncResponseContext(
          update: .client(.mock),
          deviceTokenUpdate: .absent,
          requestDeviceToken: nil,
          baseGeneration: 0,
          serverDate: nil,
          isCanonicalClientRequest: true,
          clientResponseGeneration: clerk.clientResponseGeneration,
          responseSequence: 1
        )
      )
    }

    #expect(clerk.client == nil)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == nil)
  }

  @Test
  func manualReloadStillAppliesLegacyClientAndEnvironmentWithoutCoordinator() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    var persistedClient = Client.mock
    persistedClient.id = "persisted-client"
    persistedClient.updatedAt = Date(timeIntervalSince1970: 200)
    try keychain.set(
      JSONEncoder.clerkEncoder.encode(persistedClient),
      forKey: ClerkKeychainKey.cachedClient.rawValue
    )
    try keychain.set(
      "200",
      forKey: ClerkKeychainKey.cachedClientServerDate.rawValue
    )
    try keychain.set(
      JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock),
      forKey: ClerkKeychainKey.cachedEnvironment.rawValue
    )
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain
    )
    var currentClient = Client.mock
    currentClient.id = "current-client"
    currentClient.updatedAt = Date(timeIntervalSince1970: 100)
    clerk.client = currentClient

    let didChange = await clerk.reloadFromSharedStorage()

    #expect(didChange)
    #expect(clerk.client?.id == "persisted-client")
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 200))
    #expect(clerk.environment == .mock)
  }

  private func waitUntil(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(1)
    while ContinuousClock.now < deadline {
      if condition() { return }
      await Task.yield()
    }
    throw ClerkClientError(message: "Timed out waiting for suspended identity persistence.")
  }

  private func makeClient(id: String) -> Client {
    var client = Client.mock
    client.id = id
    return client
  }
}

private final class ControllerSuspendingIdentityStore: @unchecked Sendable,
  SharedSessionLocalIdentityStoring
{
  private let stateLock = NSLock()
  private let suspension = NSCondition()
  private var record: SharedSessionLocalIdentityRecord?
  private var shouldSuspendNextSave = false
  private var shouldResumeSave = false
  private var saveIsSuspended = false

  var isSaveSuspended: Bool {
    suspension.withLock { saveIsSuspended }
  }

  func suspendNextSave() {
    suspension.withLock {
      shouldSuspendNextSave = true
      shouldResumeSave = false
    }
  }

  func resumeSuspendedSave() {
    suspension.withLock {
      shouldResumeSave = true
      suspension.broadcast()
    }
  }

  func loadRecord() throws -> SharedSessionLocalIdentityRecord? {
    stateLock.withLock { record }
  }

  func updateRecord(
    _ update: (SharedSessionLocalIdentityRecord?) throws -> SharedSessionLocalIdentityRecord?
  ) throws {
    let current = stateLock.withLock { record }
    let updated = try update(current)

    suspension.lock()
    let shouldSuspend = shouldSuspendNextSave && updated != nil
    if shouldSuspend {
      shouldSuspendNextSave = false
      saveIsSuspended = true
      suspension.broadcast()
      while !shouldResumeSave {
        suspension.wait()
      }
      saveIsSuspended = false
    }
    suspension.unlock()

    stateLock.withLock { record = updated }
  }
}

private final class ControllerFailingOnceIdentityStore: @unchecked Sendable,
  SharedSessionLocalIdentityStoring
{
  enum Failure: Error {
    case save
  }

  private let lock = NSLock()
  private var record: SharedSessionLocalIdentityRecord?
  private var shouldFailNextSave = false

  init(identity: SharedSessionLocalIdentity) {
    record = SharedSessionLocalIdentityRecord(
      acceptedIdentity: identity,
      pendingPublication: nil
    )
  }

  func failNextSave() {
    lock.withLock { shouldFailNextSave = true }
  }

  func loadRecord() throws -> SharedSessionLocalIdentityRecord? {
    lock.withLock { record }
  }

  func updateRecord(
    _ update: (SharedSessionLocalIdentityRecord?) throws -> SharedSessionLocalIdentityRecord?
  ) throws {
    try lock.withLock {
      let updated = try update(record)
      if shouldFailNextSave {
        shouldFailNextSave = false
        throw Failure.save
      }
      record = updated
    }
  }
}
