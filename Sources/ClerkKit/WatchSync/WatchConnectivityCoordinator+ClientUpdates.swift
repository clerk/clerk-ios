//
//  WatchConnectivityCoordinator+ClientUpdates.swift
//  Clerk
//

import Foundation

extension WatchConnectivityCoordinator {
  func shouldPublishLocalAuthChange(previousClient: Client?, client: Client?, clerk: Clerk) -> Bool {
    client != nil || previousClient != nil || clerk.lastClientServerFetchDate != nil
  }

  func scheduleRefresh(for clerk: Clerk) {
    let taskID = UUID()
    guard markRefreshScheduled(taskID) else { return }

    let task = clerk.scheduleManagedTask { [weak self, weak clerk] in
      do {
        try await clerk?.refreshClient()
      } catch is CancellationError {
        // Managed cleanup cancels this task when Clerk reconfigures or resets.
      } catch {
        ClerkLogger.logError(error, message: "Failed to refresh client after watch sync")
      }
      await self?.finishScheduledRefresh(taskID)
    }
    setRefreshTask(task, taskID: taskID)

    if task == nil {
      clearRefreshScheduled(taskID)
    }
  }

  private func finishScheduledRefresh(_ taskID: UUID) {
    clearRefreshScheduled(taskID)
  }
}
