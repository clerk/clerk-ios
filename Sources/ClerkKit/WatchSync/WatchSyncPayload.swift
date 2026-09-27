//
//  WatchSyncPayload.swift
//  Clerk
//

import Foundation

package enum WatchSyncSource: Equatable {
  case phone
  case watch
}

/// One device's complete Clerk auth state, as exchanged between phone and watch.
///
/// The device token names a server-side Client, so two devices holding the same
/// token share one Client and only need to agree on the newest snapshot of it.
package struct WatchSyncState: Equatable {
  let deviceToken: String?
  let client: Client?
  /// `Date` header of the response that produced `client`.
  let serverDate: Date?
  /// The largest clear generation observed, incremented on each local clear. Lower generations
  /// cannot restore pre-clear state. Independent offline clears can tie, in which case the
  /// normal identity merge rules apply. Payloads from earlier SDKs carry none and count as 0.
  let clearGeneration: Int

  init(deviceToken: String?, client: Client?, serverDate: Date?, clearGeneration: Int = 0) {
    self.deviceToken = deviceToken.nilIfEmpty
    self.client = client
    self.serverDate = serverDate
    self.clearGeneration = clearGeneration
  }

  var isCleared: Bool {
    deviceToken == nil
  }

  var hasSession: Bool {
    client?.sessions.contains { $0.status == .active || $0.status == .pending } == true
  }

  /// Whether `self`, received from `source`, should replace `local`.
  func supersedes(_ local: WatchSyncState, from source: WatchSyncSource) -> Bool {
    // A newer clear generation wins in either direction, including a post-clear
    // anonymous Client sent before the peer received the tokenless clear itself.
    if clearGeneration != local.clearGeneration {
      return clearGeneration > local.clearGeneration
    }

    // Signing in or out can rotate the token without changing the server-side Client.
    // For the same Client, freshness takes priority over signed-in state and device.
    if deviceToken == local.deviceToken || (client != nil && client?.id == local.client?.id) {
      guard let client else { return false }
      guard let localClient = local.client else { return true }
      guard let serverDate else { return false }
      guard let localDate = local.serverDate else { return true }
      if serverDate != localDate { return serverDate > localDate }
      if client.updatedAt != localClient.updatedAt { return client.updatedAt > localClient.updatedAt }
      return deviceToken != local.deviceToken && source == .phone
    }

    // Different Clients at the same generation: a tokenless state is not a new clear.
    if isCleared { return false }
    if local.isCleared { return true } // Seed a device that has no token.
    // A phone token awaiting its Client is unresolved, not signed out. Keep that
    // identity authoritative while its refresh is in flight (or awaiting a retry).
    if source == .watch, local.client == nil { return false }
    if hasSession != local.hasSession { return hasSession } // A signed-in Client beats a signed-out one.
    return source == .phone
  }
}

package struct WatchSyncPayload: Equatable {
  private enum Key {
    static let schema = "clerkWatchSyncSchema"
    static let deviceToken = "clerkDeviceToken"
    static let client = "clerkClient"
    static let serverDate = "clerkClientServerFetchDate"
    static let clearGeneration = "clerkWatchSyncClearGeneration"
    static let environment = "clerkEnvironment"
    static let tokenState = "watchSyncDeviceTokenState"
    static let tokenVersion = "watchSyncDeviceTokenVersion"
    static let authState = "watchSyncAuthState"
    static let authVersion = "watchSyncAuthVersion"
  }

  /// Keys an SDK 1.5 peer reads. Once synced, SDK 1.5 accepts only versioned updates, so a payload
  /// without them could not sign out a paired device that has not updated yet. Remove after one release.
  private enum LegacyKey {
    static let deviceTokenState = "watchSyncDeviceTokenState"
    static let deviceTokenVersion = "watchSyncDeviceTokenVersion"
    static let authState = "watchSyncAuthState"
    static let authVersion = "watchSyncAuthVersion"
  }

  private static let schemaVersion = 2

  /// `nil` when the payload carries no usable auth state.
  let state: WatchSyncState?
  let environment: Clerk.Environment?
  let isLegacy: Bool
  let legacyVersion: WatchSyncLegacyVersion?

  init(state: WatchSyncState?, environment: Clerk.Environment?) {
    self.state = state
    self.environment = environment
    isLegacy = false
    legacyVersion = nil
  }

  init?(applicationContext context: [String: Any]) {
    environment = (context[Key.environment] as? Data).flatMap {
      try? JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: $0)
    }

    let deviceToken = (context[Key.deviceToken] as? String).nilIfEmpty
    let clientData = context[Key.client] as? Data
    let client = clientData.flatMap {
      try? JSONDecoder.clerkDecoder.decode(Client.self, from: $0)
    }
    let isCurrentSchema = context[Key.schema] as? Int == Self.schemaVersion
    isLegacy = context[Key.schema] == nil
    let tokenVersion = Self.version(context[Key.tokenVersion])
    let authVersion = Self.version(context[Key.authVersion])
    legacyVersion = isLegacy && (tokenVersion != nil || authVersion != nil)
      ? WatchSyncLegacyVersion(token: tokenVersion, auth: authVersion) : nil
    let explicitLegacyClear = isLegacy && context[Key.tokenState] as? String == "cleared"
      && tokenVersion != nil && deviceToken == nil && clientData == nil
    let invalidLegacyMetadata = isLegacy && (
      (context[Key.tokenState] != nil && !["set", "cleared"].contains(context[Key.tokenState] as? String ?? ""))
        || (context[Key.authState] != nil && !["set", "cleared"].contains(context[Key.authState] as? String ?? ""))
        || (context[Key.tokenState] as? String == "set" && deviceToken == nil)
        || (context[Key.authState] as? String == "set" && client == nil)
        || (context[Key.tokenVersion] != nil && (tokenVersion == nil || context[Key.tokenState] == nil))
        || (context[Key.authVersion] != nil && (authVersion == nil || context[Key.authState] == nil))
        || (context[Key.tokenState] as? String == "cleared" && deviceToken != nil)
        || (context[Key.authState] as? String == "cleared" && clientData != nil)
    )

    // Absence of a token is not a clear unless the protocol explicitly says so.
    if (clientData != nil && client == nil)
      || (client != nil && deviceToken == nil)
      || (!isCurrentSchema && deviceToken == nil && !explicitLegacyClear)
      || invalidLegacyMetadata
      || (!isLegacy && !isCurrentSchema)
    {
      state = nil
    } else {
      state = WatchSyncState(
        deviceToken: deviceToken,
        client: client,
        serverDate: Self.date(context[Key.serverDate]),
        clearGeneration: isCurrentSchema ? (context[Key.clearGeneration] as? Int ?? 0) : 0
      )
    }

    guard state != nil || environment != nil else { return nil }
  }

  var applicationContext: [String: Any] {
    var context: [String: Any] = [:]
    if let state {
      context[Key.schema] = Self.schemaVersion
      context[Key.deviceToken] = state.deviceToken
      context[Key.client] = state.client.flatMap { try? JSONEncoder.clerkEncoder.encode($0) }
      context[Key.serverDate] = state.serverDate?.timeIntervalSince1970
      context[Key.clearGeneration] = state.clearGeneration
      Self.addLegacyKeys(for: state, to: &context)
    }
    context[Key.environment] = environment.flatMap { try? JSONEncoder.clerkEncoder.encode($0) }
    return context
  }

  /// Describes `state` for an SDK 1.5 peer, versioned by send time so each payload is newer than
  /// the last one it accepted.
  private static func addLegacyKeys(for state: WatchSyncState, to context: inout [String: Any]) {
    let version = Int(Date().timeIntervalSince1970 * 1000)
    if state.deviceToken != nil {
      context[LegacyKey.deviceTokenState] = "set"
      context[LegacyKey.deviceTokenVersion] = version
      if state.client != nil {
        context[LegacyKey.authState] = "set"
        context[LegacyKey.authVersion] = version
      }
    } else if state.clearGeneration > 0 {
      // Only a clear; a device that has not fetched a token yet must not sign out its peer.
      context[LegacyKey.deviceTokenState] = "cleared"
      context[LegacyKey.deviceTokenVersion] = version
      context[LegacyKey.authState] = "cleared"
      context[LegacyKey.authVersion] = version
    }
  }

  private static func date(_ value: Any?) -> Date? {
    guard let interval = value as? Double, interval.isFinite else { return nil }
    return Date(timeIntervalSince1970: interval)
  }

  private static func version(_ value: Any?) -> Int? {
    let version: Int? = if let integer = value as? Int {
      integer
    } else if let string = value as? String {
      Int(string)
    } else if let number = value as? Double {
      Int(exactly: number)
    } else {
      nil
    }
    return version.flatMap { $0 >= 0 ? $0 : nil }
  }
}
