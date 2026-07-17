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
    case refresh
  }

  private let store: SharedSessionSyncStore
  private let identityKeychain: any KeychainStorage
  private let notifier: any SharedSessionSyncNotifying
  private weak var clerk: Clerk?

  private var currentRevision: UUID?
  private var currentDeviceToken: String?
  private var isApplyingSharedEnvelope = false
  private var isRefreshScheduled = false
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

    let identityDeviceToken = try? identityKeychain
      .string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
      .nilIfEmpty

    currentDeviceToken = identityDeviceToken

    do {
      if let initialEnvelope = try store.load() {
        canPublishSharedIdentity = true
        switch reconciliationDecision(for: initialEnvelope, clerk: clerk) {
        case .apply:
          _ = try apply(initialEnvelope, to: clerk)
        case .acceptRevision:
          currentRevision = initialEnvelope.revision
        case .rejectOlder, .refresh:
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
    currentDeviceToken
  }

  func updateDeviceToken(_ token: String?) {
    currentDeviceToken = token.nilIfEmpty
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
    requiresClientRefresh = true
  }

  func handle(_ change: ClerkInternalStateChange, from clerk: Clerk) throws {
    switch change {
    case let .clientDidChange(previousClient, client):
      guard !isApplyingSharedEnvelope,
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
      guard let envelope = try store.load(),
            force || envelope.revision != currentRevision
      else {
        return false
      }

      switch reconciliationDecision(for: envelope, clerk: clerk) {
      case .apply:
        return try apply(envelope, to: clerk)
      case .acceptRevision:
        currentRevision = envelope.revision
        return false
      case .rejectOlder:
        guard !requiresClientRefresh else {
          return false
        }
        try persistCurrentIdentity(from: clerk)
        return false
      case .refresh:
        if !requiresClientRefresh {
          clerk.hardFenceClientResponses()
          requiresClientRefresh = true
        }
        scheduleRefresh(for: clerk)
        return false
      }
    } catch {
      ClerkLogger.logError(error, message: "Failed to reload the shared Clerk auth envelope")
      return false
    }
  }

  func persistCurrentIdentityIfNeeded() throws {
    guard !requiresClientRefresh,
          let clerk,
          canPublishSharedIdentity || clerk.client?.activeSessions.isEmpty == false
    else {
      return
    }

    if let envelope = try store.load(),
       envelope.deviceToken == currentDeviceToken,
       envelope.client == clerk.client,
       envelope.serverDate == clerk.lastClientServerFetchDate
    {
      currentRevision = envelope.revision
      return
    }

    try persistCurrentIdentity(from: clerk)
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

  private func scheduleRefresh(for clerk: Clerk) {
    guard !isRefreshScheduled else { return }
    isRefreshScheduled = true

    let task = clerk.scheduleManagedTask { @MainActor [weak self, weak clerk] in
      defer { self?.isRefreshScheduled = false }

      do {
        try await clerk?.refreshClient()
      } catch is CancellationError {
        // Managed cleanup cancels this task during Clerk reconfiguration.
      } catch {
        ClerkLogger.logError(
          error,
          message: "Failed to refresh client after an ambiguous shared auth update"
        )
      }
    }

    if task == nil {
      isRefreshScheduled = false
    }
  }

  private func persistCurrentIdentity(from clerk: Clerk) throws {
    let envelope = try store.save(
      deviceToken: currentDeviceToken,
      client: clerk.client,
      serverDate: clerk.lastClientServerFetchDate
    )
    canPublishSharedIdentity = true
    currentRevision = envelope.revision
    notifier.post()
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

    if currentDeviceToken == nil,
       clerk.client == nil,
       currentServerDate == nil
    {
      return .apply
    }

    guard let incomingServerDate, let currentServerDate else {
      return .refresh
    }

    if incomingServerDate > currentServerDate {
      return .apply
    }
    return incomingServerDate < currentServerDate
      ? .rejectOlder
      : .refresh
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
    currentDeviceToken = envelope.deviceToken
    clerk.lastClientServerFetchDate = envelope.serverDate
    clerk.client = envelope.client
    isApplyingSharedEnvelope = false
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
