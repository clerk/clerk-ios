//
//  WatchConnectivityCoordinator+DeviceTokenUpdates.swift
//  Clerk
//

extension WatchConnectivityCoordinator {
  func nextDeviceTokenVersion(keychain: any KeychainStorage) throws -> WatchSyncVersion {
    try readDeviceTokenVersion(keychain: keychain).next()
  }

  func persistDeviceTokenState(
    _ state: String,
    deviceToken: String?,
    version: WatchSyncVersion?,
    keychain: any KeychainStorage
  ) throws {
    let resolvedVersion = try version ?? nextDeviceTokenVersion(keychain: keychain)
    let store = WatchSyncMetadataStore(keychain: keychain)
    var record = try store.load()
    record.deviceTokenState = state
    record.deviceTokenVersion = resolvedVersion.rawValue
    record.deviceTokenFingerprint = Self.deviceTokenFingerprint(deviceToken)
    record.discardPendingDeviceToken()
    try store.save(record)
  }

  func readDeviceTokenVersion(keychain: any KeychainStorage) throws -> WatchSyncVersion {
    try WatchSyncVersion(
      rawValue: WatchSyncMetadataStore(keychain: keychain).load().effectiveDeviceTokenVersion
    )
  }
}
