//
//  WatchConnectivityCoordinator+DeviceTokenUpdates.swift
//  Clerk
//

extension WatchConnectivityCoordinator {
  func persistDeviceTokenState(
    _ state: WatchSyncMetadataState,
    deviceToken: String?,
    version: WatchSyncVersion?,
    keychain: any KeychainStorage
  ) throws -> WatchSyncMetadataRecord {
    let store = WatchSyncMetadataStore(keychain: keychain)
    var record = try store.load()
    let resolvedVersion = try version ?? WatchSyncVersion(
      rawValue: record.effectiveDeviceTokenVersion
    ).next()
    record.deviceTokenState = state
    record.deviceTokenVersion = resolvedVersion.rawValue
    record.deviceTokenFingerprint = Self.deviceTokenFingerprint(deviceToken)
    record.deviceTokenSource = nil
    record.discardPendingDeviceToken()
    try store.save(record)
    return record
  }
}
