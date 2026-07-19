//
//  WatchConnectivityCoordinator.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Coordinates WatchConnectivity as a transport for Clerk auth state.
@MainActor
final class WatchConnectivityCoordinator: ClerkInternalStateChangeObserver {
  private struct IdentityCandidate {
    let state: SharedSessionIdentityEvent.State
    let deviceToken: String?
    let client: Client?
    let serverDate: Date?
    let tokenVersion: WatchSyncVersion?
    let authVersion: WatchSyncVersion?
    let requiresClientRefresh: Bool
  }

  private struct VersionAcceptance {
    let version: WatchSyncVersion?
    let updateIsIncluded: Bool
    let acceptedVersion: WatchSyncVersion?
    let acceptedFingerprint: String?
    let pendingVersion: WatchSyncVersion?
    let pendingFingerprint: String?
    let current: WatchSyncVersion?
    let incomingFingerprint: String
    let durableFingerprint: String
    let source: WatchSyncSource
  }

  private var watchConnectivitySync: (any WatchConnectivitySyncing)?
  private var authGeneration: WatchSyncVersion?
  private var isAcceptingIdentityUpdates = true
  private var isApplyingRemotePayload = false
  private var isRefreshScheduled = false
  private var identityPublicationTasks: [UUID: Task<Void, Error>] = [:]
  private var activeRemoteIdentityApplications: Set<UUID> = []
  var activeIdentityPublicationCount: Int {
    identityPublicationTasks.count
  }

  private var clientRefreshTask: Task<Void, Never>?
  private var clientRefreshTaskID: UUID?

  init() {
    #if os(iOS)
    watchConnectivitySync = createWatchConnectivityManager(
      payloadHandler: { [weak self] payload in
        self?.apply(payload, from: .watch, to: Clerk.shared)
      },
      activationHandler: { [weak self] in
        self?.syncCurrentState(from: Clerk.shared)
      }
    )
    #elseif os(watchOS)
    watchConnectivitySync = WatchSyncReceiver(
      payloadHandler: { [weak self] payload in
        self?.apply(payload, from: .phone, to: Clerk.shared)
      },
      activationHandler: { [weak self] in
        self?.syncCurrentState(from: Clerk.shared)
      }
    )
    #else
    watchConnectivitySync = nil
    #endif
  }

  func handle(_ change: ClerkInternalStateChange, from clerk: Clerk) throws {
    guard isAcceptingIdentityUpdates else { return }

    switch change {
    case let .clientDidChange(previousClient, client):
      guard !isApplyingRemotePayload,
            !clerk.identityController.isApplyingIdentityTransition,
            shouldPublishLocalAuthChange(previousClient: previousClient, client: client, clerk: clerk)
      else {
        return
      }

      try persistAuthState(
        client == nil ? "cleared" : "set",
        version: nextAuthVersion(keychain: clerk.dependencies.watchSyncKeychain),
        client: client,
        serverDate: clerk.lastClientServerFetchDate,
        keychain: clerk.dependencies.watchSyncKeychain
      )
      syncCurrentState(from: clerk)
    case .environmentDidChange:
      guard !isApplyingRemotePayload else { return }
      syncCurrentState(from: clerk)
    case let .deviceTokenDidChange(previousToken, token):
      if previousToken != token {
        try persistDeviceTokenState(
          token == nil ? "cleared" : "set",
          deviceToken: token,
          version: nextDeviceTokenVersion(keychain: clerk.dependencies.watchSyncKeychain),
          keychain: clerk.dependencies.watchSyncKeychain
        )
      }

      syncCurrentState(from: clerk)
    case .identityDidChange:
      guard !isApplyingRemotePayload else { return }
      let keychain = clerk.dependencies.watchSyncKeychain
      let metadata = try persistCurrentIdentityMetadata(
        from: clerk,
        keychain: keychain
      )
      try syncCurrentState(from: clerk, metadata: metadata)
    case .localStorageDidClear:
      identityPublicationTasks.values.forEach { $0.cancel() }
      identityPublicationTasks.removeAll()
      activeRemoteIdentityApplications.removeAll()
      clientRefreshTask?.cancel()
      clientRefreshTask = nil
      clientRefreshTaskID = nil
      isApplyingRemotePayload = false
      isRefreshScheduled = false
      let metadata = try WatchSyncMetadataStore(
        keychain: clerk.dependencies.watchSyncKeychain
      ).saveClearTombstone()
      try syncCurrentState(from: clerk, metadata: metadata)
    case .applicationDidEnterForeground:
      syncCurrentState(from: clerk)
    }
  }

  func syncCurrentState(from clerk: Clerk) {
    guard isAcceptingIdentityUpdates, watchConnectivitySync != nil else { return }

    let watchSyncKeychain = clerk.dependencies.watchSyncKeychain
    do {
      let metadata = try resolvedWatchMetadata(
        clerk: clerk,
        keychain: watchSyncKeychain
      )
      try syncCurrentState(from: clerk, metadata: metadata)
    } catch {
      ClerkLogger.logError(error, message: "Failed to read Watch identity metadata for sync")
    }
  }

  private func syncCurrentState(
    from clerk: Clerk,
    metadata: WatchSyncMetadataRecord
  ) throws {
    guard isAcceptingIdentityUpdates, let watchConnectivitySync else { return }
    if let effectiveAuthVersion = effectiveVersion(
      accepted: metadata.authVersion,
      pending: metadata.pendingAuthVersion
    ) {
      authGeneration = maxVersion(authGeneration, effectiveAuthVersion)
    }
    let payload = try WatchSyncPayload(
      clerk: clerk,
      metadata: metadata,
      authGeneration: authGeneration ?? .initial
    )
    watchConnectivitySync.sync(payload)
  }

  func apply(_ payload: WatchSyncPayload, from source: WatchSyncSource, to clerk: Clerk) {
    guard isAcceptingIdentityUpdates else { return }

    if let environment = payload.environment {
      let wasApplyingRemotePayload = isApplyingRemotePayload
      isApplyingRemotePayload = true
      clerk.environment = environment
      isApplyingRemotePayload = wasApplyingRemotePayload
    }

    guard payload.deviceTokenUpdate != .notIncluded
      || payload.clientUpdate != .notIncluded
    else {
      return
    }

    enqueueIdentityPayload(payload, source: source, for: clerk)
  }
}

extension WatchConnectivityCoordinator {
  private func identityCandidate(
    from payload: WatchSyncPayload,
    source: WatchSyncSource,
    clerk: Clerk,
    watchSyncKeychain: any KeychainStorage
  ) throws -> IdentityCandidate? {
    guard payload.deviceTokenUpdate != .notIncluded
      || payload.clientUpdate != .notIncluded
    else {
      return nil
    }

    let metadata = try WatchSyncMetadataStore(keychain: watchSyncKeychain).load()
    guard acceptsIdentityVersions(
      in: payload,
      metadata: metadata,
      source: source,
      clerk: clerk
    ) else {
      return nil
    }

    let currentToken = normalizedToken(clerk.deviceToken)
    let deviceToken: String?
    switch payload.deviceTokenUpdate {
    case .notIncluded:
      deviceToken = clerk.deviceToken
    case .tokenSet(let token, _):
      guard let token = normalizedToken(token) else { return nil }
      deviceToken = token
    case .tokenCleared:
      deviceToken = nil
    }

    let client: Client?
    let serverDate: Date?
    let requiresClientRefresh: Bool
    switch payload.clientUpdate {
    case .notIncluded:
      switch payload.deviceTokenUpdate {
      case .notIncluded:
        return nil
      case .tokenSet:
        if deviceToken == currentToken {
          client = clerk.client
          serverDate = clerk.lastClientServerFetchDate
          requiresClientRefresh = false
        } else {
          client = nil
          serverDate = nil
          requiresClientRefresh = true
        }
      case .tokenCleared:
        client = nil
        serverDate = nil
        requiresClientRefresh = false
      }
    case .snapshot(let snapshot, let date, _):
      guard case .tokenSet(let pairedToken, _) = payload.deviceTokenUpdate,
            normalizedToken(pairedToken) == deviceToken
      else {
        scheduleRefresh(for: clerk)
        return nil
      }
      client = snapshot
      serverDate = date
      requiresClientRefresh = false
    case .cleared(let date, _):
      client = nil
      serverDate = date
      requiresClientRefresh = false
    }

    guard client == nil || deviceToken != nil else {
      scheduleRefresh(for: clerk)
      return nil
    }
    if !source.incomingDeviceIsAuthoritative,
       !shouldApplyNonAuthoritativeIdentityUpdate(
         deviceToken: deviceToken,
         client: client,
         serverDate: serverDate,
         clientUpdate: payload.clientUpdate,
         clerk: clerk
       )
    {
      return nil
    }
    if isAlreadyAcceptedIdentityPayload(payload, metadata: metadata, clerk: clerk) {
      return nil
    }

    return IdentityCandidate(
      state: client == nil ? .cleared : .present,
      deviceToken: deviceToken,
      client: client,
      serverDate: serverDate,
      tokenVersion: payload.deviceTokenUpdate.version,
      authVersion: payload.clientUpdate.version,
      requiresClientRefresh: requiresClientRefresh
    )
  }

  private func accepts(_ candidate: VersionAcceptance) -> Bool {
    guard candidate.updateIsIncluded else { return true }
    guard let version = candidate.version else {
      return candidate.acceptedVersion == nil
        && candidate.pendingVersion == nil
        && candidate.current == nil
    }
    if let current = candidate.current {
      guard version >= current else { return false }
    }
    if version == candidate.pendingVersion {
      return candidate.incomingFingerprint == candidate.pendingFingerprint
    }
    if version == candidate.acceptedVersion || version == candidate.current {
      if let acceptedFingerprint = candidate.acceptedFingerprint {
        guard acceptedFingerprint == candidate.durableFingerprint else {
          return false
        }
        return candidate.incomingFingerprint == acceptedFingerprint
      }
      return candidate.incomingFingerprint == candidate.durableFingerprint
    }
    if let current = candidate.current {
      return candidate.source.incomingDeviceIsAuthoritative
        || version > current
    }
    return true
  }

  private func isAlreadyAcceptedIdentityPayload(
    _ payload: WatchSyncPayload,
    metadata: WatchSyncMetadataRecord,
    clerk: Clerk
  ) -> Bool {
    let includesToken = payload.deviceTokenUpdate != .notIncluded
    let includesAuth = payload.clientUpdate != .notIncluded
    guard includesToken || includesAuth else { return false }

    let incomingTokenFingerprint: String = switch payload.deviceTokenUpdate {
    case .notIncluded:
      Self.deviceTokenFingerprint(clerk.deviceToken)
    case .tokenSet(let token, _):
      Self.deviceTokenFingerprint(normalizedToken(token))
    case .tokenCleared:
      Self.deviceTokenFingerprint(nil)
    }
    let tokenIsAccepted: Bool = if !includesToken {
      true
    } else if let version = payload.deviceTokenUpdate.version {
      metadata.pendingDeviceTokenVersion != version.rawValue
        && metadata.deviceTokenVersion == version.rawValue
        && metadata.deviceTokenFingerprint == incomingTokenFingerprint
        && metadata.deviceTokenFingerprint == Self.deviceTokenFingerprint(clerk.deviceToken)
    } else {
      false
    }

    let authIsAccepted: Bool = if !includesAuth {
      true
    } else if let version = payload.clientUpdate.version,
              let incomingFingerprint = try? Self.authFingerprint(
                client: payload.clientUpdate.client,
                serverDate: payload.clientUpdate.serverFetchDate
              ),
              let durableFingerprint = try? Self.authFingerprint(
                client: clerk.client,
                serverDate: clerk.lastClientServerFetchDate
              )
    {
      metadata.pendingAuthVersion != version.rawValue
        && metadata.authVersion == version.rawValue
        && metadata.authFingerprint == incomingFingerprint
        && metadata.authFingerprint == durableFingerprint
    } else {
      false
    }

    return tokenIsAccepted && authIsAccepted
  }

  private func acceptsIdentityVersions(
    in payload: WatchSyncPayload,
    metadata: WatchSyncMetadataRecord,
    source: WatchSyncSource,
    clerk: Clerk
  ) -> Bool {
    let incomingTokenFingerprint: String = switch payload.deviceTokenUpdate {
    case .notIncluded:
      Self.deviceTokenFingerprint(clerk.deviceToken)
    case .tokenSet(let token, _):
      Self.deviceTokenFingerprint(normalizedToken(token))
    case .tokenCleared:
      Self.deviceTokenFingerprint(nil)
    }
    guard accepts(
      VersionAcceptance(
        version: payload.deviceTokenUpdate.version,
        updateIsIncluded: payload.deviceTokenUpdate != .notIncluded,
        acceptedVersion: metadata.deviceTokenVersion.map(WatchSyncVersion.init(rawValue:)),
        acceptedFingerprint: metadata.deviceTokenFingerprint,
        pendingVersion: metadata.pendingDeviceTokenVersion.map(WatchSyncVersion.init(rawValue:)),
        pendingFingerprint: metadata.pendingDeviceTokenFingerprint,
        current: effectiveVersion(
          accepted: metadata.deviceTokenVersion,
          pending: metadata.pendingDeviceTokenVersion
        ),
        incomingFingerprint: incomingTokenFingerprint,
        durableFingerprint: Self.deviceTokenFingerprint(clerk.deviceToken),
        source: source
      )
    ) else {
      return false
    }
    let incomingAuthFingerprint: String
    do {
      incomingAuthFingerprint = try Self.authFingerprint(
        client: payload.clientUpdate.client,
        serverDate: payload.clientUpdate.serverFetchDate
      )
    } catch {
      return false
    }
    let acceptedAuthVersion = maxVersion(
      authGeneration,
      metadata.authVersion.map(WatchSyncVersion.init(rawValue:))
    )
    guard accepts(
      VersionAcceptance(
        version: payload.clientUpdate.version,
        updateIsIncluded: payload.clientUpdate != .notIncluded,
        acceptedVersion: acceptedAuthVersion,
        acceptedFingerprint: metadata.authFingerprint,
        pendingVersion: metadata.pendingAuthVersion.map(WatchSyncVersion.init(rawValue:)),
        pendingFingerprint: metadata.pendingAuthFingerprint,
        current: maxVersion(
          acceptedAuthVersion,
          effectiveVersion(
            accepted: metadata.authVersion,
            pending: metadata.pendingAuthVersion
          )
        ),
        incomingFingerprint: incomingAuthFingerprint,
        durableFingerprint: (try? Self.authFingerprint(
          client: clerk.client,
          serverDate: clerk.lastClientServerFetchDate
        )) ?? "",
        source: source
      )
    ) else {
      scheduleRefreshForRejectedClientIfNeeded(
        payload.clientUpdate,
        source: source,
        clerk: clerk
      )
      return false
    }
    return true
  }

  private func scheduleRefreshForRejectedClientIfNeeded(
    _ update: WatchSyncClientUpdate,
    source: WatchSyncSource,
    clerk: Clerk
  ) {
    guard !source.incomingDeviceIsAuthoritative,
          update != .notIncluded,
          let incomingDate = update.serverFetchDate
    else {
      return
    }
    if let currentDate = clerk.lastClientServerFetchDate,
       incomingDate <= currentDate
    {
      return
    }
    scheduleRefresh(for: clerk)
  }

  private func shouldApplyNonAuthoritativeClientUpdate(
    _ update: WatchSyncClientUpdate,
    serverDate: Date?,
    clerk: Clerk
  ) -> Bool {
    guard update != .notIncluded else { return true }
    if let serverDate,
       let currentDate = clerk.lastClientServerFetchDate,
       serverDate < currentDate
    {
      return false
    }

    switch update {
    case .notIncluded:
      return true
    case .cleared:
      guard clerk.client == nil else {
        scheduleRefresh(for: clerk)
        return false
      }
      return true
    case .snapshot:
      if let serverDate,
         let currentDate = clerk.lastClientServerFetchDate,
         serverDate > currentDate
      {
        return true
      }
      guard clerk.client == nil, clerk.lastClientServerFetchDate == nil else {
        scheduleRefresh(for: clerk)
        return false
      }
      scheduleRefresh(for: clerk)
      return true
    }
  }

  private func shouldApplyNonAuthoritativeIdentityUpdate(
    deviceToken: String?,
    client: Client?,
    serverDate: Date?,
    clientUpdate: WatchSyncClientUpdate,
    clerk: Clerk
  ) -> Bool {
    let currentToken = normalizedToken(clerk.deviceToken)
    guard currentToken != nil || clerk.client != nil else {
      return shouldApplyNonAuthoritativeClientUpdate(
        clientUpdate,
        serverDate: serverDate,
        clerk: clerk
      )
    }

    let incomingAuthFingerprint = try? Self.authFingerprint(
      client: client,
      serverDate: serverDate
    )
    let currentAuthFingerprint = try? Self.authFingerprint(
      client: clerk.client,
      serverDate: clerk.lastClientServerFetchDate
    )
    guard normalizedToken(deviceToken) == currentToken,
          incomingAuthFingerprint == currentAuthFingerprint
    else {
      scheduleRefresh(for: clerk)
      return false
    }
    return true
  }

  private func persistCurrentIdentityMetadata(
    from clerk: Clerk,
    keychain: any KeychainStorage
  ) throws -> WatchSyncMetadataRecord {
    let store = WatchSyncMetadataStore(keychain: keychain)
    var record = try store.load()
    let deviceTokenVersion = try WatchSyncVersion(
      rawValue: record.effectiveDeviceTokenVersion
    ).next()
    let authVersion = try max(
      authGeneration ?? .initial,
      effectiveVersion(
        accepted: record.authVersion,
        pending: record.pendingAuthVersion
      ) ?? .initial
    ).next()

    record.deviceTokenState = clerk.deviceToken == nil ? "cleared" : "set"
    record.deviceTokenVersion = deviceTokenVersion.rawValue
    record.deviceTokenFingerprint = Self.deviceTokenFingerprint(clerk.deviceToken)
    record.discardPendingDeviceToken()
    record.authState = clerk.client == nil ? "cleared" : "set"
    record.authVersion = authVersion.rawValue
    record.authFingerprint = try Self.authFingerprint(
      client: clerk.client,
      serverDate: clerk.lastClientServerFetchDate
    )
    record.discardPendingAuth()
    try store.save(record)
    setAuthGeneration(authVersion)
    return record
  }

  private func stagePendingWatchMetadata(
    for candidate: IdentityCandidate,
    keychain: any KeychainStorage
  ) throws {
    try stagePendingWatchMetadata(
      WatchSyncPendingMetadataIntent(
        deviceToken: candidate.deviceToken,
        client: candidate.client,
        serverDate: candidate.serverDate,
        tokenVersion: candidate.tokenVersion,
        authVersion: candidate.authVersion
      ),
      keychain: keychain
    )
  }

  private func enqueueIdentityPayload(
    _ payload: WatchSyncPayload,
    source: WatchSyncSource,
    for clerk: Clerk
  ) {
    guard isAcceptingIdentityUpdates else { return }
    let operationID = UUID()
    do {
      let operationTask = try clerk.identityController.submitExternalTransition { [weak self, weak clerk] in
        guard let self, let clerk, isAcceptingIdentityUpdates else { return nil }
        let keychain = clerk.dependencies.watchSyncKeychain
        let candidate: IdentityCandidate
        do {
          guard let resolved = try identityCandidate(
            from: payload,
            source: source,
            clerk: clerk,
            watchSyncKeychain: keychain
          ) else {
            return nil
          }
          candidate = resolved
        } catch {
          ClerkLogger.logError(error, message: "Failed to read Watch identity metadata; rejecting identity update")
          return nil
        }

        beginApplyingRemoteIdentity(operationID)
        let identity = try ClerkIdentitySnapshot(
          state: candidate.state,
          deviceToken: candidate.deviceToken,
          client: candidate.client,
          serverDate: candidate.serverDate
        ).validated()
        return ClerkIdentityController.ExternalTransition(
          identity: identity,
          stage: { [weak self] in
            guard let self else { throw CancellationError() }
            try stagePendingWatchMetadata(for: candidate, keychain: keychain)
          },
          didApply: { [weak self, weak clerk] in
            guard let self, let clerk else { return }
            do {
              try promotePendingWatchMetadata(
                tokenVersion: candidate.tokenVersion,
                authVersion: candidate.authVersion,
                keychain: keychain
              )
            } catch {
              ClerkLogger.logError(error, message: "Failed to finalize Watch identity metadata")
            }
            syncCurrentState(from: clerk)
            if candidate.requiresClientRefresh {
              scheduleRefresh(for: clerk)
            }
          },
          didNotApply: { [weak self] in
            guard let self else { return }
            do {
              try discardPendingWatchMetadata(
                tokenVersion: candidate.tokenVersion,
                authVersion: candidate.authVersion,
                keychain: keychain
              )
            } catch {
              ClerkLogger.logError(
                error,
                message: "Failed to discard superseded Watch identity metadata"
              )
            }
          }
        )
      }
      if let operationTask {
        trackIdentityPublication(operationTask, operationID: operationID)
      } else {
        finishIdentityPublication(operationID)
      }
    } catch is CancellationError {
      finishIdentityPublication(operationID)
    } catch {
      finishIdentityPublication(operationID)
      ClerkLogger.logError(error, message: "Failed to persist atomic Watch identity update")
    }
  }

  private func trackIdentityPublication(
    _ operationTask: Task<Void, Error>,
    operationID: UUID
  ) {
    let trackedTask = Task { @MainActor [weak self] in
      defer { self?.finishIdentityPublication(operationID) }
      do {
        return try await withTaskCancellationHandler {
          try await operationTask.value
        } onCancel: {
          operationTask.cancel()
        }
      } catch is CancellationError {
        return
      } catch {
        ClerkLogger.logError(error, message: "Failed to apply Watch identity transition")
        throw error
      }
    }
    identityPublicationTasks[operationID] = trackedTask
  }

  func waitForIdentityPublications() async {
    while !identityPublicationTasks.isEmpty {
      let tasks = Array(identityPublicationTasks.values)
      for task in tasks {
        _ = try? await task.value
      }
    }
  }

  func stopAcceptingIdentityUpdates() {
    guard isAcceptingIdentityUpdates else { return }
    isAcceptingIdentityUpdates = false
    clientRefreshTask?.cancel()
    clientRefreshTask = nil
    clientRefreshTaskID = nil
    isRefreshScheduled = false
  }

  private func beginApplyingRemoteIdentity(_ operationID: UUID) {
    activeRemoteIdentityApplications.insert(operationID)
    isApplyingRemotePayload = true
  }

  private func finishIdentityPublication(_ operationID: UUID) {
    identityPublicationTasks.removeValue(forKey: operationID)
    activeRemoteIdentityApplications.remove(operationID)
    isApplyingRemotePayload = !activeRemoteIdentityApplications.isEmpty
  }

  private func normalizedToken(_ token: String?) -> String? {
    guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines),
          !token.isEmpty
    else {
      return nil
    }
    return token
  }

  private func effectiveVersion(accepted: Int?, pending: Int?) -> WatchSyncVersion? {
    maxVersion(
      accepted.map(WatchSyncVersion.init(rawValue:)),
      pending.map(WatchSyncVersion.init(rawValue:))
    )
  }

  private func maxVersion(
    _ lhs: WatchSyncVersion?,
    _ rhs: WatchSyncVersion?
  ) -> WatchSyncVersion? {
    switch (lhs, rhs) {
    case (nil, nil):
      nil
    case (let version?, nil), (nil, let version?):
      version
    case (let lhs?, let rhs?):
      max(lhs, rhs)
    }
  }

  func currentAuthVersion(keychain: any KeychainStorage) throws -> WatchSyncVersion {
    try max(authGeneration ?? .initial, readAuthVersion(keychain: keychain))
  }

  func setAuthGeneration(_ version: WatchSyncVersion) {
    authGeneration = version
  }

  func markRefreshScheduled(_ taskID: UUID) -> Bool {
    guard isAcceptingIdentityUpdates, !isRefreshScheduled else { return false }
    isRefreshScheduled = true
    clientRefreshTaskID = taskID
    return true
  }

  func clearRefreshScheduled(_ taskID: UUID) {
    guard clientRefreshTaskID == taskID else { return }
    isRefreshScheduled = false
    clientRefreshTask = nil
    clientRefreshTaskID = nil
  }

  func setRefreshTask(_ task: Task<Void, Never>?, taskID: UUID) {
    guard clientRefreshTaskID == taskID else {
      task?.cancel()
      return
    }
    clientRefreshTask = task
  }
}
