//
//  WatchConnectivityCoordinator+ClientUpdates.swift
//  Clerk
//

import Foundation

private enum RemoteClientUpdateDecision {
  case apply
  case refresh
  case ignore
}

private struct WatchSyncClientApplication {
  let client: Client?
  let serverFetchDate: Date?
  let isAuthoritative: Bool
  let version: WatchSyncVersion?
  let state: String
}

extension WatchConnectivityCoordinator {
  func applyClientUpdate(_ update: WatchSyncClientUpdate, from source: WatchSyncSource, to clerk: Clerk) {
    switch update {
    case .notIncluded:
      return
    case let .snapshot(client, serverFetchDate, version):
      applyClient(
        WatchSyncClientApplication(
          client: client,
          serverFetchDate: serverFetchDate,
          isAuthoritative: source.incomingDeviceIsAuthoritative,
          version: version,
          state: "set"
        ),
        to: clerk
      )
    case let .cleared(serverFetchDate, version):
      applyClient(
        WatchSyncClientApplication(
          client: nil,
          serverFetchDate: serverFetchDate,
          isAuthoritative: source.incomingDeviceIsAuthoritative,
          version: version,
          state: "cleared"
        ),
        to: clerk
      )
    }
  }

  func shouldPublishLocalAuthChange(previousClient: Client?, client: Client?, clerk: Clerk) -> Bool {
    client != nil || previousClient != nil || clerk.lastClientServerFetchDate != nil
  }

  private func applyClient(_ update: WatchSyncClientApplication, to clerk: Clerk) {
    switch remoteClientUpdateDecision(for: update, clerk: clerk) {
    case .apply:
      break
    case .refresh:
      scheduleRefresh(for: clerk)
      return
    case .ignore:
      return
    }

    if update.isAuthoritative {
      if let serverFetchDate = update.serverFetchDate {
        clerk.lastClientServerFetchDate = serverFetchDate
      }
      noteAppliedAuthState(update, keychain: clerk.dependencies.keychain)
      clerk.client = update.client
      return
    }

    if let client = update.client,
       let serverFetchDate = update.serverFetchDate,
       let lastClientServerFetchDate = clerk.lastClientServerFetchDate,
       serverFetchDate > lastClientServerFetchDate
    {
      clerk.lastClientServerFetchDate = serverFetchDate
      noteAppliedAuthState(update, keychain: clerk.dependencies.keychain)
      if client != clerk.client {
        clerk.client = client
      } else {
        clerk.cacheManager?.saveServerFetchDate(serverFetchDate)
      }
      return
    }

    guard let client = update.client else {
      applyNonAuthoritativeClear(update, to: clerk)
      return
    }

    if clerk.client != nil || clerk.lastClientServerFetchDate != nil {
      scheduleRefresh(for: clerk)
      return
    }

    clerk.lastClientServerFetchDate = update.serverFetchDate
    noteAppliedAuthState(update, keychain: clerk.dependencies.keychain)
    clerk.client = client
    scheduleRefresh(for: clerk)
  }

  private func applyNonAuthoritativeClear(_ update: WatchSyncClientApplication, to clerk: Clerk) {
    guard clerk.client == nil else {
      scheduleRefresh(for: clerk)
      return
    }

    if let serverFetchDate = update.serverFetchDate {
      clerk.lastClientServerFetchDate = serverFetchDate
    }
    noteAppliedAuthState(update, keychain: clerk.dependencies.keychain)
    if clerk.client != nil || clerk.lastClientServerFetchDate != nil {
      scheduleRefresh(for: clerk)
    }
  }

  private func remoteClientUpdateDecision(
    for update: WatchSyncClientApplication,
    clerk: Clerk
  ) -> RemoteClientUpdateDecision {
    let currentVersion = currentAuthVersion(keychain: clerk.dependencies.keychain)

    if let serverFetchDate = update.serverFetchDate,
       let lastClientServerFetchDate = clerk.lastClientServerFetchDate,
       serverFetchDate < lastClientServerFetchDate
    {
      return .ignore
    }

    if let version = update.version {
      if version < currentVersion
        || (!update.isAuthoritative && version == currentVersion && currentVersion > .initial)
      {
        return shouldRefreshForNonAuthoritativeClientConflict(update, clerk: clerk)
      }
    } else if currentVersion > .initial {
      return shouldRefreshForNonAuthoritativeClientConflict(update, clerk: clerk)
    }

    return .apply
  }

  private func shouldRefreshForNonAuthoritativeClientConflict(
    _ update: WatchSyncClientApplication,
    clerk: Clerk
  ) -> RemoteClientUpdateDecision {
    guard !update.isAuthoritative, let serverFetchDate = update.serverFetchDate else {
      return .ignore
    }

    if let lastClientServerFetchDate = clerk.lastClientServerFetchDate {
      return serverFetchDate > lastClientServerFetchDate ? .refresh : .ignore
    }

    return .refresh
  }

  private func noteAppliedAuthState(_ update: WatchSyncClientApplication, keychain: any KeychainStorage) {
    guard let version = update.version, version >= readAuthVersion(keychain: keychain) else {
      return
    }

    setAuthGeneration(version)
    do {
      try persistAuthState(update.state, version: version, keychain: keychain)
    } catch {
      ClerkLogger.logError(error, message: "Failed to persist auth sync state")
    }
  }

  private func scheduleRefresh(for clerk: Clerk) {
    guard markRefreshScheduled() else { return }

    let task = clerk.scheduleManagedTask { [weak self, weak clerk] in
      do {
        try await clerk?.refreshClient()
      } catch is CancellationError {
        // Managed cleanup cancels this task when Clerk reconfigures or resets.
      } catch {
        ClerkLogger.logError(error, message: "Failed to refresh client after watch sync")
      }
      await self?.finishScheduledRefresh()
    }

    if task == nil {
      clearRefreshScheduled()
    }
  }

  private func finishScheduledRefresh() {
    clearRefreshScheduled()
  }
}
