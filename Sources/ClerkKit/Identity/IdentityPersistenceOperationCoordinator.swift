//
//  IdentityPersistenceOperationCoordinator.swift
//  Clerk
//

import Foundation

extension Clerk {
  /// The persistence mode established for this Clerk runtime and whether
  /// identity operations may currently proceed.
  ///
  /// Identity storage and cross-app transport are independent capabilities:
  /// an app can retain durable, app-local authentication while shared-session
  /// transport is unavailable.
  public struct PersistenceStatus: Sendable, Equatable {
    public enum FailureReason: Sendable, Equatable {
      /// The underlying storage was unavailable when Clerk configured.
      case temporarilyUnavailable

      /// The application does not currently have access to the required
      /// Keychain access group.
      case missingEntitlement

      /// Persisted coordination data was written in an unsupported or invalid
      /// format.
      case incompatibleStoredData

      /// Persistence failed for a reason Clerk could not safely classify.
      case unexpected
    }

    public enum IdentityStorage: Sendable, Equatable {
      case durable
      case volatile(FailureReason)
    }

    public enum SharedSession: Sendable, Equatable {
      /// Shared-session transport is not configured.
      case disabled

      /// Shared-session transport was established for this runtime.
      ///
      /// This is not a continuous reachability signal. A later transport
      /// failure is reported by the operation that encountered it.
      case active

      /// Shared-session transport could not be established during bootstrap.
      case unavailable(FailureReason)
    }

    public enum Readiness: Sendable, Equatable {
      case ready
      case transitioning
      case blocked(PersistenceBlockReason)
    }

    public let identityStorage: IdentityStorage
    public let sharedSession: SharedSession
    public let readiness: Readiness

    init(
      identityStorage: IdentityStorage,
      sharedSession: SharedSession,
      readiness: Readiness
    ) {
      self.identityStorage = identityStorage
      self.sharedSession = sharedSession
      self.readiness = readiness
    }
  }

  /// A safety condition that prevents Clerk from exposing persisted identity.
  public enum PersistenceBlockReason: Sendable, Equatable {
    /// An explicit identity clear has not reached its durable completion boundary.
    case pendingClear

    /// Identity storage cannot currently be reached.
    case storageUnavailable

    /// Persisted coordination data cannot be interpreted safely.
    case incompatibleStoredData

    /// Persistence could not be made safe for an unexpected reason.
    case unknown
  }
}

enum PersistenceFailureKind: Equatable {
  case temporarilyUnavailable
  case missingEntitlement
  case incompatibleStoredData
  case unexpected

  var blockReason: Clerk.PersistenceBlockReason {
    switch self {
    case .temporarilyUnavailable, .missingEntitlement:
      .storageUnavailable
    case .incompatibleStoredData:
      .incompatibleStoredData
    case .unexpected:
      .unknown
    }
  }

  var publicReason: Clerk.PersistenceStatus.FailureReason {
    switch self {
    case .temporarilyUnavailable:
      .temporarilyUnavailable
    case .missingEntitlement:
      .missingEntitlement
    case .incompatibleStoredData:
      .incompatibleStoredData
    case .unexpected:
      .unexpected
    }
  }
}

enum IdentityPersistenceCapability: Equatable {
  case durable
  case volatile(PersistenceFailureKind)
}

enum SharedSessionCapability: Equatable {
  case disabled
  case active
  case unavailable(PersistenceFailureKind)
}

enum PersistenceOperationKind: Equatable {
  case bootstrap
  case clear
  case reconfigure
}

struct PersistenceTransitionOwnership: Equatable {
  let id: UUID
  let configurationEpoch: ClerkConfigurationEpoch
}

struct ActivePersistenceOperation: Equatable {
  let kind: PersistenceOperationKind
  let ownership: PersistenceTransitionOwnership
}

enum PersistenceTransitionState: Equatable {
  case ready
  case running(ActivePersistenceOperation)
  case blocked(Clerk.PersistenceBlockReason)
}

@MainActor
final class IdentityPersistenceOperationCoordinator {
  private weak var clerk: Clerk?

  private(set) var identityCapability: IdentityPersistenceCapability = .durable
  private(set) var sharedSessionCapability: SharedSessionCapability = .disabled
  private(set) var transitionState: PersistenceTransitionState = .ready

  init(clerk: Clerk) {
    self.clerk = clerk
  }

  var isIdentityReady: Bool {
    if case .ready = transitionState {
      true
    } else {
      false
    }
  }

  var isClearPending: Bool {
    if case .running(let operation) = transitionState,
       operation.kind == .clear
    {
      true
    } else if case .blocked(.pendingClear) = transitionState {
      true
    } else {
      false
    }
  }

  @discardableResult
  func beginBootstrap(
    epoch: ClerkConfigurationEpoch
  ) -> PersistenceTransitionOwnership {
    begin(.bootstrap, epoch: epoch)
  }

  @discardableResult
  func beginClear(
    epoch: ClerkConfigurationEpoch
  ) throws -> PersistenceTransitionOwnership {
    if case .running(let operation) = transitionState,
       operation.kind == .clear
    {
      throw ClerkClientError(
        message: "Clerk identity storage is already completing an explicit clear."
      )
    }
    return begin(.clear, epoch: epoch)
  }

  @discardableResult
  func beginReconfiguration(
    epoch: ClerkConfigurationEpoch
  ) throws -> PersistenceTransitionOwnership {
    guard !isClearPending else {
      throw ClerkClientError(
        message: "Clerk identity storage is still completing an explicit clear."
      )
    }
    return begin(.reconfigure, epoch: epoch)
  }

  func setSharedSessionCapability(_ capability: SharedSessionCapability) {
    sharedSessionCapability = capability
    publishStatus()
  }

  func finish(_ ownership: PersistenceTransitionOwnership) {
    guard owns(ownership) else { return }
    transitionState = .ready
    publishStatus()
  }

  func block(
    _ ownership: PersistenceTransitionOwnership?,
    reason: Clerk.PersistenceBlockReason
  ) {
    if let ownership, !owns(ownership) {
      return
    }
    transitionState = .blocked(reason)
    publishStatus()
  }

  func reset(
    identityCapability: IdentityPersistenceCapability,
    sharedSessionCapability: SharedSessionCapability
  ) {
    self.identityCapability = identityCapability
    self.sharedSessionCapability = sharedSessionCapability
    transitionState = .ready
    publishStatus()
  }

  func cancelActiveTransition() {
    transitionState = .ready
    publishStatus()
  }

  func validate(
    _ ownership: PersistenceTransitionOwnership,
    operation expectedKind: PersistenceOperationKind,
    expectedEpoch: ClerkConfigurationEpoch? = nil
  ) throws {
    try Task.checkCancellation()
    guard case .running(let activeOperation) = transitionState,
          activeOperation.kind == expectedKind,
          activeOperation.ownership == ownership,
          let clerk,
          clerk.configurationEpoch == (expectedEpoch ?? ownership.configurationEpoch)
    else {
      throw CancellationError()
    }
  }

  func isActive(
    _ ownership: PersistenceTransitionOwnership,
    operation expectedKind: PersistenceOperationKind
  ) -> Bool {
    guard case .running(let activeOperation) = transitionState else {
      return false
    }
    return activeOperation.kind == expectedKind
      && activeOperation.ownership == ownership
  }

  func requireIdentityOperationsAvailable() throws {
    switch transitionState {
    case .ready:
      return
    case .running:
      throw ClerkClientError(
        message: "Clerk identity persistence is still preparing."
      )
    case .blocked(.pendingClear):
      throw ClerkClientError(
        message: "Clerk identity storage is still completing an explicit clear."
      )
    case .blocked:
      throw ClerkClientError(
        message: "Clerk identity persistence is unavailable."
      )
    }
  }

  private func begin(
    _ kind: PersistenceOperationKind,
    epoch: ClerkConfigurationEpoch
  ) -> PersistenceTransitionOwnership {
    let ownership = PersistenceTransitionOwnership(
      id: UUID(),
      configurationEpoch: epoch
    )
    transitionState = .running(
      ActivePersistenceOperation(kind: kind, ownership: ownership)
    )
    publishStatus()
    return ownership
  }

  private func owns(
    _ ownership: PersistenceTransitionOwnership
  ) -> Bool {
    guard case .running(let activeOperation) = transitionState else {
      return false
    }
    return activeOperation.ownership == ownership
  }

  private func publishStatus() {
    guard let clerk else { return }
    let identityStorage: Clerk.PersistenceStatus.IdentityStorage = switch identityCapability {
    case .durable:
      .durable
    case .volatile(let failure):
      .volatile(failure.publicReason)
    }
    let sharedSession: Clerk.PersistenceStatus.SharedSession = switch sharedSessionCapability {
    case .disabled:
      .disabled
    case .active:
      .active
    case .unavailable(let failure):
      .unavailable(failure.publicReason)
    }
    let readiness: Clerk.PersistenceStatus.Readiness = switch transitionState {
    case .ready:
      .ready
    case .running:
      .transitioning
    case .blocked(let reason):
      .blocked(reason)
    }
    clerk.persistenceStatus = .init(
      identityStorage: identityStorage,
      sharedSession: sharedSession,
      readiness: readiness
    )
  }
}
