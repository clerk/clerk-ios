//
//  SharedSessionRecoveryReconciler.swift
//  Clerk
//

import Foundation

enum SharedSessionRecoveryReconciler {
  enum Decision: Equatable {
    case publishLocal
    case acceptShared
  }

  @MainActor
  static func prepareLocalMutationForActivation(
    identity: ClerkIdentitySnapshot,
    baseGeneration: UInt64?,
    in dependencies: any Dependencies
  ) throws -> SharedSessionTopologyMigration.Rollback? {
    let identity = try identity.validated()
    guard let identityStore = dependencies.atomicIdentityStore else {
      return nil
    }
    guard let topology = SharedSessionSlotTopology(
      dependencies: dependencies
    ) else {
      try identityStore.save(identity)
      return nil
    }

    let slotStore = try topology.makeOwnerSlotStore()
    let slots: [SharedSessionOwnerSlot]
    do {
      slots = try slotStore.loadAllSlots()
    } catch {
      let failure = PersistenceFailureKind.classify(error)
      guard failure == .temporarilyUnavailable
        || failure == .missingEntitlement
      else {
        throw error
      }
      try identityStore.saveUnpublishedLocalIdentity(
        identity,
        baseGeneration: baseGeneration
      )
      return nil
    }

    let reduction = SharedSessionIdentityReducer.reduce(slots)
    guard decision(
      local: identity,
      baseGeneration: baseGeneration,
      sharedWinner: reduction.winner
    ) == .publishLocal
    else {
      return nil
    }

    return try SharedSessionTopologyMigration.prepare(
      identity: identity,
      destinationIdentityStore: identityStore,
      destinationSlotStore: slotStore,
      destinationInstanceFingerprint: topology.instanceFingerprint,
      destinationOwnerIdentifier: topology.ownerIdentifier,
      alwaysPublishIdentity: true
    )
  }

  @MainActor
  static func preparePendingLocalMutationForActivation(
    in dependencies: any Dependencies
  ) throws -> SharedSessionTopologyMigration.Rollback? {
    guard let record = try dependencies.atomicIdentityStore?.loadRecord(),
          record.hasUnpublishedLocalMutation,
          record.pendingPublication == nil,
          let identity = record.acceptedIdentity
    else {
      return nil
    }
    return try prepareLocalMutationForActivation(
      identity: identity,
      baseGeneration: record.sharedSessionBaseGeneration,
      in: dependencies
    )
  }

  static func decision(
    local: ClerkIdentitySnapshot,
    baseGeneration: UInt64?,
    sharedWinner: SharedSessionIdentityEvent?
  ) -> Decision {
    guard let sharedWinner else { return .publishLocal }

    if let baseGeneration,
       sharedWinner.generation <= baseGeneration
    {
      return .publishLocal
    }

    switch (local.serverDate, sharedWinner.serverDate) {
    case let (.some(localDate), .some(sharedDate)):
      return localDate > sharedDate ? .publishLocal : .acceptShared
    case (.some, nil):
      return .publishLocal
    case (nil, .some):
      return .acceptShared
    case (nil, nil):
      // Without a common server timestamp or an unchanged base generation,
      // prefer the already peer-visible event. Explicit clears use their own
      // durable journal and never reach this ambiguous branch.
      return .acceptShared
    }
  }
}

extension SharedSessionLocalIdentityStoring {
  func saveUnpublishedLocalIdentity(
    _ identity: ClerkIdentitySnapshot,
    baseGeneration: UInt64?
  ) throws {
    let identity = try identity.validated()
    try updateRecord { record in
      guard record?.pendingPublication == nil else {
        throw SharedSessionLocalIdentityStoreError
          .pendingPublicationAlreadyExists
      }
      return SharedSessionLocalIdentityRecord(
        acceptedIdentity: identity,
        pendingPublication: nil,
        hasUnpublishedLocalMutation: true,
        sharedSessionBaseGeneration: baseGeneration
      )
    }
  }
}
