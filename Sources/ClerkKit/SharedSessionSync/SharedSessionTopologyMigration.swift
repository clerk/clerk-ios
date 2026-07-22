//
//  SharedSessionTopologyMigration.swift
//  Clerk
//

import Foundation

enum SharedSessionTopologyMigrationError: Error, Equatable {
  case destinationIdentityChanged
  case destinationSlotChanged
}

private enum TopologyMigrationPreparationError: Error {
  case destinationChangedBeforeWrite
}

enum SharedSessionTopologyMigration {
  private struct PersistenceContext {
    let identity: ClerkIdentitySnapshot
    let event: SharedSessionIdentityEvent?
    let previousRecord: SharedSessionLocalIdentityRecord?
  }

  private struct DestinationTopology {
    let hasSlotStore: Bool
    let instanceFingerprint: String?
    let ownerIdentifier: String?
    let excludedOwnerIdentifier: String?
  }

  private struct PreparedDestination {
    let event: SharedSessionIdentityEvent?
    let slot: SharedSessionOwnerSlot?
    let migratedRecord: SharedSessionLocalIdentityRecord
    let stagedRecord: SharedSessionLocalIdentityRecord?
  }

  struct Rollback {
    let destinationIdentityStore: any SharedSessionLocalIdentityStoring
    let previousDestinationRecord: SharedSessionLocalIdentityRecord?
    let migratedDestinationRecord: SharedSessionLocalIdentityRecord
    let destinationSlotStore: (any SharedSessionSlotStoring)?
    let previousDestinationSlot: SharedSessionOwnerSlot?
    let publishedDestinationSlot: SharedSessionOwnerSlot?

    func restore() throws {
      try restore(
        whenIdentityMatches: [migratedDestinationRecord],
        abortOnSlotConflict: true
      )
    }

    fileprivate func restoreAfterPreparationFailure(
      stagedDestinationRecord: SharedSessionLocalIdentityRecord?
    ) throws {
      try restore(
        whenIdentityMatches: [
          stagedDestinationRecord,
          migratedDestinationRecord,
        ].compactMap { $0 },
        abortOnSlotConflict: false
      )
    }

    private func restore(
      whenIdentityMatches ownedDestinationRecords: [SharedSessionLocalIdentityRecord],
      abortOnSlotConflict: Bool
    ) throws {
      var firstError: (any Error)?
      if let publishedDestinationSlot, let destinationSlotStore {
        do {
          guard try destinationSlotStore.restoreOwnSlot(
            previousDestinationSlot,
            ifCurrentMatchesPublication: publishedDestinationSlot
          ) else {
            throw SharedSessionTopologyMigrationError.destinationSlotChanged
          }
        } catch let error as SharedSessionTopologyMigrationError {
          if abortOnSlotConflict {
            throw error
          }
          firstError = error
        } catch {
          firstError = error
        }
      }
      do {
        try destinationIdentityStore.updateRecord { record in
          guard ownedDestinationRecords.contains(where: { record == $0 }) else {
            throw SharedSessionTopologyMigrationError.destinationIdentityChanged
          }
          return previousDestinationRecord
        }
      } catch {
        firstError = firstError ?? error
      }
      if let firstError {
        throw firstError
      }
    }
  }

  static func prepare(
    identity: ClerkIdentitySnapshot,
    destinationIdentityStore: any SharedSessionLocalIdentityStoring,
    destinationSlotStore: (any SharedSessionSlotStoring)?,
    destinationInstanceFingerprint: String?,
    destinationOwnerIdentifier: String?,
    excludingSourceOwnerIdentifier: String? = nil
  ) throws -> Rollback {
    let identity = try identity.validated()
    let previousDestinationRecord = try destinationIdentityStore.loadRecord()
    let previousDestinationSlot = try destinationSlotStore?.loadOwnSlot()
    let destinationSlots = try destinationSlotStore?.loadAllSlots() ?? []
    let destination = try makePreparedDestination(
      identity: identity,
      previousRecord: previousDestinationRecord,
      slots: destinationSlots,
      topology: DestinationTopology(
        hasSlotStore: destinationSlotStore != nil,
        instanceFingerprint: destinationInstanceFingerprint,
        ownerIdentifier: destinationOwnerIdentifier,
        excludedOwnerIdentifier: excludingSourceOwnerIdentifier
      )
    )

    let rollback = Rollback(
      destinationIdentityStore: destinationIdentityStore,
      previousDestinationRecord: previousDestinationRecord,
      migratedDestinationRecord: destination.migratedRecord,
      destinationSlotStore: destinationSlotStore,
      previousDestinationSlot: previousDestinationSlot,
      publishedDestinationSlot: destination.slot
    )

    do {
      try persist(
        PersistenceContext(
          identity: identity,
          event: destination.event,
          previousRecord: previousDestinationRecord
        ),
        identityStore: destinationIdentityStore,
        slotStore: destinationSlotStore,
        destinationSlot: destination.slot
      )
      return rollback
    } catch TopologyMigrationPreparationError.destinationChangedBeforeWrite {
      throw SharedSessionTopologyMigrationError.destinationIdentityChanged
    } catch {
      do {
        try rollback.restoreAfterPreparationFailure(
          stagedDestinationRecord: destination.stagedRecord
        )
      } catch let rollbackError {
        ClerkLogger.logError(
          rollbackError,
          message: "Failed to roll back shared-session topology preparation"
        )
      }
      throw error
    }
  }

  private static func makePreparedDestination(
    identity: ClerkIdentitySnapshot,
    previousRecord: SharedSessionLocalIdentityRecord?,
    slots: [SharedSessionOwnerSlot],
    topology: DestinationTopology
  ) throws -> PreparedDestination {
    let hasPeerSlot = slots.contains {
      $0.slotOwnerIdentifier != topology.excludedOwnerIdentifier
        && $0.slotOwnerIdentifier != topology.ownerIdentifier
    }
    let event = try topology.hasSlotStore && !hasPeerSlot
      ? makeDestinationEvent(
        identity: identity,
        slots: slots,
        pendingPublication: previousRecord?.pendingPublication,
        ownerIdentifier: topology.ownerIdentifier
      )
      : nil
    return try PreparedDestination(
      event: event,
      slot: makeDestinationSlot(
        event: event,
        instanceFingerprint: topology.instanceFingerprint
      ),
      migratedRecord: SharedSessionLocalIdentityRecord(
        acceptedIdentity: identity,
        pendingPublication: nil
      ),
      stagedRecord: event.map {
        SharedSessionLocalIdentityRecord(
          acceptedIdentity: previousRecord?.acceptedIdentity,
          pendingPublication: $0
        )
      }
    )
  }

  private static func makeDestinationSlot(
    event: SharedSessionIdentityEvent?,
    instanceFingerprint: String?
  ) throws -> SharedSessionOwnerSlot? {
    guard let event else { return nil }
    guard let instanceFingerprint else {
      throw ClerkClientError(message: "Shared-session topology migration is missing destination slot identity.")
    }
    return SharedSessionOwnerSlot(
      schemaVersion: SharedSessionOwnerSlot.schemaVersion,
      instanceFingerprint: instanceFingerprint,
      slotOwnerIdentifier: event.originOwnerIdentifier,
      event: event
    )
  }

  private static func makeDestinationEvent(
    identity: ClerkIdentitySnapshot,
    slots: [SharedSessionOwnerSlot],
    pendingPublication: SharedSessionIdentityEvent?,
    ownerIdentifier: String?
  ) throws -> SharedSessionIdentityEvent {
    guard let ownerIdentifier else {
      throw ClerkClientError(message: "Shared-session topology migration is missing destination slot identity.")
    }
    return try SharedSessionIdentityEvent(
      id: UUID(),
      originOwnerIdentifier: ownerIdentifier,
      generation: SharedSessionIdentityEvent.nextGeneration(
        after: max(
          SharedSessionIdentityReducer.reduce(slots).maximumGeneration,
          pendingPublication?.generation ?? 0
        )
      ),
      state: identity.state,
      deviceToken: identity.deviceToken,
      client: identity.client,
      serverDate: identity.serverDate
    ).validated()
  }

  private static func persist(
    _ context: PersistenceContext,
    identityStore: any SharedSessionLocalIdentityStoring,
    slotStore: (any SharedSessionSlotStoring)?,
    destinationSlot: SharedSessionOwnerSlot?
  ) throws {
    guard let event = context.event else {
      try identityStore.updateRecord { record in
        guard record == context.previousRecord else {
          throw TopologyMigrationPreparationError.destinationChangedBeforeWrite
        }
        return SharedSessionLocalIdentityRecord(
          acceptedIdentity: context.identity,
          pendingPublication: nil
        )
      }
      return
    }
    guard let slotStore, let destinationSlot else {
      throw ClerkClientError(message: "Shared-session topology migration is missing destination slot identity.")
    }
    try identityStore.updateRecord { record in
      guard record == context.previousRecord else {
        throw TopologyMigrationPreparationError.destinationChangedBeforeWrite
      }
      return SharedSessionLocalIdentityRecord(
        acceptedIdentity: record?.acceptedIdentity,
        pendingPublication: event
      )
    }
    try slotStore.saveOwnSlot(destinationSlot)
    try identityStore.commitAcceptedIdentity(
      context.identity,
      clearingPendingPublicationID: event.id
    )
  }
}
