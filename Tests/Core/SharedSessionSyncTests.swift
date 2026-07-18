@_spi(FrameworkIntegration) @testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct SharedSessionSyncTests {
  @Test
  func threeIndependentOwnerSlotsConvergeOnOneExactEvent() async throws {
    let backend = TestSlotBackend()
    let first = try makeNode(owner: "app.a", backend: backend)
    let second = try makeNode(owner: "app.b", backend: backend)
    let third = try makeNode(owner: "app.c", backend: backend)
    let client = makeClient(id: "client-a")

    try await first.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "token-a",
      client: client,
      serverDate: nil
    )
    _ = await second.clerk.reloadFromSharedStorage()
    _ = await third.clerk.reloadFromSharedStorage()

    let slots = backend.allSlots()
    let eventIDs = Set(slots.map(\.event.id))
    #expect(slots.count == 3)
    #expect(eventIDs.count == 1)
    #expect(first.clerk.client?.id == client.id)
    #expect(second.clerk.client?.id == client.id)
    #expect(third.clerk.client?.id == client.id)
    #expect(try second.localStore.load()?.deviceToken == "token-a")
    #expect(try third.localStore.load()?.deviceToken == "token-a")
  }

  @Test
  func competingWritesRemainDiscoverableUntilConvergence() async throws {
    let backend = TestSlotBackend()
    let first = try makeNode(owner: "app.a", backend: backend)
    let second = try makeNode(owner: "app.b", backend: backend)
    let firstBase = first.coordinator.currentMaximumGeneration
    let secondBase = second.coordinator.currentMaximumGeneration

    try await first.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "token-a",
      client: makeClient(id: "client-a"),
      serverDate: nil,
      baseGeneration: firstBase
    )
    try await second.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "token-b",
      client: makeClient(id: "client-b"),
      serverDate: nil,
      baseGeneration: secondBase
    )

    let competingSlots = backend.allSlots()
    #expect(competingSlots.count == 2)
    #expect(Set(competingSlots.map(\.event.id)).count == 2)
    #expect(competingSlots.allSatisfy { $0.event.generation == 1 })

    _ = await first.clerk.reloadFromSharedStorage()

    let convergedSlots = backend.allSlots()
    #expect(Set(convergedSlots.map(\.event.id)).count == 1)
    #expect(first.clerk.client?.id == second.clerk.client?.id)
  }

  @Test
  func delayedResponseUsesGenerationCapturedBeforePeerPublication() async throws {
    let backend = TestSlotBackend()
    let delayed = try makeNode(owner: "app.a", backend: backend)
    let peer = try makeNode(owner: "app.z", backend: backend)
    let capturedGeneration = delayed.coordinator.currentMaximumGeneration

    try await peer.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "peer-token",
      client: makeClient(id: "peer"),
      serverDate: nil
    )
    _ = await delayed.clerk.reloadFromSharedStorage()
    try await delayed.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "delayed-token",
      client: makeClient(id: "delayed"),
      serverDate: nil,
      baseGeneration: capturedGeneration
    )

    let delayedEvent = try #require(
      backend.allSlots().first { $0.slotOwnerIdentifier == "app.a" }?.event
    )
    #expect(delayedEvent.generation == 1)
    #expect(delayed.coordinator.currentMaximumGeneration == 1)
  }

  @Test
  func responsePreparedBeforeAcceptedPeerFrontierIsRejected() async throws {
    let backend = TestSlotBackend()
    let node = try makeNode(owner: "app.a", backend: backend)
    let peer = try makeNode(owner: "app.z", backend: backend)
    try await node.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "token",
      client: makeClient(id: "generation-5"),
      serverDate: nil,
      baseGeneration: 4
    )
    _ = await peer.clerk.reloadFromSharedStorage()
    try await peer.coordinator.publishLocalIdentity(
      state: .cleared,
      deviceToken: "token",
      client: nil,
      serverDate: Date(timeIntervalSince1970: 200),
      baseGeneration: 5
    )
    _ = await node.clerk.reloadFromSharedStorage()
    let notificationCount = node.notifier.postCount

    try await node.coordinator.handleNetworkResponse(
      ClientSyncResponseContext(
        update: .client(makeClient(id: "stale-response")),
        deviceTokenUpdate: .set("token"),
        requestDeviceToken: "token",
        baseGeneration: 5,
        serverDate: Date(timeIntervalSince1970: 300),
        isCanonicalClientRequest: true,
        clientResponseGeneration: node.clerk.clientResponseGeneration,
        responseSequence: 1
      )
    )

    #expect(node.clerk.client == nil)
    #expect(node.notifier.postCount == notificationCount)
    #expect(backend.allSlots().allSatisfy { $0.event.originOwnerIdentifier == "app.z" })

    try await node.coordinator.handleNetworkResponse(
      ClientSyncResponseContext(
        update: .client(makeClient(id: "fresh-response")),
        deviceTokenUpdate: .set("token"),
        requestDeviceToken: "token",
        baseGeneration: 6,
        serverDate: Date(timeIntervalSince1970: 301),
        isCanonicalClientRequest: true,
        clientResponseGeneration: node.clerk.clientResponseGeneration,
        responseSequence: 2
      )
    )

    let event = try #require(
      backend.allSlots().first { $0.slotOwnerIdentifier == "app.a" }?.event
    )
    #expect(event.generation == 7)
    #expect(event.client?.id == "fresh-response")
  }

  @Test
  func responsePreparedBeforeSameOwnerWatchUpdateIsRejected() async throws {
    let backend = TestSlotBackend()
    let node = try makeNode(owner: "app.a", backend: backend)
    try await node.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "token",
      client: makeClient(id: "generation-5"),
      serverDate: nil,
      baseGeneration: 4
    )

    try await node.coordinator.publishLocalIdentity(
      state: .cleared,
      deviceToken: "token",
      client: nil,
      serverDate: Date(timeIntervalSince1970: 200)
    )
    let notificationCount = node.notifier.postCount

    try await node.coordinator.handleNetworkResponse(
      ClientSyncResponseContext(
        update: .client(makeClient(id: "stale-response")),
        deviceTokenUpdate: .set("token"),
        requestDeviceToken: "token",
        baseGeneration: 5,
        serverDate: Date(timeIntervalSince1970: 300),
        isCanonicalClientRequest: true,
        clientResponseGeneration: node.clerk.clientResponseGeneration,
        responseSequence: 1
      )
    )

    #expect(node.clerk.client == nil)
    #expect(node.coordinator.currentMaximumGeneration == 6)
    #expect(node.notifier.postCount == notificationCount)
    #expect(backend.allSlots().first?.event.generation == 6)

    try await node.coordinator.handleNetworkResponse(
      ClientSyncResponseContext(
        update: .client(makeClient(id: "fresh-response")),
        deviceTokenUpdate: .set("token"),
        requestDeviceToken: "token",
        baseGeneration: 6,
        serverDate: Date(timeIntervalSince1970: 301),
        isCanonicalClientRequest: true,
        clientResponseGeneration: node.clerk.clientResponseGeneration,
        responseSequence: 2
      )
    )

    #expect(node.clerk.client?.id == "fresh-response")
    #expect(backend.allSlots().first?.event.generation == 7)
  }

  @Test
  func olderResponseSequenceCannotReplaceNewerSameFrontierResponse() async throws {
    let backend = TestSlotBackend()
    let node = try makeNode(
      owner: "app.a",
      backend: backend,
      initialIdentity: SharedSessionLocalIdentity(
        state: .cleared,
        deviceToken: "token",
        client: nil,
        serverDate: nil
      )
    )

    try await node.coordinator.handleNetworkResponse(
      ClientSyncResponseContext(
        update: .client(makeClient(id: "newer")),
        deviceTokenUpdate: .set("token"),
        requestDeviceToken: "token",
        baseGeneration: 0,
        serverDate: nil,
        isCanonicalClientRequest: true,
        clientResponseGeneration: node.clerk.clientResponseGeneration,
        responseSequence: 2
      )
    )
    try await node.coordinator.handleNetworkResponse(
      ClientSyncResponseContext(
        update: .explicitClear,
        deviceTokenUpdate: .set("token"),
        requestDeviceToken: "token",
        baseGeneration: 0,
        serverDate: nil,
        isCanonicalClientRequest: true,
        clientResponseGeneration: node.clerk.clientResponseGeneration,
        responseSequence: 1
      )
    )

    #expect(node.clerk.client?.id == "newer")
    #expect(backend.allSlots().first?.event.client?.id == "newer")
  }

  @Test
  func newerRequestFromIntermediateNetworkFrontierCanExtendResponseLineage() async throws {
    let backend = TestSlotBackend()
    let node = try makeNode(
      owner: "app.a",
      backend: backend,
      initialIdentity: SharedSessionLocalIdentity(
        state: .cleared,
        deviceToken: "token",
        client: nil,
        serverDate: nil
      )
    )

    try await node.coordinator.handleNetworkResponse(
      responseContext(
        clientID: "first",
        token: "token",
        baseGeneration: 0,
        sequence: 1
      )
    )
    let intermediateFrontier = node.coordinator.currentMaximumGeneration

    try await node.coordinator.handleNetworkResponse(
      responseContext(
        clientID: "second-from-root",
        token: "token",
        baseGeneration: 0,
        sequence: 2
      )
    )
    try await node.coordinator.handleNetworkResponse(
      responseContext(
        clientID: "third-from-intermediate",
        token: "token",
        baseGeneration: intermediateFrontier,
        sequence: 3
      )
    )

    #expect(intermediateFrontier == 1)
    #expect(node.coordinator.currentMaximumGeneration == 3)
    #expect(node.clerk.client?.id == "third-from-intermediate")
    #expect(backend.allSlots().first?.event.generation == 3)
  }

  @Test
  func newerResponseFromSameCapturedFrontierExtendsNetworkLineage() async throws {
    let backend = TestSlotBackend()
    let node = try makeNode(
      owner: "app.a",
      backend: backend,
      initialIdentity: SharedSessionLocalIdentity(
        state: .cleared,
        deviceToken: "token",
        client: nil,
        serverDate: nil
      )
    )

    try await node.coordinator.handleNetworkResponse(
      ClientSyncResponseContext(
        update: .client(makeClient(id: "first")),
        deviceTokenUpdate: .set("token"),
        requestDeviceToken: "token",
        baseGeneration: 0,
        serverDate: Date(timeIntervalSince1970: 100),
        isCanonicalClientRequest: true,
        clientResponseGeneration: node.clerk.clientResponseGeneration,
        responseSequence: 1
      )
    )
    try await node.coordinator.handleNetworkResponse(
      ClientSyncResponseContext(
        update: .client(makeClient(id: "second")),
        deviceTokenUpdate: .set("token"),
        requestDeviceToken: "token",
        baseGeneration: 0,
        serverDate: Date(timeIntervalSince1970: 200),
        isCanonicalClientRequest: true,
        clientResponseGeneration: node.clerk.clientResponseGeneration,
        responseSequence: 2
      )
    )

    let event = try #require(backend.allSlots().first?.event)
    #expect(event.generation == 2)
    #expect(event.client?.id == "second")
    #expect(node.clerk.client?.id == "second")
  }

  @Test
  func canonicalActiveClientWithoutTokenThrows() async throws {
    let node = try makeNode(owner: "app.a", backend: TestSlotBackend())

    await #expect(throws: ClientSyncResponseError.missingDeviceTokenForCanonicalClient) {
      try await node.coordinator.handleNetworkResponse(
        ClientSyncResponseContext(
          update: .client(makeClient(id: "invalid")),
          deviceTokenUpdate: .clear,
          requestDeviceToken: nil,
          baseGeneration: 0,
          serverDate: nil,
          isCanonicalClientRequest: true,
          clientResponseGeneration: node.clerk.clientResponseGeneration,
          responseSequence: 1
        )
      )
    }
  }

  @Test
  func peerIdentityPersistsBeforeMemoryChanges() async throws {
    let backend = TestSlotBackend()
    let publisher = try makeNode(owner: "app.a", backend: backend)
    let receiver = try makeNode(owner: "app.b", backend: backend)
    let client = makeClient(id: "peer")

    try await publisher.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "peer-token",
      client: client,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    _ = await receiver.clerk.reloadFromSharedStorage()

    let persisted = try #require(try receiver.localStore.load())
    #expect(persisted.client == receiver.clerk.client)
    #expect(persisted.deviceToken == "peer-token")
    #expect(persisted.serverDate == receiver.clerk.lastClientServerFetchDate)
  }

  @Test
  func localPersistenceFailureRetainsPreviousInMemoryIdentity() async throws {
    let backend = TestSlotBackend()
    let previous = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "old-token",
      client: makeClient(id: "old-client"),
      serverDate: nil
    )
    let node = try makeNode(owner: "app.a", backend: backend, initialIdentity: previous)
    node.localStore.failSaves = true

    await #expect(throws: TestLocalIdentityStore.Failure.self) {
      try await node.coordinator.publishLocalIdentity(
        state: .present,
        deviceToken: "new-token",
        client: makeClient(id: "new-client"),
        serverDate: nil
      )
    }

    #expect(node.clerk.client?.id == "old-client")
    #expect(try node.localStore.load()?.deviceToken == "old-token")
    #expect(try node.localStore.loadPendingPublication() == nil)
    #expect(backend.allSlots().isEmpty)
    #expect(node.notifier.postCount == 0)
  }

  @Test
  func ownerSlotWriteFailureDoesNotNotifyOrApplyResponse() async throws {
    let backend = TestSlotBackend()
    backend.failSavesForOwners = ["app.a"]
    let node = try makeNode(owner: "app.a", backend: backend)

    await #expect(throws: TestSlotBackend.Failure.self) {
      try await node.coordinator.publishLocalIdentity(
        state: .present,
        deviceToken: "token",
        client: makeClient(id: "client"),
        serverDate: nil
      )
    }

    #expect(node.clerk.client == nil)
    #expect(node.notifier.postCount == 0)
    #expect(backend.allSlots().isEmpty)
    #expect(try node.localStore.loadPendingPublication() != nil)
  }

  @Test
  func restartRetriesExactDurablePendingPublication() async throws {
    let backend = TestSlotBackend()
    backend.failSavesForOwners = ["app.a"]
    let localStore = TestLocalIdentityStore()
    let original = try makeNode(
      owner: "app.a",
      backend: backend,
      localStore: localStore
    )

    await #expect(throws: TestSlotBackend.Failure.self) {
      try await original.coordinator.publishLocalIdentity(
        state: .present,
        deviceToken: "token",
        client: makeClient(id: "client"),
        serverDate: Date(timeIntervalSince1970: 100)
      )
    }
    await original.coordinator.shutdown(deleteOwnSlot: false)
    let pending = try #require(try localStore.loadPendingPublication())

    backend.failSavesForOwners = []
    let restarted = try makeNode(
      owner: "app.a",
      backend: backend,
      localStore: localStore
    )
    #expect(await restarted.coordinator.start().value)

    let published = try #require(backend.allSlots().first?.event)
    #expect(published == pending)
    #expect(try localStore.loadPendingPublication() == nil)
    #expect(try localStore.load()?.client?.id == "client")
    #expect(restarted.clerk.client?.id == "client")
    #expect(restarted.notifier.postCount == 1)
  }

  @Test
  func destructiveShutdownDiscardsPendingPublication() async throws {
    let backend = TestSlotBackend()
    backend.failSavesForOwners = ["app.a"]
    let node = try makeNode(owner: "app.a", backend: backend)

    await #expect(throws: TestSlotBackend.Failure.self) {
      try await node.coordinator.publishLocalIdentity(
        state: .present,
        deviceToken: "token",
        client: makeClient(id: "client"),
        serverDate: nil
      )
    }
    #expect(try node.localStore.loadPendingPublication() != nil)

    await node.coordinator.shutdown(deleteOwnSlot: true)

    #expect(try node.localStore.loadPendingPublication() == nil)
    #expect(backend.allSlots().isEmpty)
  }

  @Test
  func acceptedCommitFailureRetainsPendingUntilExactRecovery() async throws {
    let backend = TestSlotBackend()
    let previous = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "old-token",
      client: makeClient(id: "old-client"),
      serverDate: nil
    )
    let node = try makeNode(owner: "app.a", backend: backend, initialIdentity: previous)
    node.localStore.failCommits = true

    await #expect(throws: TestLocalIdentityStore.Failure.self) {
      try await node.coordinator.publishLocalIdentity(
        state: .present,
        deviceToken: "new-token",
        client: makeClient(id: "new-client"),
        serverDate: nil
      )
    }

    let pending = try #require(try node.localStore.loadPendingPublication())
    #expect(backend.allSlots().first?.event == pending)
    #expect(try node.localStore.load()?.client?.id == "old-client")
    #expect(node.clerk.client?.id == "old-client")
    #expect(node.notifier.postCount == 0)

    node.localStore.failCommits = false
    #expect(await node.coordinator.reloadFromSharedStorage())

    #expect(backend.allSlots().first?.event == pending)
    #expect(try node.localStore.loadPendingPublication() == nil)
    #expect(try node.localStore.load()?.client?.id == "new-client")
    #expect(node.clerk.client?.id == "new-client")
    #expect(node.notifier.postCount == 1)
  }

  @Test
  func pendingRecoveryNeverOverwritesNewerOwnSlot() async throws {
    let backend = TestSlotBackend()
    let localStore = TestLocalIdentityStore()
    let pending = try makeEvent(
      owner: "app.a",
      generation: 1,
      clientID: "pending"
    )
    try localStore.stagePendingPublication(pending)
    let newer = try makeEvent(
      owner: "app.a",
      generation: 2,
      clientID: "newer"
    )
    try TestOwnerSlotStore(owner: "app.a", backend: backend).saveOwnSlot(
      SharedSessionOwnerSlot(
        schemaVersion: SharedSessionOwnerSlot.schemaVersion,
        instanceFingerprint: "instance",
        slotOwnerIdentifier: "app.a",
        event: newer
      )
    )
    let saveCount = backend.saveCount
    let node = try makeNode(
      owner: "app.a",
      backend: backend,
      localStore: localStore
    )

    #expect(await node.coordinator.start().value)

    #expect(backend.saveCount == saveCount)
    #expect(backend.allSlots().first?.event == newer)
    #expect(try localStore.loadPendingPublication() == nil)
    #expect(try localStore.load()?.client?.id == "newer")
    #expect(node.clerk.client?.id == "newer")
  }

  @Test
  func localCandidateThatLosesReductionIsNeverAccepted() async throws {
    let backend = TestSlotBackend()
    let peer = try makeNode(owner: "app.peer", backend: backend)
    try await peer.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "peer-token",
      client: makeClient(id: "peer"),
      serverDate: nil,
      baseGeneration: 1
    )
    let node = try makeNode(owner: "app.local", backend: backend)

    try await node.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "local-token",
      client: makeClient(id: "local"),
      serverDate: nil,
      baseGeneration: 0
    )

    #expect(node.clerk.client?.id == "peer")
    #expect(try node.localStore.load()?.client?.id == "peer")
    #expect(try node.localStore.loadPendingPublication() == nil)
    #expect(backend.allSlots().allSatisfy { $0.event.client?.id == "peer" })
  }

  @Test
  func futureSchemaOwnSlotDoesNotBlockPeerAdoptionOrRetainPendingIntent() async throws {
    let backend = TestSlotBackend()
    let peer = try makeNode(owner: "app.peer", backend: backend)
    try await peer.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "peer-token",
      client: makeClient(id: "peer"),
      serverDate: nil,
      baseGeneration: 1
    )
    backend.futureSchemaOwners = ["app.local"]
    let node = try makeNode(owner: "app.local", backend: backend)

    try await node.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "local-token",
      client: makeClient(id: "local"),
      serverDate: nil,
      baseGeneration: 0
    )

    #expect(node.clerk.client?.id == "peer")
    #expect(try node.localStore.load()?.client?.id == "peer")
    #expect(try node.localStore.loadPendingPublication() == nil)
    #expect(backend.allSlots().allSatisfy { $0.slotOwnerIdentifier == "app.peer" })
  }

  @Test
  func publicationNotifiesOnlyAfterAcceptedCommitAndMemoryApply() async throws {
    let node = try makeNode(owner: "app.a", backend: TestSlotBackend())
    var observedCommittedIdentity = false
    node.notifier.onPost = {
      do {
        observedCommittedIdentity = try node.localStore.loadPendingPublication() == nil
          && node.localStore.load()?.client?.id == "client"
          && node.clerk.client?.id == "client"
      } catch {
        observedCommittedIdentity = false
      }
    }

    try await node.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "token",
      client: makeClient(id: "client"),
      serverDate: nil
    )

    #expect(observedCommittedIdentity)
  }

  @Test
  func olderFailedPublicationCannotBecomePendingAfterNewerSuccess() async throws {
    let backend = TestSlotBackend()
    backend.suspendNextSave()
    let node = try makeNode(owner: "app.a", backend: backend)
    let older = Task { @MainActor in
      try await node.coordinator.publishLocalIdentity(
        state: .present,
        deviceToken: "older-token",
        client: makeClient(id: "older"),
        serverDate: nil
      )
    }
    try await waitUntil { backend.isSaveSuspended }
    let newer = Task { @MainActor in
      try await node.coordinator.publishLocalIdentity(
        state: .present,
        deviceToken: "newer-token",
        client: makeClient(id: "newer"),
        serverDate: nil
      )
    }
    await Task.yield()
    backend.resumeSuspendedSave(failing: true)

    await #expect(throws: TestSlotBackend.Failure.self) {
      try await older.value
    }
    try await newer.value
    _ = await node.clerk.reloadFromSharedStorage()

    #expect(backend.allSlots().first?.event.client?.id == "newer")
    #expect(node.clerk.client?.id == "newer")
  }

  @Test
  func enumerationFailureRetainsLocalIdentity() async throws {
    let backend = TestSlotBackend()
    let previous = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "old-token",
      client: makeClient(id: "old-client"),
      serverDate: nil
    )
    let node = try makeNode(owner: "app.a", backend: backend, initialIdentity: previous)
    backend.failReads = true

    let changed = await node.clerk.reloadFromSharedStorage()

    #expect(!changed)
    #expect(node.clerk.client?.id == "old-client")
    #expect(try node.localStore.load()?.deviceToken == "old-token")
  }

  @Test
  func emptySharedStoreDoesNotClearExistingLocalIdentity() async throws {
    let previous = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "token",
      client: makeClient(id: "client"),
      serverDate: nil
    )
    let node = try makeNode(
      owner: "app.a",
      backend: TestSlotBackend(),
      initialIdentity: previous
    )

    #expect(await !node.clerk.reloadFromSharedStorage())
    #expect(node.clerk.client?.id == "client")
  }

  @Test
  func offlineColdStartHydratesSlotPublishedByTerminatedSibling() async throws {
    let backend = TestSlotBackend()
    let publisher = try makeNode(owner: "app.publisher", backend: backend)
    try await publisher.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "offline-token",
      client: makeClient(id: "offline-client"),
      serverDate: nil
    )
    publisher.coordinator.deactivate()

    let coldStartedReceiver = try makeNode(owner: "app.receiver", backend: backend)
    _ = await coldStartedReceiver.clerk.reloadFromSharedStorage()

    #expect(coldStartedReceiver.clerk.client?.id == "offline-client")
    #expect(try coldStartedReceiver.localStore.load()?.deviceToken == "offline-token")
  }

  @Test
  func initialReconciliationInstallsPeerFrontierBeforeRequestPreparation() async throws {
    let backend = TestSlotBackend()
    let publisher = try makeNode(owner: "app.publisher", backend: backend)
    try await publisher.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "peer-token",
      client: makeClient(id: "peer-client"),
      serverDate: nil
    )
    let receiver = try makeNode(owner: "app.receiver", backend: backend)

    var request = try URLRequest(url: #require(URL(string: "https://example.com/v1/client")))
    try await ClerkHeaderRequestMiddleware(runtimeScope: receiver.clerk.runtimeScope)
      .prepare(&request)

    #expect(request.value(forHTTPHeaderField: "Authorization") == "peer-token")
    #expect(request.clerkSharedSessionBaseGeneration == 1)
  }

  @Test
  func failedInitialReconciliationFailsPreparationOnceAndThenRetries() async throws {
    let backend = TestSlotBackend()
    backend.failReads = true
    let node = try makeNode(owner: "app.receiver", backend: backend)
    let middleware = ClerkHeaderRequestMiddleware(runtimeScope: node.clerk.runtimeScope)
    var failedRequest = try URLRequest(url: #require(URL(string: "https://example.com/v1/client")))

    await #expect(throws: SharedSessionSyncCoordinatorError.initialReconciliationFailed) {
      try await middleware.prepare(&failedRequest)
    }

    backend.failReads = false
    var retriedRequest = try URLRequest(url: #require(URL(string: "https://example.com/v1/client")))
    try await middleware.prepare(&retriedRequest)

    #expect(retriedRequest.clerkSharedSessionBaseGeneration == 0)
  }

  @Test
  func successfulBackgroundReconciliationRepairsFailedInitialBarrier() async throws {
    let backend = TestSlotBackend()
    backend.failReads = true
    let node = try makeNode(owner: "app.receiver", backend: backend)

    _ = await node.coordinator.start().value
    backend.failReads = false
    #expect(await !node.clerk.reloadFromSharedStorage())

    var request = try URLRequest(url: #require(URL(string: "https://example.com/v1/client")))
    try await ClerkHeaderRequestMiddleware(runtimeScope: node.clerk.runtimeScope)
      .prepare(&request)

    #expect(request.clerkSharedSessionBaseGeneration == 0)
  }

  @Test
  func requestRecoversFailedReconciliationBeforeCapturingFrontier() async throws {
    let backend = TestSlotBackend()
    let previous = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "old-token",
      client: makeClient(id: "old-client"),
      serverDate: nil
    )
    let receiver = try makeNode(
      owner: "app.receiver",
      backend: backend,
      initialIdentity: previous
    )
    var initialRequest = try URLRequest(url: #require(URL(string: "https://example.com/v1/client")))
    try await ClerkHeaderRequestMiddleware(runtimeScope: receiver.clerk.runtimeScope)
      .prepare(&initialRequest)

    let publisher = try makeNode(owner: "app.publisher", backend: backend)
    try await publisher.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "peer-token",
      client: makeClient(id: "peer-client"),
      serverDate: nil
    )
    receiver.localStore.failSaves = true
    #expect(await !receiver.clerk.reloadFromSharedStorage())
    receiver.localStore.failSaves = false

    var request = try URLRequest(url: #require(URL(string: "https://example.com/v1/client")))
    try await ClerkHeaderRequestMiddleware(runtimeScope: receiver.clerk.runtimeScope)
      .prepare(&request)

    #expect(request.value(forHTTPHeaderField: "Authorization") == "peer-token")
    #expect(request.value(forHTTPHeaderField: "x-clerk-client-id") == "peer-client")
    #expect(request.clerkSharedSessionBaseGeneration == 1)
    #expect(try receiver.localStore.load()?.client?.id == "peer-client")
  }

  @Test
  func notificationDuringFailedReconciliationSchedulesFollowupPass() async throws {
    let backend = TestSlotBackend()
    let receiver = try makeNode(owner: "app.receiver", backend: backend)
    var initialRequest = try URLRequest(url: #require(URL(string: "https://example.com/v1/client")))
    try await ClerkHeaderRequestMiddleware(runtimeScope: receiver.clerk.runtimeScope)
      .prepare(&initialRequest)

    let publisher = try makeNode(owner: "app.publisher", backend: backend)
    try await publisher.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "peer-token",
      client: makeClient(id: "peer-client"),
      serverDate: nil
    )

    let notificationDelivered = TestBlockingSignal()
    backend.failReads = true
    backend.beforeFailingRead = {
      Task { @MainActor in
        backend.failReads = false
        receiver.notifier.simulateNotification()
        notificationDelivered.signal()
      }
      notificationDelivered.wait()
    }
    receiver.notifier.simulateNotification()

    try await waitUntil { receiver.clerk.client?.id == "peer-client" }
    #expect(try receiver.localStore.load()?.deviceToken == "peer-token")
  }

  @Test
  func requestPreparationWaitsForAlreadyQueuedSharedIdentityWork() async throws {
    let backend = TestSlotBackend()
    let receiver = try makeNode(owner: "app.receiver", backend: backend)
    var initialRequest = try URLRequest(url: #require(URL(string: "https://example.com/v1/client")))
    try await ClerkHeaderRequestMiddleware(runtimeScope: receiver.clerk.runtimeScope)
      .prepare(&initialRequest)

    let publisher = try makeNode(owner: "app.publisher", backend: backend)
    try await publisher.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "peer-token",
      client: makeClient(id: "peer-client"),
      serverDate: nil
    )
    backend.suspendNextSave()
    receiver.notifier.simulateNotification()
    try await waitUntil { backend.isSaveSuspended }

    var didPrepare = false
    let requestTask = Task { @MainActor in
      var request = try URLRequest(url: #require(URL(string: "https://example.com/v1/client")))
      try await ClerkHeaderRequestMiddleware(runtimeScope: receiver.clerk.runtimeScope)
        .prepare(&request)
      didPrepare = true
      return request
    }
    await Task.yield()
    #expect(!didPrepare)

    backend.resumeSuspendedSave(failing: false)
    let request = try await requestTask.value

    #expect(didPrepare)
    #expect(request.value(forHTTPHeaderField: "Authorization") == "peer-token")
    #expect(request.clerkSharedSessionBaseGeneration == 1)
  }

  @Test
  func requestCapturesOneIdentityWhenReconciliationQueuesDuringEarlierWait() async throws {
    let backend = TestSlotBackend()
    let receiver = try makeNode(owner: "app.receiver", backend: backend)
    var initialRequest = try URLRequest(url: #require(URL(string: "https://example.com/v1/client")))
    try await ClerkHeaderRequestMiddleware(runtimeScope: receiver.clerk.runtimeScope)
      .prepare(&initialRequest)

    let publisher = try makeNode(owner: "app.publisher", backend: backend)
    try await publisher.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "peer-token",
      client: makeClient(id: "peer-client"),
      serverDate: nil
    )

    let gate = SharedRequestPreparationGate()
    let blocker = receiver.clerk.enqueueLocalIdentityOperation { _ in
      await gate.suspend()
    }
    try await waitUntil { gate.isSuspended }

    var didPrepare = false
    let requestTask = Task { @MainActor in
      var request = try URLRequest(url: #require(URL(string: "https://example.com/v1/client")))
      try await ClerkHeaderRequestMiddleware(runtimeScope: receiver.clerk.runtimeScope)
        .prepare(&request)
      didPrepare = true
      return request
    }
    await Task.yield()

    backend.suspendNextSave()
    receiver.notifier.simulateNotification()
    try await waitUntil { backend.isSaveSuspended }
    gate.resume()
    _ = try await blocker.value
    await Task.yield()
    #expect(!didPrepare)

    backend.resumeSuspendedSave(failing: false)
    let request = try await requestTask.value

    #expect(request.value(forHTTPHeaderField: "Authorization") == "peer-token")
    #expect(request.value(forHTTPHeaderField: "x-clerk-client-id") == "peer-client")
    #expect(request.clerkSharedSessionBaseGeneration == 1)
  }

  @Test
  func foregroundReconciliationRecoversMissedNotification() async throws {
    let backend = TestSlotBackend()
    let receiver = try makeNode(owner: "app.receiver", backend: backend)
    let publisher = try makeNode(owner: "app.publisher", backend: backend)
    try await publisher.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "foreground-token",
      client: makeClient(id: "foreground-client"),
      serverDate: nil
    )

    try receiver.coordinator.handle(.applicationDidEnterForeground, from: receiver.clerk)
    try await waitUntil { receiver.clerk.client?.id == "foreground-client" }

    #expect(try receiver.localStore.load()?.deviceToken == "foreground-token")
  }

  @Test
  func signOutIsPublishedAsDurableClearEvent() async throws {
    let backend = TestSlotBackend()
    let node = try makeNode(owner: "app.a", backend: backend)

    try await node.coordinator.publishLocalIdentity(
      state: .cleared,
      deviceToken: "token",
      client: nil,
      serverDate: Date(timeIntervalSince1970: 100)
    )

    let event = try #require(backend.allSlots().first?.event)
    #expect(event.state == .cleared)
    #expect(event.client == nil)
    #expect(event.deviceToken == "token")
    #expect(try node.localStore.load()?.state == .cleared)
  }

  @Test
  func siblingSignInAndSignOutConvergeInBothDirections() async throws {
    let backend = TestSlotBackend()
    let first = try makeNode(owner: "app.a", backend: backend)
    let second = try makeNode(owner: "app.z", backend: backend)
    try await first.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "token",
      client: makeClient(id: "signed-in"),
      serverDate: Date(timeIntervalSince1970: 100)
    )
    _ = await second.clerk.reloadFromSharedStorage()
    try await second.coordinator.publishLocalIdentity(
      state: .cleared,
      deviceToken: "token",
      client: nil,
      serverDate: Date(timeIntervalSince1970: 200)
    )
    _ = await first.clerk.reloadFromSharedStorage()

    #expect(first.clerk.client == nil)
    #expect(second.clerk.client == nil)
    #expect(Set(backend.allSlots().map(\.event.id)).count == 1)
    #expect(backend.allSlots().first?.event.state == .cleared)
  }

  @Test
  func localClearDeletesOnlyCallingOwnersSlot() async throws {
    let backend = TestSlotBackend()
    let first = try makeNode(owner: "app.a", backend: backend)
    let second = try makeNode(owner: "app.b", backend: backend)
    try await first.coordinator.publishLocalIdentity(
      state: .cleared,
      deviceToken: nil,
      client: nil,
      serverDate: nil
    )
    _ = await second.clerk.reloadFromSharedStorage()

    await first.coordinator.deleteOwnSlotAfterLocalClear()

    #expect(backend.allSlots().map(\.slotOwnerIdentifier) == ["app.b"])
  }

  @Test
  func localClearPreservesObservedFrontierForNextPublication() async throws {
    let backend = TestSlotBackend()
    let peer = try makeNode(owner: "app.peer", backend: backend)
    let node = try makeNode(owner: "app.local", backend: backend)
    try await peer.coordinator.publishLocalIdentity(
      state: .cleared,
      deviceToken: nil,
      client: nil,
      serverDate: nil,
      baseGeneration: 99
    )
    _ = await node.clerk.reloadFromSharedStorage()

    await node.coordinator.deleteOwnSlotAfterLocalClear()
    try await node.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "new-token",
      client: makeClient(id: "new-client"),
      serverDate: nil
    )

    let event = try #require(
      backend.allSlots().first { $0.slotOwnerIdentifier == "app.local" }?.event
    )
    #expect(event.generation == 101)
  }

  @Test
  func shutdownCanPreserveOwnSlotForSameTopologyReplacement() async throws {
    let backend = TestSlotBackend()
    let original = try makeNode(owner: "app.a", backend: backend)
    try await original.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "token",
      client: makeClient(id: "session"),
      serverDate: nil
    )

    await original.coordinator.shutdown(deleteOwnSlot: false)
    let replacement = try makeNode(owner: "app.a", backend: backend)
    _ = await replacement.clerk.reloadFromSharedStorage()

    #expect(backend.allSlots().count == 1)
    #expect(replacement.clerk.client?.id == "session")
  }

  @Test
  func shutdownDeletionRemovesOnlyCallingOwnersSlot() async throws {
    let backend = TestSlotBackend()
    let first = try makeNode(owner: "app.a", backend: backend)
    let peer = try makeNode(owner: "app.b", backend: backend)
    try await first.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "token",
      client: makeClient(id: "client"),
      serverDate: nil
    )
    _ = await peer.clerk.reloadFromSharedStorage()

    await first.coordinator.shutdown(deleteOwnSlot: true)

    #expect(backend.allSlots().map(\.slotOwnerIdentifier) == ["app.b"])
  }

  @Test
  func replicationDoesNotPostAnotherNotification() async throws {
    let backend = TestSlotBackend()
    let publisher = try makeNode(owner: "app.a", backend: backend)
    let receiver = try makeNode(owner: "app.b", backend: backend)
    try await publisher.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "token",
      client: makeClient(id: "client"),
      serverDate: nil
    )

    _ = await receiver.clerk.reloadFromSharedStorage()

    #expect(publisher.notifier.postCount == 1)
    #expect(receiver.notifier.postCount == 0)
  }

  @Test
  func watchPayloadPublishesOneAtomicSharedIdentityEvent() async throws {
    let backend = TestSlotBackend()
    let node = try makeNode(owner: "app.phone", backend: backend)
    let watchCoordinator = WatchConnectivityCoordinator()
    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "watch-token",
        version: WatchSyncVersion(rawValue: 1)
      ),
      clientUpdate: .snapshot(
        client: makeClient(id: "watch-client"),
        serverFetchDate: Date(timeIntervalSince1970: 100),
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )

    watchCoordinator.apply(payload, from: .phone, to: node.clerk)
    try await waitUntil {
      backend.allSlots().count == 1 && node.notifier.postCount == 1
    }

    let event = try #require(backend.allSlots().first?.event)
    #expect(event.deviceToken == "watch-token")
    #expect(event.client?.id == "watch-client")
    #expect(backend.saveCount == 1)
    #expect(node.notifier.postCount == 1)

    watchCoordinator.apply(payload, from: .phone, to: node.clerk)
    await watchCoordinator.waitForIdentityPublications()

    #expect(backend.allSlots().first?.event == event)
    #expect(backend.saveCount == 1)
    #expect(node.notifier.postCount == 1)
  }

  @Test
  func watchIdentityPayloadsPublishSeriallyInArrivalOrder() async throws {
    let backend = TestSlotBackend()
    backend.suspendNextSave()
    let node = try makeNode(owner: "app.phone", backend: backend)
    let watchCoordinator = WatchConnectivityCoordinator()
    let first = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "first-token",
        version: WatchSyncVersion(rawValue: 1)
      ),
      clientUpdate: .snapshot(
        client: makeClient(id: "first-client"),
        serverFetchDate: Date(timeIntervalSince1970: 100),
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )
    let second = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "second-token",
        version: WatchSyncVersion(rawValue: 2)
      ),
      clientUpdate: .snapshot(
        client: makeClient(id: "second-client"),
        serverFetchDate: Date(timeIntervalSince1970: 200),
        version: WatchSyncVersion(rawValue: 2)
      ),
      environment: nil
    )

    watchCoordinator.apply(first, from: .phone, to: node.clerk)
    try await waitUntil { backend.isSaveSuspended }
    watchCoordinator.apply(second, from: .phone, to: node.clerk)
    backend.resumeSuspendedSave(failing: false)
    try await waitUntil { node.clerk.client?.id == "second-client" }

    let event = try #require(backend.allSlots().first?.event)
    #expect(event.client?.id == "second-client")
    #expect(event.deviceToken == "second-token")
    #expect(event.generation == 2)
    #expect(node.notifier.postCount == 2)
  }

  @Test
  func canceledWatchPublicationCleanupCannotEraseReplacementTask() async throws {
    let backend = TestSlotBackend()
    backend.suspendNextSave()
    let node = try makeNode(owner: "app.phone", backend: backend)
    let watchCoordinator = WatchConnectivityCoordinator()
    let first = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "first-token",
        version: WatchSyncVersion(rawValue: 1)
      ),
      clientUpdate: .snapshot(
        client: makeClient(id: "first-client"),
        serverFetchDate: Date(timeIntervalSince1970: 100),
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )
    let replacement = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "replacement-token",
        version: WatchSyncVersion(rawValue: 2)
      ),
      clientUpdate: .snapshot(
        client: makeClient(id: "replacement-client"),
        serverFetchDate: Date(timeIntervalSince1970: 200),
        version: WatchSyncVersion(rawValue: 2)
      ),
      environment: nil
    )

    watchCoordinator.apply(first, from: .phone, to: node.clerk)
    try await waitUntil { backend.isSaveSuspended }
    try watchCoordinator.handle(.localStorageDidClear, from: node.clerk)
    Clerk.clearAllKeychainItems(in: node.clerk.dependencies.appLocalKeychain)
    watchCoordinator.apply(replacement, from: .phone, to: node.clerk)
    #expect(watchCoordinator.activeIdentityPublicationCount == 1)

    backend.saveDelay = 0.1
    backend.resumeSuspendedSave(failing: false)
    try await waitUntil { node.clerk.client?.id == "first-client" }

    #expect(watchCoordinator.activeIdentityPublicationCount == 1)
    try await waitUntil { node.clerk.client?.id == "replacement-client" }
    await watchCoordinator.waitForIdentityPublications()
    #expect(watchCoordinator.activeIdentityPublicationCount == 0)
  }

  @Test
  func watchPublicationAllocatesGenerationWhenCoordinatorQueueProcessesIt() async throws {
    let backend = TestSlotBackend()
    backend.suspendNextSave()
    let node = try makeNode(owner: "app.phone", backend: backend)
    let earlierPublication = Task { @MainActor in
      try await node.coordinator.publishLocalIdentity(
        state: .present,
        deviceToken: "earlier-token",
        client: makeClient(id: "earlier-client"),
        serverDate: Date(timeIntervalSince1970: 100)
      )
    }
    try await waitUntil { backend.isSaveSuspended }

    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "watch-token",
        version: WatchSyncVersion(rawValue: 1)
      ),
      clientUpdate: .snapshot(
        client: makeClient(id: "watch-client"),
        serverFetchDate: Date(timeIntervalSince1970: 200),
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )
    let watchCoordinator = WatchConnectivityCoordinator()
    watchCoordinator.apply(payload, from: .phone, to: node.clerk)
    backend.resumeSuspendedSave(failing: false)

    try await earlierPublication.value
    try await waitUntil { node.clerk.client?.id == "watch-client" }

    let event = try #require(backend.allSlots().first?.event)
    #expect(event.client?.id == "watch-client")
    #expect(event.generation == 2)
  }

  @Test
  func queuedWatchPayloadDoesNotSuppressEarlierSharedIdentityChange() async throws {
    let backend = TestSlotBackend()
    backend.suspendNextSave()
    let node = try makeNode(owner: "app.phone", backend: backend)
    let watchCoordinator = WatchConnectivityCoordinator()
    node.clerk.internalStateChanges.addObserver(watchCoordinator)
    let earlierPublication = Task { @MainActor in
      try await node.coordinator.publishLocalIdentity(
        state: .present,
        deviceToken: "earlier-token",
        client: makeClient(id: "earlier-client"),
        serverDate: Date(timeIntervalSince1970: 100)
      )
    }
    try await waitUntil { backend.isSaveSuspended }

    watchCoordinator.apply(
      WatchSyncPayload(
        deviceTokenUpdate: .tokenSet(token: "stale-token", version: .initial),
        clientUpdate: .snapshot(
          client: makeClient(id: "stale-watch-client"),
          serverFetchDate: Date(timeIntervalSince1970: 50),
          version: .initial
        ),
        environment: nil
      ),
      from: .phone,
      to: node.clerk
    )
    backend.resumeSuspendedSave(failing: false)

    try await earlierPublication.value
    await watchCoordinator.waitForIdentityPublications()

    let metadata = try WatchSyncMetadataStore(
      keychain: node.clerk.dependencies.watchSyncKeychain
    ).load()
    #expect(node.clerk.client?.id == "earlier-client")
    #expect(metadata.deviceTokenVersion == 1)
    #expect(metadata.authVersion == 1)
    #expect(metadata.deviceTokenFingerprint == WatchConnectivityCoordinator.deviceTokenFingerprint("earlier-token"))
    #expect(try metadata.authFingerprint == (WatchConnectivityCoordinator.authFingerprint(
      client: node.clerk.client,
      serverDate: node.clerk.lastClientServerFetchDate
    )))
  }

  @Test
  func watchArrivalReservesCoordinatorQueueBeforeNetworkResponse() async throws {
    let backend = TestSlotBackend()
    let node = try makeNode(owner: "app.phone", backend: backend)
    try await node.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "token",
      client: makeClient(id: "initial"),
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let watchCoordinator = WatchConnectivityCoordinator()
    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "token",
        version: WatchSyncVersion(rawValue: 1)
      ),
      clientUpdate: .cleared(
        serverFetchDate: Date(timeIntervalSince1970: 200),
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )

    watchCoordinator.apply(payload, from: .phone, to: node.clerk)
    try await node.coordinator.handleNetworkResponse(
      ClientSyncResponseContext(
        update: .client(makeClient(id: "delayed-response")),
        deviceTokenUpdate: .set("token"),
        requestDeviceToken: "token",
        baseGeneration: 1,
        serverDate: Date(timeIntervalSince1970: 300),
        isCanonicalClientRequest: true,
        clientResponseGeneration: node.clerk.clientResponseGeneration,
        responseSequence: 1
      )
    )

    let event = try #require(backend.allSlots().first?.event)
    #expect(event.generation == 2)
    #expect(event.client == nil)
    #expect(node.clerk.client == nil)
    #expect(node.notifier.postCount == 2)
  }

  @Test
  func headerPreparationCapturesTypedFrontierAndCanonicalMarker() async throws {
    let node = try makeNode(owner: "app.a", backend: TestSlotBackend())
    try await node.coordinator.waitForInitialReconciliation()
    try await node.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "token",
      client: makeClient(id: "client"),
      serverDate: nil
    )
    node.localStore.failLoads = true
    var request = try URLRequest(url: #require(URL(string: "https://example.com/v1/client")))
    request.setValue(
      "1",
      forHTTPHeaderField: ClerkHeaderRequestMiddleware.canonicalClientRequestHeader
    )

    try await ClerkHeaderRequestMiddleware(runtimeScope: node.clerk.runtimeScope)
      .prepare(&request)

    #expect(request.clerkSharedSessionBaseGeneration == 1)
    #expect(request.clerkIsCanonicalClientRequest)
    #expect(request.value(forHTTPHeaderField: "Authorization") == "token")
    #expect(request.value(
      forHTTPHeaderField: ClerkHeaderRequestMiddleware.canonicalClientRequestHeader
    ) == nil)
  }

  @Test
  func canonicalEmptyOrMalformedResponseCannotRotateOnlyToken() async throws {
    let backend = TestSlotBackend()
    let previous = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "old-token",
      client: makeClient(id: "old-client"),
      serverDate: nil
    )
    let node = try makeNode(
      owner: "app.a",
      backend: backend,
      initialIdentity: previous
    )
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": "rotated-token"]
    ))
    var request = URLRequest(url: url)
    request.setValue("old-token", forHTTPHeaderField: "Authorization")
    request.setClerkSharedSessionBaseGeneration(0)
    request.setClerkCanonicalClientRequest(true)
    let middleware = ClerkClientSyncResponseMiddleware(runtimeScope: node.clerk.runtimeScope)

    for data in [
      Data("{}".utf8),
      Data(#"{"response":null,"client":null}"#.utf8),
      Data(#"{"client":{"id":123}}"#.utf8),
    ] {
      try await middleware.validate(response, data: data, for: request)
    }

    #expect(backend.allSlots().isEmpty)
    #expect(try node.localStore.load()?.deviceToken == "old-token")
    #expect(node.clerk.client?.id == "old-client")
  }

  @Test
  func canonicalCompleteResponsePublishesTokenAndClientTogether() async throws {
    let backend = TestSlotBackend()
    let node = try makeNode(owner: "app.a", backend: backend)
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": "response-token"]
    ))
    var request = URLRequest(url: url)
    request.setClerkSharedSessionBaseGeneration(0)
    request.setClerkCanonicalClientRequest(true)
    let client = makeClient(id: "response-client")
    let data = try JSONEncoder.clerkEncoder.encode(["response": client])

    try await ClerkClientSyncResponseMiddleware(runtimeScope: node.clerk.runtimeScope)
      .validate(response, data: data, for: request)

    let event = try #require(backend.allSlots().first?.event)
    #expect(event.deviceToken == "response-token")
    #expect(event.client?.id == "response-client")
    #expect(try node.localStore.load()?.client?.id == "response-client")
  }

  @Test
  func conflictingPendingEventIsAbandonedWithoutWedgingFuturePublications() async throws {
    let backend = TestSlotBackend()
    let node = try makeNode(owner: "app.a", backend: backend)
    let eventID = UUID()
    let pending = try makeEvent(
      id: eventID,
      owner: "app.a",
      generation: 5,
      clientID: "pending"
    )
    let conflicting = try makeEvent(
      id: eventID,
      owner: "app.b",
      generation: 5,
      clientID: "conflicting"
    )
    try node.localStore.stagePendingPublication(pending)
    try backend.save(
      SharedSessionOwnerSlot(
        schemaVersion: SharedSessionOwnerSlot.schemaVersion,
        instanceFingerprint: "instance",
        slotOwnerIdentifier: "app.a",
        event: pending
      ),
      owner: "app.a"
    )
    try backend.save(
      SharedSessionOwnerSlot(
        schemaVersion: SharedSessionOwnerSlot.schemaVersion,
        instanceFingerprint: "instance",
        slotOwnerIdentifier: "app.b",
        event: conflicting
      ),
      owner: "app.b"
    )

    _ = await node.clerk.reloadFromSharedStorage()

    #expect(try node.localStore.loadPendingPublication() == nil)
    #expect(node.coordinator.currentMaximumGeneration == 5)

    try await node.coordinator.publishLocalIdentity(
      state: .present,
      deviceToken: "recovered-token",
      client: makeClient(id: "recovered"),
      serverDate: nil
    )

    let recovered = try #require(
      backend.allSlots().first { $0.slotOwnerIdentifier == "app.a" }?.event
    )
    #expect(recovered.id != eventID)
    #expect(recovered.generation == 6)
    #expect(recovered.client?.id == "recovered")
    #expect(node.clerk.client?.id == "recovered")
  }

  @Test
  func updateDeviceTokenPublishesClearedIdentityBeforeRefreshFailure() async throws {
    let backend = TestSlotBackend()
    let previous = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "old-token",
      client: makeClient(id: "old-client"),
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let node = try makeNode(
      owner: "app.a",
      backend: backend,
      initialIdentity: previous,
      clientService: MockClientService(get: { throw TestSlotBackend.Failure.read })
    )

    await #expect(throws: TestSlotBackend.Failure.self) {
      try await node.clerk.updateDeviceToken("new-token")
    }

    let event = try #require(backend.allSlots().first?.event)
    #expect(event.state == .cleared)
    #expect(event.deviceToken == "new-token")
    #expect(event.client == nil)
    #expect(node.clerk.client == nil)
    #expect(try node.localStore.load()?.deviceToken == "new-token")
    #expect(try node.localStore.load()?.client == nil)
  }

  @Test
  func shutdownDeletesOwnSlotAfterSuspendedPublicationAndFencesOldWork() async throws {
    let backend = TestSlotBackend()
    backend.saveDelay = 0.05
    let node = try makeNode(owner: "app.old", backend: backend)
    let publication = Task { @MainActor in
      try await node.coordinator.publishLocalIdentity(
        state: .present,
        deviceToken: "old-token",
        client: makeClient(id: "old-client"),
        serverDate: nil
      )
    }
    try await Task.sleep(for: .milliseconds(10))

    await node.coordinator.shutdown(deleteOwnSlot: true)

    await #expect(throws: CancellationError.self) {
      try await publication.value
    }
    #expect(backend.allSlots().isEmpty)
    #expect(node.notifier.postCount == 0)
  }

  @Test
  func localClearSerializesDeletionAfterSuspendedPublicationAndFencesOldWork() async throws {
    let backend = TestSlotBackend()
    backend.suspendNextSave()
    let node = try makeNode(owner: "app.a", backend: backend)
    let publication = Task { @MainActor in
      try await node.coordinator.publishLocalIdentity(
        state: .present,
        deviceToken: "stale-token",
        client: makeClient(id: "stale-client"),
        serverDate: nil
      )
    }
    try await waitUntil { backend.isSaveSuspended }

    node.coordinator.beginLocalClear()
    let deletion = Task { @MainActor in
      await node.coordinator.deleteOwnSlotAfterLocalClear()
    }
    backend.resumeSuspendedSave(failing: false)

    await #expect(throws: CancellationError.self) {
      try await publication.value
    }
    await deletion.value

    #expect(backend.allSlots().isEmpty)
    #expect(try node.localStore.loadPendingPublication() == nil)
    #expect(node.notifier.postCount == 0)
  }

  @Test
  func notificationNameDoesNotExposeKeychainConfiguration() throws {
    let config = Clerk.Options.KeychainConfig(
      service: "com.example.clerk",
      accessGroup: "TEAMID.com.example.clerk"
    )
    let name = SharedSessionSyncDarwinNotifier.notificationName(for: config)

    #expect(!name.contains(config.service))
    #expect(try !name.contains(#require(config.accessGroup)))
    #expect(
      name != SharedSessionSyncDarwinNotifier.notificationName(
        for: config,
        instanceFingerprint: "another-instance"
      )
    )
    #expect(
      name == SharedSessionSyncDarwinNotifier.notificationName(
        for: .init(
          service: config.service,
          accessGroup: "  TEAMID.com.example.clerk\n"
        )
      )
    )
  }

  private func makeNode(
    owner: String,
    backend: TestSlotBackend,
    initialIdentity: SharedSessionLocalIdentity? = nil,
    localStore suppliedLocalStore: TestLocalIdentityStore? = nil,
    clientService: (any ClientServiceProtocol)? = nil
  ) throws -> TestNode {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let localStore = suppliedLocalStore ?? TestLocalIdentityStore()
    if let initialIdentity {
      try localStore.save(initialIdentity)
    }
    let apiClient = createMockAPIClient(
      runtimeScope: .init(epoch: clerk.configurationEpoch, clerkProvider: { clerk })
    )
    let dependencies = MockDependencyContainer(
      apiClient: apiClient,
      keychain: keychain,
      appLocalKeychain: keychain,
      identityKeychain: keychain,
      sharedSessionLocalIdentityStore: localStore,
      clientService: clientService ?? MockClientService(get: { nil })
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init()
    )
    clerk.dependencies = dependencies
    if let initialIdentity {
      clerk.setSharedSessionIdentityIfNeeded(initialIdentity)
    }

    let notifier = TestSharedSessionSyncNotifier()
    let coordinator = SharedSessionSyncCoordinator(
      ownerIdentifier: owner,
      instanceFingerprint: "instance",
      slotStore: TestOwnerSlotStore(owner: owner, backend: backend),
      localIdentityStore: localStore,
      notifier: notifier,
      configurationEpoch: clerk.configurationEpoch,
      clerk: clerk,
      logError: { _, _ in }
    )
    clerk.sharedSessionSyncCoordinator = coordinator
    clerk.internalStateChanges.addObserver(coordinator)
    return TestNode(
      clerk: clerk,
      coordinator: coordinator,
      localStore: localStore,
      notifier: notifier
    )
  }

  private func makeClient(id: String) -> Client {
    var client = Client.mockSignedOut
    client.id = id
    return client
  }

  private func responseContext(
    clientID: String,
    token: String,
    baseGeneration: UInt64,
    sequence: Int
  ) -> ClientSyncResponseContext {
    ClientSyncResponseContext(
      update: .client(makeClient(id: clientID)),
      deviceTokenUpdate: .set(token),
      requestDeviceToken: token,
      baseGeneration: baseGeneration,
      serverDate: Date(timeIntervalSince1970: TimeInterval(sequence)),
      isCanonicalClientRequest: true,
      clientResponseGeneration: nil,
      responseSequence: sequence
    )
  }

  private func makeEvent(
    id: UUID = UUID(),
    owner: String,
    generation: UInt64,
    clientID: String
  ) throws -> SharedSessionIdentityEvent {
    try SharedSessionIdentityEvent(
      id: id,
      originOwnerIdentifier: owner,
      generation: generation,
      state: .present,
      deviceToken: "token-\(clientID)",
      client: makeClient(id: clientID),
      serverDate: nil
    ).validated()
  }

  private func waitUntil(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(1)
    while ContinuousClock.now < deadline {
      if condition() { return }
      await Task.yield()
    }
    throw ClerkClientError(message: "Timed out waiting for shared Watch publication.")
  }
}

@MainActor
private struct TestNode {
  let clerk: Clerk
  let coordinator: SharedSessionSyncCoordinator
  let localStore: TestLocalIdentityStore
  let notifier: TestSharedSessionSyncNotifier
}

@MainActor
private final class SharedRequestPreparationGate {
  private(set) var isSuspended = false
  private var continuation: CheckedContinuation<Void, Never>?

  func suspend() async {
    isSuspended = true
    await withCheckedContinuation { continuation in
      self.continuation = continuation
    }
    isSuspended = false
  }

  func resume() {
    continuation?.resume()
    continuation = nil
  }
}

private final class TestSlotBackend: @unchecked Sendable {
  enum Failure: Error {
    case read
    case save
  }

  private let lock = NSLock()
  private let saveCondition = NSCondition()
  private var slots: [String: SharedSessionOwnerSlot] = [:]
  private var saveOperations = 0
  private var shouldSuspendNextSave = false
  private var suspendedSaveShouldResume = false
  private var suspendedSaveShouldFail = false
  private var saveIsSuspended = false
  private var readsShouldFail = false
  var failReads: Bool {
    get { lock.withLock { readsShouldFail } }
    set { lock.withLock { readsShouldFail = newValue } }
  }

  var beforeFailingRead: (@Sendable () -> Void)?
  var failSavesForOwners: Set<String> = []
  var futureSchemaOwners: Set<String> = []
  var saveDelay: TimeInterval = 0

  var saveCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return saveOperations
  }

  var isSaveSuspended: Bool {
    saveCondition.lock()
    defer { saveCondition.unlock() }
    return saveIsSuspended
  }

  func suspendNextSave() {
    saveCondition.lock()
    shouldSuspendNextSave = true
    suspendedSaveShouldResume = false
    suspendedSaveShouldFail = false
    saveCondition.unlock()
  }

  func resumeSuspendedSave(failing: Bool) {
    saveCondition.lock()
    suspendedSaveShouldFail = failing
    suspendedSaveShouldResume = true
    saveCondition.broadcast()
    saveCondition.unlock()
  }

  func load(owner: String) throws -> SharedSessionOwnerSlot? {
    lock.lock()
    defer { lock.unlock() }
    guard !readsShouldFail else { throw Failure.read }
    return slots[owner]
  }

  func loadAll() throws -> [SharedSessionOwnerSlot] {
    lock.lock()
    let shouldFail = readsShouldFail
    let result = slots.values.sorted { $0.slotOwnerIdentifier < $1.slotOwnerIdentifier }
    lock.unlock()
    if shouldFail {
      beforeFailingRead?()
      throw Failure.read
    }
    return result
  }

  func save(_ slot: SharedSessionOwnerSlot, owner: String) throws {
    if futureSchemaOwners.contains(owner) {
      throw SharedSessionOwnerSlotStoreError.futureSchemaVersion(3)
    }
    saveCondition.lock()
    let shouldSuspend = shouldSuspendNextSave
    shouldSuspendNextSave = false
    if shouldSuspend {
      saveIsSuspended = true
      saveCondition.broadcast()
      while !suspendedSaveShouldResume {
        saveCondition.wait()
      }
      saveIsSuspended = false
    }
    let shouldFailSuspendedSave = shouldSuspend && suspendedSaveShouldFail
    saveCondition.unlock()
    if shouldFailSuspendedSave {
      throw Failure.save
    }

    if saveDelay > 0 {
      Thread.sleep(forTimeInterval: saveDelay)
    }
    lock.lock()
    defer { lock.unlock() }
    guard !failSavesForOwners.contains(owner) else { throw Failure.save }
    slots[owner] = slot
    saveOperations += 1
  }

  func delete(owner: String) {
    lock.lock()
    defer { lock.unlock() }
    slots.removeValue(forKey: owner)
  }

  func allSlots() -> [SharedSessionOwnerSlot] {
    (try? loadAll()) ?? []
  }
}

private final class TestBlockingSignal: @unchecked Sendable {
  private let condition = NSCondition()
  private var isSignaled = false

  func wait() {
    condition.lock()
    while !isSignaled {
      condition.wait()
    }
    condition.unlock()
  }

  func signal() {
    condition.withLock {
      isSignaled = true
      condition.broadcast()
    }
  }
}

private struct TestOwnerSlotStore: SharedSessionSlotStoring {
  let owner: String
  let backend: TestSlotBackend

  func loadOwnSlot() throws -> SharedSessionOwnerSlot? {
    try backend.load(owner: owner)
  }

  func loadAllSlots() throws -> [SharedSessionOwnerSlot] {
    try backend.loadAll()
  }

  func saveOwnSlot(_ slot: SharedSessionOwnerSlot) throws {
    try backend.save(slot, owner: owner)
  }

  func deleteOwnSlot() throws {
    backend.delete(owner: owner)
  }
}

private final class TestLocalIdentityStore: @unchecked Sendable, SharedSessionLocalIdentityStoring {
  enum Failure: Error {
    case save
  }

  private let lock = NSLock()
  private var record: SharedSessionLocalIdentityRecord?
  var failSaves = false
  var failLoads = false
  var failStages = false
  var failCommits = false

  func loadRecord() throws -> SharedSessionLocalIdentityRecord? {
    lock.lock()
    defer { lock.unlock() }
    guard !failLoads else { throw Failure.save }
    return record
  }

  func updateRecord(
    _ update: (SharedSessionLocalIdentityRecord?) throws -> SharedSessionLocalIdentityRecord?
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    let updatedRecord = try update(record)
    let isStage = record?.pendingPublication == nil
      && updatedRecord?.pendingPublication != nil
    let isCommit = record?.pendingPublication != nil
      && updatedRecord?.pendingPublication == nil
    guard !failSaves,
          !(failStages && isStage),
          !(failCommits && isCommit)
    else {
      throw Failure.save
    }
    record = updatedRecord
  }
}

@MainActor
private final class TestSharedSessionSyncNotifier: SharedSessionSyncNotifying {
  private var handler: (@MainActor () -> Void)?
  var postCount = 0
  var onPost: (@MainActor () -> Void)?

  func setHandler(_ handler: @escaping @MainActor () -> Void) {
    self.handler = handler
  }

  func post() {
    postCount += 1
    onPost?()
  }

  func simulateNotification() {
    handler?()
  }
}
