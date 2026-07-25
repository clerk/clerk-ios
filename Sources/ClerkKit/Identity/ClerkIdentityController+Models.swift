//
//  ClerkIdentityController+Models.swift
//  Clerk
//

import Foundation

extension ClerkIdentityController {
  struct PersistedClientSnapshot {
    let state: String?
    let client: Client?
    let serverDate: Date?
  }

  enum PersistedClientDecision {
    case apply
    case ignore
  }

  struct RollbackState {
    let lastAppliedResponseSequence: Int?
    let lastServerDate: Date?
  }

  struct ExternalTransition {
    let identity: ClerkIdentitySnapshot
    let fenceAllClientResponses: Bool
    let stage: @MainActor () throws -> Void
    let didApply: @MainActor () -> Void
    let didNotApply: @MainActor () -> Void

    init(
      identity: ClerkIdentitySnapshot,
      fenceAllClientResponses: Bool = true,
      stage: @escaping @MainActor () throws -> Void = {},
      didApply: @escaping @MainActor () -> Void = {},
      didNotApply: @escaping @MainActor () -> Void = {}
    ) {
      self.identity = identity
      self.fenceAllClientResponses = fenceAllClientResponses
      self.stage = stage
      self.didApply = didApply
      self.didNotApply = didNotApply
    }
  }

  struct StorageClearContext {
    let usesAtomicLocalPersistence: Bool
    let invalidatedThroughRevision: UInt64
    let requiresOwnerSlotWithdrawal: Bool
    let sharedCoordinator: SharedSessionSyncCoordinator?
  }

  enum PersistenceMode {
    case shared(SharedSessionSyncCoordinator)
    case atomicLocal(SharedSessionLocalIdentityIO)
    case legacy
  }
}
