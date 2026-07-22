import Foundation

/// Coordinates temporary ownership of configure-time client loading by
/// tokenless authentication requests.
@MainActor
final class StartupClientRefreshTakeover {
  private struct Checkpoint: Equatable {
    let clientResponseGeneration: ClientResponseGeneration
    let deviceToken: String?
    let client: Client?
    let serverDate: Date?
  }

  private struct ActiveTakeover {
    let checkpoint: Checkpoint
    var requestIDs: Set<UUID>
  }

  private weak var clerk: Clerk?
  private var activeTakeover: ActiveTakeover?

  init(clerk: Clerk) {
    self.clerk = clerk
  }

  func beginIfNeeded(id: UUID?, deviceToken: String?) {
    guard deviceToken == nil,
          let id,
          let clerk
    else {
      return
    }

    if var activeTakeover {
      activeTakeover.requestIDs.insert(id)
      self.activeTakeover = activeTakeover
      return
    }

    guard clerk.cancelStartupClientRefreshTask() else { return }
    clerk.identityController.fenceClientResponses()
    activeTakeover = ActiveTakeover(
      checkpoint: checkpoint(deviceToken: deviceToken, clerk: clerk),
      requestIDs: [id]
    )
  }

  func finish(id: UUID) async {
    guard let clerk,
          activeTakeover?.requestIDs.contains(id) == true
    else {
      return
    }

    if let coordinator = clerk.sharedSessionSyncCoordinator {
      let task = coordinator.enqueueSerializedLocalIdentityOperation { [weak self] in
        guard let self else { throw CancellationError() }
        finishSerialized(id: id)
      }
      await finish(task: task, id: id)
    } else if clerk.dependencies.atomicIdentityIO != nil {
      let task = clerk.identityController.enqueueLocalOperation { [weak self] _ in
        guard let self else { throw CancellationError() }
        finishSerialized(id: id)
      }
      await finish(task: task, id: id)
    } else {
      finishSerialized(id: id)
    }
  }

  func cancel() {
    activeTakeover = nil
  }

  private func finish(task: Task<Void, Error>, id: UUID) async {
    do {
      try await task.value
    } catch {
      guard activeTakeover?.requestIDs.contains(id) == true else { return }
      ClerkLogger.logError(
        error,
        message: "Failed to serialize startup client refresh takeover completion"
      )
      finishSerialized(id: id)
    }
  }

  private func finishSerialized(id: UUID) {
    guard let clerk,
          var activeTakeover,
          activeTakeover.requestIDs.remove(id) != nil
    else {
      return
    }

    guard activeTakeover.requestIDs.isEmpty else {
      self.activeTakeover = activeTakeover
      return
    }

    self.activeTakeover = nil
    guard checkpoint(
      deviceToken: clerk.identityController.currentDeviceToken,
      clerk: clerk
    ) == activeTakeover.checkpoint else {
      return
    }
    clerk.startStartupClientRefreshIfNeeded()
  }

  private func checkpoint(deviceToken: String?, clerk: Clerk) -> Checkpoint {
    Checkpoint(
      clientResponseGeneration: clerk.clientResponseGeneration,
      deviceToken: deviceToken,
      client: clerk.client,
      serverDate: clerk.lastClientServerFetchDate
    )
  }
}

extension ClerkIdentityController {
  func captureRequestIdentity(
    startupClientRefreshTakeoverID: UUID? = nil
  ) async throws -> ClerkIdentityRequestSnapshot {
    guard let clerk else { throw CancellationError() }
    if let coordinator = clerk.sharedSessionSyncCoordinator {
      try await coordinator.waitForInitialReconciliation()
      await waitForPendingLocalOperations()
      return try await coordinator.captureRequestIdentity(
        startupClientRefreshTakeoverID: startupClientRefreshTakeoverID
      )
    }

    if clerk.dependencies.atomicIdentityIO != nil {
      let task = enqueueLocalOperation { [weak self] _ in
        guard let self else { throw CancellationError() }
        return try captureSerializedRequestIdentity(
          baseGeneration: 0,
          deviceToken: localDeviceToken,
          startupClientRefreshTakeoverID: startupClientRefreshTakeoverID
        )
      }
      return try await task.value
    }

    return try captureSerializedRequestIdentity(
      baseGeneration: 0,
      deviceToken: currentDeviceToken,
      startupClientRefreshTakeoverID: startupClientRefreshTakeoverID
    )
  }

  func captureSerializedRequestIdentity(
    baseGeneration: UInt64,
    deviceToken: String?,
    startupClientRefreshTakeoverID: UUID?
  ) throws -> ClerkIdentityRequestSnapshot {
    guard let clerk else { throw CancellationError() }
    let deviceToken = deviceToken.nilIfEmpty
    clerk.startupClientRefreshTakeover.beginIfNeeded(
      id: startupClientRefreshTakeoverID,
      deviceToken: deviceToken
    )
    return ClerkIdentityRequestSnapshot(
      baseGeneration: baseGeneration,
      deviceToken: deviceToken,
      clientID: clerk.client?.id,
      clientResponseGeneration: clientResponseGeneration
    )
  }
}
