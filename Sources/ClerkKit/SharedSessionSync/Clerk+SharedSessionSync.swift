//
//  Clerk+SharedSessionSync.swift
//  Clerk
//

import Foundation

private struct SharedSessionSyncClientSnapshot {
  let state: String?
  let client: Client?
  let serverFetchDate: Date?
}

enum SharedSessionSyncClientReloadResult: Equatable {
  case changed
  case unchanged
  case rejectedStale
}

private enum SharedSessionSyncClientSnapshotDecision {
  case apply
  case ignore
  case rejectStale
}

extension Clerk {
  /// Reloads persisted Clerk auth state from shared storage.
  ///
  /// Use this when another app that shares the same Clerk Keychain service and access group
  /// may have changed auth state while this app was running or suspended.
  ///
  /// - Returns: `true` when in-memory Clerk state changed.
  @discardableResult
  public func reloadFromSharedStorage() async -> Bool {
    if let sharedSessionSyncCoordinator {
      return sharedSessionSyncCoordinator.reloadFromSharedStorage(force: true, to: self)
    }

    var didChange = false
    if applySharedSessionSyncClientSnapshot() == .changed {
      didChange = true
    }
    if applySharedSessionSyncEnvironmentSnapshot() {
      didChange = true
    }
    return didChange
  }

  @discardableResult
  func applySharedSessionSyncClientSnapshot() -> SharedSessionSyncClientReloadResult {
    do {
      return try applySharedSessionSyncClientSnapshot(loadSharedSessionSyncClientSnapshot())
    } catch {
      ClerkLogger.logError(error, message: "Failed to reload shared Clerk client state")
      return .unchanged
    }
  }

  @discardableResult
  func applySharedSessionSyncEnvironmentSnapshot() -> Bool {
    do {
      guard let environmentData = try dependencies.keychain.data(forKey: ClerkKeychainKey.cachedEnvironment.rawValue) else {
        return false
      }

      let incomingEnvironment = try JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: environmentData)
      guard incomingEnvironment != environment else {
        return false
      }

      environment = incomingEnvironment
      return true
    } catch {
      ClerkLogger.logError(error, message: "Failed to reload shared Clerk environment state")
      return false
    }
  }

  private func loadSharedSessionSyncClientSnapshot() throws -> SharedSessionSyncClientSnapshot {
    let keychain = dependencies.keychain
    let state = try keychain.string(forKey: ClerkKeychainKey.sharedSessionSyncAuthState.rawValue)
    let serverFetchDate = try loadSharedSessionSyncClientServerFetchDate()

    guard let clientData = try keychain.data(forKey: ClerkKeychainKey.cachedClient.rawValue) else {
      return SharedSessionSyncClientSnapshot(state: state, client: nil, serverFetchDate: serverFetchDate)
    }

    let client = try JSONDecoder.clerkDecoder.decode(Client.self, from: clientData)
    return SharedSessionSyncClientSnapshot(state: state, client: client, serverFetchDate: serverFetchDate)
  }

  private func loadSharedSessionSyncClientServerFetchDate() throws -> Date? {
    guard let dateString = try dependencies.keychain.string(forKey: ClerkKeychainKey.cachedClientServerDate.rawValue),
          let timeInterval = TimeInterval(dateString)
    else {
      return nil
    }

    return Date(timeIntervalSince1970: timeInterval)
  }

  @discardableResult
  private func applySharedSessionSyncClientSnapshot(_ snapshot: SharedSessionSyncClientSnapshot) throws -> SharedSessionSyncClientReloadResult {
    if snapshot.state == "cleared" || (snapshot.client == nil && snapshot.serverFetchDate != nil) {
      return applySharedSessionSyncClientClear(serverFetchDate: snapshot.serverFetchDate)
    }

    guard let incomingClient = snapshot.client else {
      return .unchanged
    }

    switch sharedSessionSyncClientDecision(for: incomingClient, serverFetchDate: snapshot.serverFetchDate) {
    case .apply:
      let previousServerFetchDate = lastClientServerFetchDate
      if let serverFetchDate = snapshot.serverFetchDate {
        lastClientServerFetchDate = serverFetchDate
      }

      if incomingClient != client {
        client = incomingClient
        return .changed
      }

      if previousServerFetchDate != lastClientServerFetchDate, let serverFetchDate = lastClientServerFetchDate {
        cacheManager?.saveServerFetchDate(serverFetchDate)
        return .changed
      }

      return .unchanged
    case .ignore:
      return .unchanged
    case .rejectStale:
      return .rejectedStale
    }
  }

  @discardableResult
  private func applySharedSessionSyncClientClear(serverFetchDate: Date?) -> SharedSessionSyncClientReloadResult {
    switch sharedSessionSyncClientClearDecision(serverFetchDate: serverFetchDate) {
    case .apply:
      let previousClient = client
      let previousServerFetchDate = lastClientServerFetchDate

      lastClientServerFetchDate = serverFetchDate
      if client != nil {
        client = nil
      } else if previousServerFetchDate != lastClientServerFetchDate {
        cacheManager?.deleteClient(serverFetchDate: lastClientServerFetchDate)
      }

      return previousClient != nil || previousServerFetchDate != lastClientServerFetchDate
        ? .changed
        : .unchanged
    case .ignore:
      return .unchanged
    case .rejectStale:
      return .rejectedStale
    }
  }

  private func sharedSessionSyncClientDecision(
    for incomingClient: Client,
    serverFetchDate: Date?
  ) -> SharedSessionSyncClientSnapshotDecision {
    guard let client else {
      return .apply
    }

    if let serverFetchDate, let lastClientServerFetchDate {
      if serverFetchDate > lastClientServerFetchDate {
        return .apply
      }

      if serverFetchDate < lastClientServerFetchDate {
        return .rejectStale
      }

      return incomingClient.updatedAt > client.updatedAt || incomingClient != client
        ? .apply
        : .ignore
    }

    if serverFetchDate != nil {
      return .apply
    }

    guard lastClientServerFetchDate == nil else {
      return .rejectStale
    }

    if incomingClient.updatedAt > client.updatedAt {
      return .apply
    }

    return incomingClient == client ? .ignore : .rejectStale
  }

  private func sharedSessionSyncClientClearDecision(serverFetchDate: Date?) -> SharedSessionSyncClientSnapshotDecision {
    guard let serverFetchDate, let lastClientServerFetchDate else {
      return client != nil || lastClientServerFetchDate != serverFetchDate
        ? .apply
        : .ignore
    }

    if serverFetchDate > lastClientServerFetchDate
      || (serverFetchDate == lastClientServerFetchDate && client != nil)
    {
      return .apply
    }

    return serverFetchDate < lastClientServerFetchDate ? .rejectStale : .ignore
  }
}
