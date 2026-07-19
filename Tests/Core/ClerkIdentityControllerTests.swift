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
  func rejectedAtomicExternalTransitionDiscardsItsStagedIntent() async throws {
    let clerk = Clerk()
    let store = ControllerSuspendingIdentityStore()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: InMemoryKeychain(),
      atomicIdentityStore: store
    )
    let identity = ClerkIdentitySnapshot(
      state: .present,
      deviceToken: "replacement-token",
      client: .mock,
      serverDate: Date(timeIntervalSince1970: 350)
    )
    var didStage = false
    var didApply = false
    var didNotApply = false

    let task = try #require(try clerk.identityController.submitExternalTransition {
      ClerkIdentityController.ExternalTransition(
        identity: identity,
        stage: {
          didStage = true
          clerk.identityController.invalidateLocalOperations()
        },
        didApply: { didApply = true },
        didNotApply: { didNotApply = true }
      )
    })
    try await task.value

    #expect(didStage)
    #expect(!didApply)
    #expect(didNotApply)
    #expect(try store.load() == nil)
    #expect(clerk.client == nil)
  }

  @Test
  func failedAtomicExternalTransitionKeepsItsStagedIntentForRetry() async throws {
    let clerk = Clerk()
    let store = ControllerSuspendingIdentityStore()
    store.failNextSave()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: InMemoryKeychain(),
      atomicIdentityStore: store
    )
    let identity = ClerkIdentitySnapshot(
      state: .present,
      deviceToken: "replacement-token",
      client: .mock,
      serverDate: Date(timeIntervalSince1970: 375)
    )
    var didStage = false
    var didApply = false
    var didNotApply = false

    let task = try #require(try clerk.identityController.submitExternalTransition {
      ClerkIdentityController.ExternalTransition(
        identity: identity,
        stage: { didStage = true },
        didApply: { didApply = true },
        didNotApply: { didNotApply = true }
      )
    })

    await #expect(throws: ControllerSuspendingIdentityStore.Failure.self) {
      try await task.value
    }
    #expect(didStage)
    #expect(!didApply)
    #expect(!didNotApply)
    #expect(try store.load() == nil)
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
  func failedAtomicResponseSaveDoesNotConsumeItsResponseSequence() async throws {
    let clerk = Clerk()
    let store = ControllerSuspendingIdentityStore()
    let initialIdentity = ClerkIdentitySnapshot(
      state: .present,
      deviceToken: "token",
      client: .mock,
      serverDate: nil
    )
    try store.save(initialIdentity)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: InMemoryKeychain(),
      atomicIdentityStore: store
    )
    clerk.hydrateIdentityIfNeeded(initialIdentity)
    var replacement = Client.mock
    replacement.id = "replacement"
    let context = ClientSyncResponseContext(
      update: .client(replacement),
      deviceTokenUpdate: .absent,
      requestDeviceToken: "token",
      baseGeneration: 0,
      serverDate: nil,
      isCanonicalClientRequest: true,
      clientResponseGeneration: clerk.clientResponseGeneration,
      responseSequence: 1
    )
    store.failNextSave()

    await #expect(throws: ControllerSuspendingIdentityStore.Failure.self) {
      try await clerk.identityController.applyNetworkResponse(context)
    }

    try await clerk.identityController.applyNetworkResponse(context)

    #expect(clerk.client?.id == "replacement")
    #expect(try store.load()?.client?.id == "replacement")
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
  func legacyTokenRotationFencesResponsesPreparedWithThePreviousToken() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("old-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain
    )
    var initialClient = Client.mock
    initialClient.id = "initial-client"
    clerk.client = initialClient
    let previousGeneration = clerk.clientResponseGeneration
    var rotatedClient = Client.mock
    rotatedClient.id = "rotated-client"

    try await clerk.identityController.applyNetworkResponse(
      ClientSyncResponseContext(
        update: .client(rotatedClient),
        deviceTokenUpdate: .set("new-token"),
        requestDeviceToken: "old-token",
        baseGeneration: 0,
        serverDate: nil,
        isCanonicalClientRequest: true,
        clientResponseGeneration: previousGeneration,
        responseSequence: 1
      )
    )

    #expect(clerk.clientResponseGeneration != previousGeneration)
    #expect(clerk.client?.id == "rotated-client")
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "new-token")

    var staleClient = Client.mock
    staleClient.id = "stale-client"
    try await clerk.identityController.applyNetworkResponse(
      ClientSyncResponseContext(
        update: .client(staleClient),
        deviceTokenUpdate: .absent,
        requestDeviceToken: "old-token",
        baseGeneration: 0,
        serverDate: nil,
        isCanonicalClientRequest: true,
        clientResponseGeneration: previousGeneration,
        responseSequence: 2
      )
    )

    #expect(clerk.client?.id == "rotated-client")
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "new-token")
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
}

private final class ControllerSuspendingIdentityStore: @unchecked Sendable,
  SharedSessionLocalIdentityStoring
{
  enum Failure: Error {
    case save
  }

  private let stateLock = NSLock()
  private let suspension = NSCondition()
  private var record: SharedSessionLocalIdentityRecord?
  private var shouldSuspendNextSave = false
  private var shouldResumeSave = false
  private var saveIsSuspended = false
  private var shouldFailNextSave = false

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

  func failNextSave() {
    stateLock.withLock {
      shouldFailNextSave = true
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

    try stateLock.withLock {
      if shouldFailNextSave {
        shouldFailNextSave = false
        throw Failure.save
      }
      record = updated
    }
  }
}
