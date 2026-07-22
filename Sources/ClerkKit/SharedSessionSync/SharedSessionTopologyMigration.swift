//
//  SharedSessionTopologyMigration.swift
//  Clerk
//

import Foundation

enum SharedSessionTopologyMigrationError: Error, Equatable {
  case destinationIdentityChanged
}

enum SharedSessionTopologyMigration {
  private struct PersistenceContext {
    let identity: ClerkIdentitySnapshot
    let event: SharedSessionIdentityEvent?
    let instanceFingerprint: String?
    let previousRecord: SharedSessionLocalIdentityRecord?
  }

  struct Rollback {
    let destinationIdentityStore: any SharedSessionLocalIdentityStoring
    let previousDestinationRecord: SharedSessionLocalIdentityRecord?
    let destinationSlotStore: (any SharedSessionSlotStoring)?
    let previousDestinationSlot: SharedSessionOwnerSlot?
    let publishedDestinationSlot: Bool

    func restore() throws {
      var firstError: (any Error)?
      if publishedDestinationSlot, let destinationSlotStore {
        do {
          if let previousDestinationSlot {
            try destinationSlotStore.saveOwnSlot(previousDestinationSlot)
          } else {
            try destinationSlotStore.deleteOwnSlot()
          }
        } catch {
          firstError = error
        }
      }
      do {
        try destinationIdentityStore.updateRecord { _ in
          previousDestinationRecord
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
    let peerSlots = destinationSlots.filter {
      $0.slotOwnerIdentifier != excludingSourceOwnerIdentifier
        && $0.slotOwnerIdentifier != destinationOwnerIdentifier
    }
    let shouldPublishDestinationSlot = destinationSlotStore != nil
      && peerSlots.isEmpty
    let destinationEvent = try shouldPublishDestinationSlot
      ? makeDestinationEvent(
        identity: identity,
        slots: destinationSlots,
        pendingPublication: previousDestinationRecord?.pendingPublication,
        ownerIdentifier: destinationOwnerIdentifier
      )
      : nil

    let rollback = Rollback(
      destinationIdentityStore: destinationIdentityStore,
      previousDestinationRecord: previousDestinationRecord,
      destinationSlotStore: destinationSlotStore,
      previousDestinationSlot: previousDestinationSlot,
      publishedDestinationSlot: shouldPublishDestinationSlot
    )

    do {
      try persist(
        PersistenceContext(
          identity: identity,
          event: destinationEvent,
          instanceFingerprint: destinationInstanceFingerprint,
          previousRecord: previousDestinationRecord
        ),
        identityStore: destinationIdentityStore,
        slotStore: destinationSlotStore
      )
      return rollback
    } catch SharedSessionTopologyMigrationError.destinationIdentityChanged {
      throw SharedSessionTopologyMigrationError.destinationIdentityChanged
    } catch {
      do {
        try rollback.restore()
      } catch let rollbackError {
        ClerkLogger.logError(
          rollbackError,
          message: "Failed to roll back shared-session topology preparation"
        )
      }
      throw error
    }
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
    slotStore: (any SharedSessionSlotStoring)?
  ) throws {
    guard let event = context.event else {
      try identityStore.updateRecord { record in
        guard record == context.previousRecord else {
          throw SharedSessionTopologyMigrationError.destinationIdentityChanged
        }
        return SharedSessionLocalIdentityRecord(
          acceptedIdentity: context.identity,
          pendingPublication: nil
        )
      }
      return
    }
    guard let slotStore, let instanceFingerprint = context.instanceFingerprint else {
      throw ClerkClientError(message: "Shared-session topology migration is missing destination slot identity.")
    }
    try identityStore.updateRecord { record in
      guard record == context.previousRecord else {
        throw SharedSessionTopologyMigrationError.destinationIdentityChanged
      }
      return SharedSessionLocalIdentityRecord(
        acceptedIdentity: record?.acceptedIdentity,
        pendingPublication: event
      )
    }
    try slotStore.saveOwnSlot(
      SharedSessionOwnerSlot(
        schemaVersion: SharedSessionOwnerSlot.schemaVersion,
        instanceFingerprint: instanceFingerprint,
        slotOwnerIdentifier: event.originOwnerIdentifier,
        event: event
      )
    )
    try identityStore.commitAcceptedIdentity(
      context.identity,
      clearingPendingPublicationID: event.id
    )
  }
}
