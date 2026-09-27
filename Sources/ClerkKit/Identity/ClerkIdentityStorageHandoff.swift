import Foundation

/// Transfers identity only when this app changes backends, without changing a sibling's record.
struct ClerkIdentityStorageHandoff {
  private struct Selection: Codable {
    let isShared: Bool
    let accessGroup: String?
    /// Sharing can change this scope without changing the identity's backend.
    let clearIntentScope: String
    /// Detects a completed copy or a local clear before a failed handoff could be marked done.
    let localRevision: UUID?
    /// The isolated backend survives changes to the configured group and sync option.
    let localClearIntentScope: String
  }

  let shared: ClerkIdentityStore
  let local: ClerkIdentityStore
  let markerKeychain: any KeychainStorage
  let config: Clerk.Options.KeychainConfig
  let makeKeychain: @Sendable (String, String?) -> any KeychainStorage
  var selectionKey: String {
    "\(local.key).storageSelection.\(SharedSessionNamespace.sha256(config.service))"
  }

  static func clearIntentScope(config: Clerk.Options.KeychainConfig, syncEnabled: Bool) -> String {
    SharedSessionNamespace.sha256("\(config.service)\u{1F}\(config.normalizedAccessGroup ?? "")\u{1F}\(syncEnabled)")
  }

  init(config: Clerk.Options.KeychainConfig, instanceFingerprint: String,
       sharedKeychain: any KeychainStorage, localKeychain: any KeychainStorage,
       markerKeychain: any KeychainStorage,
       makeKeychain: @escaping @Sendable (String, String?) -> any KeychainStorage)
  {
    func store(_ keychain: any KeychainStorage, sync: Bool) -> ClerkIdentityStore {
      ClerkIdentityStore(
        keychain: keychain, instanceFingerprint: instanceFingerprint,
        clearIntentKeychain: markerKeychain,
        clearIntentScope: Self.clearIntentScope(config: config, syncEnabled: sync)
      )
    }
    shared = store(sharedKeychain, sync: true)
    local = store(localKeychain, sync: false)
    self.markerKeychain = markerKeychain
    self.config = config
    self.makeKeychain = makeKeychain
  }

  /// Removing a group must not reopen the configured service after this app has
  /// selected an isolated or group backend. Handoff retains its current identity.
  func hasSelection() throws -> Bool {
    try selection() != nil
  }

  private func selection() throws -> Selection? {
    try markerKeychain.data(forKey: selectionKey).map {
      try JSONDecoder.clerkDecoder.decode(Selection.self, from: $0)
    }
  }

  func prepare(isShared: Bool, clearIntentScope: String) throws {
    let previous = try selection()
    let accessGroup = isShared ? config.normalizedAccessGroup : nil
    guard previous?.isShared != isShared || previous?.accessGroup != accessGroup
      || previous?.clearIntentScope != clearIntentScope else { return }
    var shared = shared
    var local = local
    local.clearIntentScope = previous?.localClearIntentScope ?? local.clearIntentScope
    if let previous, previous.isShared, isShared, previous.accessGroup == accessGroup {
      shared.clearIntentScope = previous.clearIntentScope
      try shared.recoverPendingClear()
    }
    // Before importing a source, finish its own clear in its original backend.
    // A backend change must never revive credentials waiting to be forgotten.
    if try !isShared || shared.load() == nil {
      try local.recoverPendingClear()
    }
    let localRecord = try local.load()

    if isShared {
      // Joining an established group adopts its identity, including a sign-out.
      if try shared.load() == nil, let localRecord {
        try copy(localRecord, to: shared, replacing: nil)
      }
    } else if let previous, previous.isShared, localRecord?.revision == previous.localRevision,
              config.normalizedAccessGroup == nil || config.normalizedAccessGroup == previous.accessGroup
    {
      let source = ClerkIdentityStore(
        keychain: makeKeychain(config.service, previous.accessGroup), instanceFingerprint: local.instanceFingerprint,
        clearIntentKeychain: markerKeychain, clearIntentScope: previous.clearIntentScope
      )
      do {
        try source.recoverPendingClear()
        let record = try source.load()
        // An interrupted first migration may not have established the group yet.
        // Removing that group must still let migration recover its original source.
        if record != nil || config.normalizedAccessGroup != nil {
          try copy(record, to: local, replacing: localRecord)
        }
      } catch let error as KeychainError where error.isMissingEntitlement {
        // The former group may be inaccessible after its entitlement is removed.
        // Its old local copy cannot be trusted to represent the current login.
        try copy(nil, to: local, replacing: localRecord)
      }
    }

    // Preparation cannot expose the destination until this succeeds. If it fails
    // after a copy, the changed local revision prevents replaying that copy.
    try markerKeychain.set(JSONEncoder.clerkEncoder.encode(Selection(
      isShared: isShared, accessGroup: accessGroup, clearIntentScope: clearIntentScope,
      localRevision: isShared ? localRecord?.revision : nil,
      localClearIntentScope: isShared ? local.clearIntentScope : clearIntentScope
    )), forKey: selectionKey)
  }

  private func copy(_ source: ClerkIdentityStore.Record?, to destination: ClerkIdentityStore,
                    replacing expected: ClerkIdentityStore.Record?) throws
  {
    do {
      if let source {
        try destination.importRecord(source, replacing: expected)
      } else {
        try destination.save(.signedOut, replacing: expected)
      }
    } catch ClerkIdentityStoreError.writeConflict {
      // A concurrent destination writer won. Never overwrite its accepted state.
      _ = try destination.load()
    }
  }
}
