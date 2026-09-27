import Foundation

/// Transfers identity only when this app changes backends, without changing a sibling's record.
struct ClerkIdentityStorageHandoff {
  private struct Selection: Codable {
    let isShared: Bool
    /// Detects a completed copy or a local clear before a failed handoff could be marked done.
    let localRevision: UUID?
  }

  let shared: ClerkIdentityStore
  let local: ClerkIdentityStore
  let markerKeychain: any KeychainStorage
  let configurationScope: String

  init(config: Clerk.Options.KeychainConfig, instanceFingerprint: String,
       sharedKeychain: any KeychainStorage, localKeychain: any KeychainStorage,
       markerKeychain: any KeychainStorage)
  {
    func store(_ keychain: any KeychainStorage, sync: Bool) -> ClerkIdentityStore {
      ClerkIdentityStore(
        keychain: keychain, instanceFingerprint: instanceFingerprint,
        clearIntentKeychain: markerKeychain,
        clearIntentScope: SharedSessionNamespace.sha256("\(config.service)\u{1F}\(config.normalizedAccessGroup ?? "")\u{1F}\(sync)")
      )
    }
    shared = store(sharedKeychain, sync: true)
    local = store(localKeychain, sync: false)
    self.markerKeychain = markerKeychain
    configurationScope = SharedSessionNamespace.sha256("\(config.service)\u{1F}\(config.normalizedAccessGroup ?? "")")
  }

  func prepare(isShared: Bool) throws {
    let key = "\(local.key).storageSelection.\(configurationScope)"
    let previous = try markerKeychain.data(forKey: key).map {
      try JSONDecoder.clerkDecoder.decode(Selection.self, from: $0)
    }
    guard previous?.isShared != isShared else { return }
    // Before importing a source, finish its own clear in its original backend.
    // A backend change must never revive credentials waiting to be forgotten.
    if isShared, try shared.load() == nil {
      try local.recoverPendingClear()
    }
    let localRecord = try local.load()

    if isShared {
      // Joining an established group adopts its identity, including a sign-out.
      if try shared.load() == nil, let localRecord {
        try copy(localRecord, to: shared, replacing: nil)
      }
    } else if previous?.isShared == true, localRecord?.revision == previous?.localRevision {
      try shared.recoverPendingClear()
      try copy(shared.load(), to: local, replacing: localRecord)
    }

    // Preparation cannot expose the destination until this succeeds. If it fails
    // after a copy, the changed local revision prevents replaying that copy.
    try markerKeychain.set(JSONEncoder.clerkEncoder.encode(Selection(
      isShared: isShared, localRevision: isShared ? localRecord?.revision : nil
    )), forKey: key)
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
