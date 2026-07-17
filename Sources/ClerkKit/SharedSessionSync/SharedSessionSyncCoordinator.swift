//
//  SharedSessionSyncCoordinator.swift
//  Clerk
//

import Foundation

@MainActor
final class SharedSessionSyncCoordinator: ClerkInternalStateChangeObserver {
  private enum ReconciliationDecision {
    case apply
    case acceptRevision
    case rejectOlder
  }

  private let store: SharedSessionSyncStore
  private let identityKeychain: any KeychainStorage
  private let notifier: any SharedSessionSyncNotifying
  private weak var clerk: Clerk?

  private var currentRevision: UUID?
  private var currentDeviceToken: String?
  private var shouldRetryIdentityDeviceTokenLoad = false
  private var isApplyingSharedEnvelope = false
  private var persistenceDeferralDepth = 0
  private var hasPendingIdentityPersistence = false
  private var canPublishSharedIdentity = false
  private(set) var requiresClientRefresh = false

  init(
    keychainConfig: Clerk.Options.KeychainConfig,
    namespace: SharedSessionSyncNamespace,
    clerk: Clerk,
    keychain: any KeychainStorage,
    identityKeychain: any KeychainStorage,
    notifier: (any SharedSessionSyncNotifying)? = nil
  ) {
    let store = SharedSessionSyncStore(
      keychain: keychain,
      namespace: namespace
    )
    self.store = store
    self.identityKeychain = identityKeychain
    self.notifier = notifier ?? SharedSessionSyncDarwinNotifier(
      keychainConfig: keychainConfig,
      namespace: namespace
    )
    self.clerk = clerk
    canPublishSharedIdentity = clerk.client?.activeSessions.isEmpty == false

    do {
      try loadIdentityDeviceToken()
    } catch {
      shouldRetryIdentityDeviceTokenLoad = true
      requiresClientRefresh = true
      ClerkLogger.logError(error, message: "Failed to load the shared Clerk identity device token")
    }

    do {
      if let initialEnvelope = try store.load() {
        canPublishSharedIdentity = true
        switch reconciliationDecision(for: initialEnvelope, clerk: clerk) {
        case .apply:
          _ = try apply(initialEnvelope, to: clerk)
        case .acceptRevision:
          currentRevision = initialEnvelope.revision
        case .rejectOlder:
          requiresClientRefresh = true
        }
      }
    } catch {
      ClerkLogger.logError(error, message: "Failed to initialize shared Clerk auth state")
    }

    self.notifier.setHandler { [weak self] in
      self?.reloadFromSharedStorageIfNeeded()
    }
  }

  var deviceToken: String? {
    if shouldRetryIdentityDeviceTokenLoad {
      do {
        try loadIdentityDeviceToken()
      } catch {
        ClerkLogger.logError(error, message: "Failed to reload the shared Clerk identity device token")
      }
    }

    return currentDeviceToken
  }

  func updateDeviceToken(_ token: String?) {
    currentDeviceToken = token.nilIfEmpty
    shouldRetryIdentityDeviceTokenLoad = false
  }

  func clearClientForDeviceTokenChange() {
    guard let clerk else { return }

    isApplyingSharedEnvelope = true
    clerk.lastClientServerFetchDate = nil
    clerk.client = nil
    isApplyingSharedEnvelope = false

    do {
      try persistCurrentIdentityIfNeeded()
    } catch {
      ClerkLogger.logError(
        error,
        message: "Failed to persist the shared Clerk device-token transition"
      )
    }
  }

  func invalidateCachedIdentityAfterKeychainClear() {
    currentRevision = nil
    currentDeviceToken = nil
    shouldRetryIdentityDeviceTokenLoad = false
    requiresClientRefresh = true
  }

  func handle(_ change: ClerkInternalStateChange, from clerk: Clerk) throws {
    switch change {
    case let .clientDidChange(previousClient, client):
      guard !isApplyingSharedEnvelope,
            persistenceDeferralDepth == 0,
            !requiresClientRefresh,
            client != nil || previousClient != nil || clerk.lastClientServerFetchDate != nil
      else {
        return
      }
      guard canPublishSharedIdentity || client?.activeSessions.isEmpty == false else {
        return
      }

      try persistCurrentIdentity(from: clerk)

    case .environmentDidChange, .deviceTokenDidChange:
      return

    case .applicationDidEnterForeground:
      reloadFromSharedStorage(to: clerk)
    }
  }

  @discardableResult
  func reloadFromSharedStorage(force: Bool = false, to clerk: Clerk) -> Bool {
    do {
      guard let envelope = try store.load() else {
        try retryPendingIdentityPersistenceIfNeeded()
        return false
      }
      guard force || envelope.revision != currentRevision else {
        try retryPendingIdentityPersistenceIfNeeded()
        return false
      }

      switch reconciliationDecision(for: envelope, clerk: clerk) {
      case .apply:
        return try apply(envelope, to: clerk)
      case .acceptRevision:
        currentRevision = envelope.revision
        try retryPendingIdentityPersistenceIfNeeded()
        return false
      case .rejectOlder:
        guard !requiresClientRefresh else {
          return false
        }
        try persistCurrentIdentity(from: clerk)
        return false
      }
    } catch {
      ClerkLogger.logError(error, message: "Failed to reload the shared Clerk auth envelope")
      return false
    }
  }

  func persistCurrentIdentityIfNeeded() throws {
    guard persistenceDeferralDepth == 0,
          !requiresClientRefresh,
          let clerk,
          canPublishSharedIdentity || clerk.client?.activeSessions.isEmpty == false
    else {
      return
    }

    do {
      if let envelope = try store.load(),
         envelope.deviceToken == currentDeviceToken,
         envelope.client == clerk.client,
         envelope.serverDate == clerk.lastClientServerFetchDate
      {
        hasPendingIdentityPersistence = false
        currentRevision = envelope.revision
        return
      }

      try persistCurrentIdentity(from: clerk)
    } catch {
      hasPendingIdentityPersistence = true
      throw error
    }
  }

  func withDeferredPersistence(_ updates: () -> Void) {
    persistenceDeferralDepth += 1
    defer { persistenceDeferralDepth -= 1 }
    updates()
  }

  func didApplyClientResponse() {
    guard requiresClientRefresh, let clerk else { return }

    do {
      try persistCurrentIdentity(from: clerk)
      requiresClientRefresh = false
    } catch {
      ClerkLogger.logError(
        error,
        message: "Failed to publish refreshed Clerk auth state"
      )
    }
  }
}

extension SharedSessionSyncCoordinator {
  private func reloadFromSharedStorageIfNeeded() {
    guard let clerk else { return }
    reloadFromSharedStorage(to: clerk)
  }

  private func loadIdentityDeviceToken() throws {
    currentDeviceToken = try identityKeychain
      .string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
      .nilIfEmpty
    shouldRetryIdentityDeviceTokenLoad = false
  }

  private func persistCurrentIdentity(from clerk: Clerk) throws {
    let envelope: SharedSessionSyncEnvelope
    do {
      envelope = try store.save(
        deviceToken: currentDeviceToken,
        client: clerk.client,
        serverDate: clerk.lastClientServerFetchDate
      )
    } catch {
      hasPendingIdentityPersistence = true
      throw error
    }
    hasPendingIdentityPersistence = false
    canPublishSharedIdentity = true
    currentRevision = envelope.revision
    notifier.post()
  }

  private func retryPendingIdentityPersistenceIfNeeded() throws {
    guard hasPendingIdentityPersistence else { return }
    try persistCurrentIdentityIfNeeded()
  }

  private func reconciliationDecision(
    for envelope: SharedSessionSyncEnvelope,
    clerk: Clerk
  ) -> ReconciliationDecision {
    let sameIdentity = envelope.deviceToken == currentDeviceToken
      && envelope.client == clerk.client
    let incomingServerDate = envelope.serverDate
    let currentServerDate = clerk.lastClientServerFetchDate

    if sameIdentity {
      guard let incomingServerDate, let currentServerDate else {
        return currentServerDate == nil && incomingServerDate != nil
          ? .apply
          : .acceptRevision
      }

      if incomingServerDate > currentServerDate {
        return .apply
      }
      return incomingServerDate < currentServerDate
        ? .rejectOlder
        : .acceptRevision
    }

    if let incomingServerDate,
       let currentServerDate,
       incomingServerDate < currentServerDate
    {
      return .rejectOlder
    }

    return .apply
  }

  private func apply(
    _ envelope: SharedSessionSyncEnvelope,
    to clerk: Clerk
  ) throws -> Bool {
    if envelope.client == clerk.client,
       envelope.deviceToken == currentDeviceToken,
       envelope.serverDate == clerk.lastClientServerFetchDate
    {
      try persistIdentityDeviceToken(envelope.deviceToken)
      updateDeviceToken(envelope.deviceToken)
      hasPendingIdentityPersistence = false
      canPublishSharedIdentity = true
      currentRevision = envelope.revision
      return false
    }

    let previousClient = clerk.client
    let previousToken = currentDeviceToken
    let previousServerDate = clerk.lastClientServerFetchDate

    try persistIdentityDeviceToken(envelope.deviceToken)
    if previousToken != envelope.deviceToken {
      clerk.hardFenceClientResponses()
    } else {
      clerk.fenceClientResponsesAfterSharedIdentityChange()
    }
    isApplyingSharedEnvelope = true
    updateDeviceToken(envelope.deviceToken)
    clerk.lastClientServerFetchDate = envelope.serverDate
    clerk.client = envelope.client
    isApplyingSharedEnvelope = false
    hasPendingIdentityPersistence = false
    canPublishSharedIdentity = true
    requiresClientRefresh = false
    currentRevision = envelope.revision

    return previousClient != clerk.client
      || previousToken != currentDeviceToken
      || previousServerDate != clerk.lastClientServerFetchDate
  }

  private func persistIdentityDeviceToken(_ token: String?) throws {
    if let token {
      try identityKeychain.set(
        token,
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      )
    } else {
      try identityKeychain.deleteItem(
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      )
    }
  }
}
