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

  func cancel() {
    activeTakeover = nil
  }

  func finish(id: UUID) async {
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
