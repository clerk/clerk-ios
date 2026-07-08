//
//  SharedSessionSyncCoordinator.swift
//  Clerk
//

import Foundation

@MainActor
final class SharedSessionSyncCoordinator: ClerkInternalStateChangeObserver {
  private let notifier: any SharedSessionSyncNotifying
  private weak var clerk: Clerk?
  private var authGeneration: SharedSessionSyncVersion
  private var environmentGeneration: SharedSessionSyncVersion
  private var deviceTokenGeneration: SharedSessionSyncVersion
  private var isApplyingSharedStorage = false

  init(
    keychainConfig: Clerk.Options.KeychainConfig,
    clerk: Clerk,
    keychain: any KeychainStorage,
    notifier: (any SharedSessionSyncNotifying)? = nil
  ) {
    self.notifier = notifier ?? SharedSessionSyncDarwinNotifier(keychainConfig: keychainConfig)
    self.clerk = clerk
    authGeneration = Self.readVersion(forKey: .sharedSessionSyncAuthVersion, keychain: keychain)
    environmentGeneration = Self.readVersion(forKey: .sharedSessionSyncEnvironmentVersion, keychain: keychain)
    deviceTokenGeneration = Self.readVersion(forKey: .sharedSessionSyncDeviceTokenVersion, keychain: keychain)

    self.notifier.setHandler { [weak self] in
      self?.reloadFromSharedStorageIfNeeded()
    }
  }

  func handle(_ change: ClerkInternalStateChange, from clerk: Clerk) throws {
    switch change {
    case let .clientDidChange(previousClient, client):
      guard !isApplyingSharedStorage,
            shouldPublishLocalAuthChange(previousClient: previousClient, client: client, clerk: clerk)
      else {
        return
      }

      try persistAuthSnapshot(from: clerk, version: .makeWriteRevision())
      notifier.post()

    case .environmentDidChange:
      guard !isApplyingSharedStorage else { return }
      try persistEnvironmentSnapshot(from: clerk, version: .makeWriteRevision())
      notifier.post()

    case let .deviceTokenDidChange(previousToken, token):
      guard !isApplyingSharedStorage, previousToken != token else { return }
      try persistDeviceTokenState("set", version: .makeWriteRevision(), keychain: clerk.dependencies.keychain)
      notifier.post()

    case .applicationDidEnterForeground:
      reloadFromSharedStorageIfNeeded(clerk: clerk)
    }
  }

  @discardableResult
  func reloadFromSharedStorage(force: Bool = false, to clerk: Clerk) -> Bool {
    let keychain = clerk.dependencies.keychain
    let incomingAuthVersion = Self.readVersion(forKey: .sharedSessionSyncAuthVersion, keychain: keychain)
    let incomingEnvironmentVersion = Self.readVersion(forKey: .sharedSessionSyncEnvironmentVersion, keychain: keychain)
    let incomingDeviceTokenVersion = Self.readVersion(forKey: .sharedSessionSyncDeviceTokenVersion, keychain: keychain)
    let authVersionChanged = incomingAuthVersion != authGeneration
    let environmentVersionChanged = incomingEnvironmentVersion != environmentGeneration
    let deviceTokenVersionChanged = incomingDeviceTokenVersion != deviceTokenGeneration

    guard force
      || authVersionChanged
      || environmentVersionChanged
      || deviceTokenVersionChanged
    else {
      return false
    }

    let wasApplyingSharedStorage = isApplyingSharedStorage
    isApplyingSharedStorage = true
    defer { isApplyingSharedStorage = wasApplyingSharedStorage }

    var didChange = false

    if deviceTokenVersionChanged {
      deviceTokenGeneration = incomingDeviceTokenVersion
      clerk.fenceClientResponsesAfterDeviceTokenChange()
      didChange = true
    }

    if force || authVersionChanged {
      switch clerk.applySharedSessionSyncClientSnapshot() {
      case .changed:
        didChange = true
        authGeneration = incomingAuthVersion
      case .unchanged:
        authGeneration = incomingAuthVersion
      case .rejectedStale:
        repairSharedAuthSnapshot(from: clerk)
      }
    }

    if force || environmentVersionChanged {
      if clerk.applySharedSessionSyncEnvironmentSnapshot() {
        didChange = true
      }
      environmentGeneration = incomingEnvironmentVersion
    }

    return didChange
  }

  private func reloadFromSharedStorageIfNeeded() {
    guard let clerk else { return }
    reloadFromSharedStorageIfNeeded(clerk: clerk)
  }

  private func reloadFromSharedStorageIfNeeded(clerk: Clerk) {
    reloadFromSharedStorage(to: clerk)
  }

  private func shouldPublishLocalAuthChange(previousClient: Client?, client: Client?, clerk: Clerk) -> Bool {
    client != nil || previousClient != nil || clerk.lastClientServerFetchDate != nil
  }

  private func repairSharedAuthSnapshot(from clerk: Clerk) {
    do {
      try persistAuthSnapshot(from: clerk, version: .makeWriteRevision())
      notifier.post()
    } catch {
      ClerkLogger.logError(error, message: "Failed to repair stale shared Clerk auth state")
    }
  }

  private func persistAuthSnapshot(from clerk: Clerk, version: SharedSessionSyncVersion) throws {
    let keychain = clerk.dependencies.keychain

    // Only known auth cache keys participate in sibling-app sync. App Attest
    // key IDs and pending magic-link state are intentionally excluded.
    if let client = clerk.client {
      try keychain.set(JSONEncoder.clerkEncoder.encode(client), forKey: ClerkKeychainKey.cachedClient.rawValue)
      if let serverFetchDate = clerk.lastClientServerFetchDate {
        try keychain.set(String(serverFetchDate.timeIntervalSince1970), forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)
      } else {
        try keychain.deleteItem(forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)
      }
      try persistAuthState("set", version: version, keychain: keychain)
    } else {
      try keychain.deleteItem(forKey: ClerkKeychainKey.cachedClient.rawValue)
      if let serverFetchDate = clerk.lastClientServerFetchDate {
        try keychain.set(String(serverFetchDate.timeIntervalSince1970), forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)
      } else {
        try keychain.deleteItem(forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)
      }
      try persistAuthState("cleared", version: version, keychain: keychain)
    }
  }

  private func persistAuthState(
    _ state: String,
    version: SharedSessionSyncVersion,
    keychain: any KeychainStorage
  ) throws {
    authGeneration = version
    try keychain.set(state, forKey: ClerkKeychainKey.sharedSessionSyncAuthState.rawValue)
    try keychain.set(version.rawValue, forKey: ClerkKeychainKey.sharedSessionSyncAuthVersion.rawValue)
  }

  private func persistEnvironmentSnapshot(from clerk: Clerk, version: SharedSessionSyncVersion) throws {
    guard let environment = clerk.environment else { return }

    let keychain = clerk.dependencies.keychain
    try keychain.set(JSONEncoder.clerkEncoder.encode(environment), forKey: ClerkKeychainKey.cachedEnvironment.rawValue)
    environmentGeneration = version
    try keychain.set(version.rawValue, forKey: ClerkKeychainKey.sharedSessionSyncEnvironmentVersion.rawValue)
  }

  private func persistDeviceTokenState(
    _ state: String,
    version: SharedSessionSyncVersion,
    keychain: any KeychainStorage
  ) throws {
    deviceTokenGeneration = version
    try keychain.set(state, forKey: ClerkKeychainKey.sharedSessionSyncDeviceTokenState.rawValue)
    try keychain.set(version.rawValue, forKey: ClerkKeychainKey.sharedSessionSyncDeviceTokenVersion.rawValue)
  }

  private static func readVersion(
    forKey key: ClerkKeychainKey,
    keychain: any KeychainStorage
  ) -> SharedSessionSyncVersion {
    guard let versionString = try? keychain.string(forKey: key.rawValue),
          !versionString.isEmpty
    else {
      return .initial
    }

    return SharedSessionSyncVersion(rawValue: versionString)
  }
}
