@testable import ClerkKit
import Foundation
import Testing

@Suite(.serialized)
struct SharedSessionTopologyMigrationTests {
  @Test
  func emptyDestinationPublishesCompleteAcceptedIdentity() throws {
    let identity = makeIdentity(clientID: "accepted")
    let localStore = SharedSessionLocalIdentityStore(keychain: InMemoryKeychain())
    let slotStore = TopologyOwnerSlotStore(ownerIdentifier: "app.new")

    let rollback = try SharedSessionTopologyMigration.prepare(
      identity: identity,
      destinationIdentityStore: localStore,
      destinationSlotStore: slotStore,
      destinationInstanceFingerprint: "destination",
      destinationOwnerIdentifier: "app.new"
    )

    #expect(try localStore.load() == identity)
    let slot = try #require(try slotStore.loadOwnSlot())
    #expect(slot.instanceFingerprint == "destination")
    #expect(slot.event.originOwnerIdentifier == "app.new")
    #expect(slot.event.generation == 1)
    #expect(slot.event.deviceToken == identity.deviceToken)
    #expect(slot.event.client == identity.client)
    #expect(slot.event.serverDate == identity.serverDate)

    try rollback.restore()
    #expect(try localStore.loadRecord() == nil)
    #expect(try slotStore.loadOwnSlot() == nil)
  }

  @Test
  func sourceSlotReplacementAdvancesDestinationGeneration() throws {
    let sourceSlot = try makeSlot(
      owner: "app.old",
      generation: 7,
      identity: makeIdentity(clientID: "old")
    )
    let slotStore = TopologyOwnerSlotStore(
      ownerIdentifier: "app.new",
      slots: [sourceSlot]
    )
    let localStore = SharedSessionLocalIdentityStore(keychain: InMemoryKeychain())

    _ = try SharedSessionTopologyMigration.prepare(
      identity: makeIdentity(clientID: "accepted"),
      destinationIdentityStore: localStore,
      destinationSlotStore: slotStore,
      destinationInstanceFingerprint: "instance",
      destinationOwnerIdentifier: "app.new",
      excludingSourceOwnerIdentifier: "app.old"
    )

    let destinationSlot = try #require(try slotStore.loadOwnSlot())
    #expect(destinationSlot.event.generation == 8)
    #expect(destinationSlot.event.client?.id == "accepted")
  }

  @Test
  func staleDestinationOwnedSlotIsReplacedWhenNoPeerExists() throws {
    let staleIdentity = makeIdentity(clientID: "stale")
    let staleSlot = try makeSlot(
      owner: "app.new",
      generation: 7,
      identity: staleIdentity
    )
    let slotStore = TopologyOwnerSlotStore(
      ownerIdentifier: "app.new",
      slots: [staleSlot]
    )
    let localStore = SharedSessionLocalIdentityStore(keychain: InMemoryKeychain())

    let rollback = try SharedSessionTopologyMigration.prepare(
      identity: makeIdentity(clientID: "accepted"),
      destinationIdentityStore: localStore,
      destinationSlotStore: slotStore,
      destinationInstanceFingerprint: "instance",
      destinationOwnerIdentifier: "app.new"
    )

    let destinationSlot = try #require(try slotStore.loadOwnSlot())
    #expect(destinationSlot.event.generation == 8)
    #expect(destinationSlot.event.client?.id == "accepted")
    #expect(try localStore.load()?.client?.id == "accepted")

    try rollback.restore()
    #expect(try slotStore.loadOwnSlot() == staleSlot)
    #expect(try localStore.loadRecord() == nil)
  }

  @Test
  func existingPendingPublicationIsSupersededTransactionally() throws {
    let previousIdentity = makeIdentity(clientID: "previous")
    let pendingPublication = try makeEvent(
      owner: "app.old",
      generation: 9,
      identity: makeIdentity(clientID: "pending")
    )
    let localStore = SharedSessionLocalIdentityStore(keychain: InMemoryKeychain())
    try localStore.save(previousIdentity)
    try localStore.stagePendingPublication(pendingPublication)
    let previousRecord = try localStore.loadRecord()
    let slotStore = TopologyOwnerSlotStore(ownerIdentifier: "app.new")

    let rollback = try SharedSessionTopologyMigration.prepare(
      identity: makeIdentity(clientID: "accepted"),
      destinationIdentityStore: localStore,
      destinationSlotStore: slotStore,
      destinationInstanceFingerprint: "destination",
      destinationOwnerIdentifier: "app.new"
    )

    let slot = try #require(try slotStore.loadOwnSlot())
    #expect(slot.event.generation == 10)
    #expect(slot.event.client?.id == "accepted")
    #expect(try localStore.load()?.client?.id == "accepted")
    #expect(try localStore.loadPendingPublication() == nil)

    try rollback.restore()
    #expect(try localStore.loadRecord() == previousRecord)
    #expect(try slotStore.loadOwnSlot() == nil)
  }

  @Test
  func destinationPublicationFailureRestoresPreviousLocalIdentity() throws {
    let previousIdentity = makeIdentity(clientID: "previous")
    let localStore = SharedSessionLocalIdentityStore(keychain: InMemoryKeychain())
    try localStore.save(previousIdentity)
    try localStore.stagePendingPublication(makeEvent(
      owner: "app.old",
      generation: 4,
      identity: makeIdentity(clientID: "pending")
    ))
    let previousRecord = try localStore.loadRecord()
    let slotStore = TopologyOwnerSlotStore(
      ownerIdentifier: "app.new",
      saveFails: true
    )

    #expect(throws: TopologyOwnerSlotStore.Failure.save) {
      _ = try SharedSessionTopologyMigration.prepare(
        identity: makeIdentity(clientID: "accepted"),
        destinationIdentityStore: localStore,
        destinationSlotStore: slotStore,
        destinationInstanceFingerprint: "destination",
        destinationOwnerIdentifier: "app.new"
      )
    }

    #expect(try localStore.loadRecord() == previousRecord)
    #expect(try slotStore.loadOwnSlot() == nil)
  }

  @Test
  func finalIdentityCommitFailureRollsBackPublishedSlotAndRecord() throws {
    let previousIdentity = makeIdentity(clientID: "previous")
    let previousRecord = SharedSessionLocalIdentityRecord(
      acceptedIdentity: previousIdentity,
      pendingPublication: nil
    )
    let localStore = CommitFailingTopologyIdentityStore(record: previousRecord)
    let previousSlot = try makeSlot(
      owner: "app.new",
      generation: 3,
      identity: previousIdentity
    )
    let slotStore = TopologyOwnerSlotStore(
      ownerIdentifier: "app.new",
      slots: [previousSlot]
    )

    #expect(throws: CommitFailingTopologyIdentityStore.Failure.commit) {
      _ = try SharedSessionTopologyMigration.prepare(
        identity: makeIdentity(clientID: "accepted"),
        destinationIdentityStore: localStore,
        destinationSlotStore: slotStore,
        destinationInstanceFingerprint: "destination",
        destinationOwnerIdentifier: "app.new"
      )
    }

    #expect(try localStore.loadRecord() == previousRecord)
    #expect(try slotStore.loadOwnSlot() == previousSlot)
  }

  @Test
  func rollbackPreservesNewerDestinationPublicationAndIdentity() throws {
    let localStore = SharedSessionLocalIdentityStore(keychain: InMemoryKeychain())
    let slotStore = TopologyOwnerSlotStore(ownerIdentifier: "app.new")
    let rollback = try SharedSessionTopologyMigration.prepare(
      identity: makeIdentity(clientID: "migrated"),
      destinationIdentityStore: localStore,
      destinationSlotStore: slotStore,
      destinationInstanceFingerprint: "instance",
      destinationOwnerIdentifier: "app.new"
    )
    let newerIdentity = makeIdentity(clientID: "newer")
    let newerSlot = try makeSlot(
      owner: "app.new",
      generation: 99,
      identity: newerIdentity
    )
    try slotStore.saveOwnSlot(newerSlot)
    try localStore.save(newerIdentity)

    #expect(throws: SharedSessionTopologyMigrationError.destinationSlotChanged) {
      try rollback.restore()
    }

    #expect(try slotStore.loadOwnSlot() == newerSlot)
    #expect(try localStore.load() == newerIdentity)
  }

  @Test
  func rollbackKeepsMigratedIdentityWhenDestinationSlotWasSuperseded() throws {
    let localStore = SharedSessionLocalIdentityStore(keychain: InMemoryKeychain())
    let slotStore = TopologyOwnerSlotStore(ownerIdentifier: "app.new")
    let migratedIdentity = makeIdentity(clientID: "migrated")
    let rollback = try SharedSessionTopologyMigration.prepare(
      identity: migratedIdentity,
      destinationIdentityStore: localStore,
      destinationSlotStore: slotStore,
      destinationInstanceFingerprint: "instance",
      destinationOwnerIdentifier: "app.new"
    )
    let newerSlot = try makeSlot(
      owner: "app.new",
      generation: 99,
      identity: migratedIdentity
    )
    try slotStore.saveOwnSlot(newerSlot)

    #expect(throws: SharedSessionTopologyMigrationError.destinationSlotChanged) {
      try rollback.restore()
    }

    #expect(try slotStore.loadOwnSlot() == newerSlot)
    #expect(try localStore.load() == migratedIdentity)
  }

  @Test
  func rollbackPreservesNewerDestinationIdentityWithoutSlotPublication() throws {
    let localStore = SharedSessionLocalIdentityStore(keychain: InMemoryKeychain())
    let rollback = try SharedSessionTopologyMigration.prepare(
      identity: makeIdentity(clientID: "migrated"),
      destinationIdentityStore: localStore,
      destinationSlotStore: nil,
      destinationInstanceFingerprint: nil,
      destinationOwnerIdentifier: nil
    )
    let newerIdentity = makeIdentity(clientID: "newer")
    try localStore.save(newerIdentity)

    #expect(throws: SharedSessionTopologyMigrationError.destinationIdentityChanged) {
      try rollback.restore()
    }

    #expect(try localStore.load() == newerIdentity)
  }

  private func makeIdentity(clientID: String) -> ClerkIdentitySnapshot {
    var client = Client.mockSignedOut
    client.id = clientID
    return ClerkIdentitySnapshot(
      state: .present,
      deviceToken: "token-\(clientID)",
      client: client,
      serverDate: Date(timeIntervalSince1970: 100)
    )
  }

  private func makeSlot(
    owner: String,
    generation: UInt64,
    identity: ClerkIdentitySnapshot
  ) throws -> SharedSessionOwnerSlot {
    try SharedSessionOwnerSlot(
      schemaVersion: SharedSessionOwnerSlot.schemaVersion,
      instanceFingerprint: "instance",
      slotOwnerIdentifier: owner,
      event: SharedSessionIdentityEvent(
        id: UUID(),
        originOwnerIdentifier: owner,
        generation: generation,
        state: identity.state,
        deviceToken: identity.deviceToken,
        client: identity.client,
        serverDate: identity.serverDate
      ).validated()
    )
  }

  private func makeEvent(
    owner: String,
    generation: UInt64,
    identity: ClerkIdentitySnapshot
  ) throws -> SharedSessionIdentityEvent {
    try SharedSessionIdentityEvent(
      id: UUID(),
      originOwnerIdentifier: owner,
      generation: generation,
      state: identity.state,
      deviceToken: identity.deviceToken,
      client: identity.client,
      serverDate: identity.serverDate
    ).validated()
  }
}

private final class CommitFailingTopologyIdentityStore: SharedSessionLocalIdentityStoring, @unchecked Sendable {
  enum Failure: Error {
    case commit
  }

  private let lock = NSLock()
  private var record: SharedSessionLocalIdentityRecord?
  private var shouldFailNextCommit = true

  init(record: SharedSessionLocalIdentityRecord?) {
    self.record = record
  }

  func loadRecord() throws -> SharedSessionLocalIdentityRecord? {
    lock.withLock { record }
  }

  func updateRecord(
    _ update: (SharedSessionLocalIdentityRecord?) throws -> SharedSessionLocalIdentityRecord?
  ) throws {
    try lock.withLock {
      let updatedRecord = try update(record)
      let isCommit = record?.pendingPublication != nil
        && updatedRecord?.pendingPublication == nil
      if isCommit, shouldFailNextCommit {
        shouldFailNextCommit = false
        throw Failure.commit
      }
      record = updatedRecord
    }
  }
}

private final class TopologyOwnerSlotStore: SharedSessionSlotStoring, @unchecked Sendable {
  enum Failure: Error {
    case save
  }

  private let lock = NSLock()
  private let ownerIdentifier: String
  private var slots: [SharedSessionOwnerSlot]
  private let saveFails: Bool

  init(
    ownerIdentifier: String,
    slots: [SharedSessionOwnerSlot] = [],
    saveFails: Bool = false
  ) {
    self.ownerIdentifier = ownerIdentifier
    self.slots = slots
    self.saveFails = saveFails
  }

  func loadOwnSlot() throws -> SharedSessionOwnerSlot? {
    lock.withLock {
      slots.first { $0.slotOwnerIdentifier == ownerIdentifier }
    }
  }

  func loadAllSlots() throws -> [SharedSessionOwnerSlot] {
    lock.withLock { slots }
  }

  func saveOwnSlot(_ slot: SharedSessionOwnerSlot) throws {
    try lock.withLock {
      if saveFails { throw Failure.save }
      slots.removeAll { $0.slotOwnerIdentifier == ownerIdentifier }
      slots.append(slot)
    }
  }

  func deleteOwnSlot() throws {
    lock.withLock {
      slots.removeAll { $0.slotOwnerIdentifier == ownerIdentifier }
    }
  }
}
