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
  @discardableResult
  func applyClientUpdate(_ update: WatchSyncClientUpdate, from source: WatchSyncSource, to clerk: Clerk) -> Bool {
    guard let application = clientApplication(for: update, from: source) else { return false }
    return applyClient(application, to: clerk)
  }

  func willApplyClientUpdate(_ update: WatchSyncClientUpdate, from source: WatchSyncSource, to clerk: Clerk) -> Bool {
    guard let application = clientApplication(for: update, from: source) else { return false }
    return willApplyClient(application, to: clerk)
  }

  func shouldPublishLocalAuthChange(previousClient: Client?, client: Client?, clerk: Clerk) -> Bool {
    client != nil || previousClient != nil || clerk.lastClientServerFetchDate != nil
  }

  private func applyClient(_ update: WatchSyncClientApplication, to clerk: Clerk) -> Bool {
    switch remoteClientUpdateDecision(for: update, clerk: clerk) {
    case .apply:
      break
    case .refresh:
      scheduleRefresh(for: clerk)
      return false
    case .ignore:
      return false
    }

    if update.isAuthoritative {
      if let serverFetchDate = update.serverFetchDate {
        clerk.lastClientServerFetchDate = serverFetchDate
      }
      noteAppliedAuthState(update, keychain: clerk.dependencies.watchSyncKeychain)
      clerk.client = update.client
      return true
    }

    if let client = update.client,
       let serverFetchDate = update.serverFetchDate,
       let lastClientServerFetchDate = clerk.lastClientServerFetchDate,
       serverFetchDate > lastClientServerFetchDate
    {
      clerk.lastClientServerFetchDate = serverFetchDate
      noteAppliedAuthState(update, keychain: clerk.dependencies.watchSyncKeychain)
      if client != clerk.client {
        clerk.client = client
      } else {
        clerk.cacheManager?.saveServerFetchDate(serverFetchDate)
      }
      return true
    }

    guard let client = update.client else {
      return applyNonAuthoritativeClear(update, to: clerk)
    }

    if clerk.client != nil || clerk.lastClientServerFetchDate != nil {
      scheduleRefresh(for: clerk)
      return false
    }

    clerk.lastClientServerFetchDate = update.serverFetchDate
    noteAppliedAuthState(update, keychain: clerk.dependencies.watchSyncKeychain)
    clerk.client = client
    scheduleRefresh(for: clerk)
    return true
  }

  private func applyNonAuthoritativeClear(_ update: WatchSyncClientApplication, to clerk: Clerk) -> Bool {
    guard clerk.client == nil else {
      scheduleRefresh(for: clerk)
      return false
    }

    if let serverFetchDate = update.serverFetchDate {
      clerk.lastClientServerFetchDate = serverFetchDate
    }
    noteAppliedAuthState(update, keychain: clerk.dependencies.watchSyncKeychain)
    if clerk.client != nil || clerk.lastClientServerFetchDate != nil {
      scheduleRefresh(for: clerk)
    }
    return true
  }

  private func willApplyClient(_ update: WatchSyncClientApplication, to clerk: Clerk) -> Bool {
    switch remoteClientUpdateDecision(for: update, clerk: clerk) {
    case .apply:
      update.isAuthoritative || willApplyNonAuthoritativeClient(update, to: clerk)
    case .refresh, .ignore:
      false
    }
  }

  private func willApplyNonAuthoritativeClient(_ update: WatchSyncClientApplication, to clerk: Clerk) -> Bool {
    guard update.client != nil else {
      return clerk.client == nil
    }

    if let serverFetchDate = update.serverFetchDate,
       clerk.lastClientServerFetchDate.map({ serverFetchDate > $0 }) == true
    {
      return true
    }

    return clerk.client == nil && clerk.lastClientServerFetchDate == nil
  }

  private func remoteClientUpdateDecision(
    for update: WatchSyncClientApplication,
    clerk: Clerk
  ) -> RemoteClientUpdateDecision {
    let currentVersion = currentAuthVersion(keychain: clerk.dependencies.watchSyncKeychain)

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

  private func clientApplication(
    for update: WatchSyncClientUpdate,
    from source: WatchSyncSource
  ) -> WatchSyncClientApplication? {
    switch update {
    case .notIncluded:
      nil
    case let .snapshot(client, serverFetchDate, version):
      WatchSyncClientApplication(
        client: client,
        serverFetchDate: serverFetchDate,
        isAuthoritative: source.incomingDeviceIsAuthoritative,
        version: version,
        state: "set"
      )
    case let .cleared(serverFetchDate, version):
      WatchSyncClientApplication(
        client: nil,
        serverFetchDate: serverFetchDate,
        isAuthoritative: source.incomingDeviceIsAuthoritative,
        version: version,
        state: "cleared"
      )
    }
  }
}
